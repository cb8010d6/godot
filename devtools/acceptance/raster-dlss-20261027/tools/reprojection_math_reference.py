"""Independent Decimal camera-space oracle and recorded float32 matrix analysis.
Factor inverses are computed in Decimal then rounded to binary32; products use binary32 rounding. This is not execution of Godot C++ inverse or a GPU test.
"""
import decimal, itertools, json, math, struct
from pathlib import Path
D=decimal.Decimal
decimal.getcontext().prec=90

def f32(x): return struct.unpack('<f',struct.pack('<f',float(x)))[0]
def ident(): return [[D(int(i==j)) for j in range(4)] for i in range(4)]
def mul(a,b): return [[sum((a[i][k]*b[k][j] for k in range(4)),D(0)) for j in range(4)] for i in range(4)]
def fmul(a,b):
    out=[]
    for i in range(4):
        row=[]
        for j in range(4):
            acc=f32(0)
            for k in range(4): acc=f32(acc+f32(a[i][k]*b[k][j]))
            row.append(acc)
        out.append(row)
    return out

def inverse(m):
    x=[row[:] + [D(int(i==j)) for j in range(4)] for i,row in enumerate(m)]
    for c in range(4):
        i=max(range(c,4),key=lambda i:abs(x[i][c])); x[c],x[i]=x[i],x[c]; q=x[c][c]; assert q
        x[c]=[v/q for v in x[c]]
        for i in range(4):
            if i!=c:
                f=x[i][c]; x[i]=[x[i][j]-f*x[c][j] for j in range(8)]
    return [row[4:] for row in x]
def mv(a,v): return [sum((a[i][j]*v[j] for j in range(4)),D(0)) for i in range(4)]
def fmv(a,v):
    out=[]
    for row in a:
        x=f32(0)
        for aij,vj in zip(row,v): x=f32(x+f32(aij*vj))
        out.append(x)
    return out
def ndc(v): return [v[i]/v[3] for i in range(3)]
def matrix32(a): return [[f32(v) for v in row] for row in a]
def decimalized(a): return [[D.from_float(float(x)) for x in row] for row in a]
def translate(x,y,z):
    out=ident();out[0][3]=D(x);out[1][3]=D(y);out[2][3]=D(z);return out
def pose(x,y,z,yaw):
    out=translate(x,y,z); c=D.from_float(f32(math.cos(yaw))); q=D.from_float(f32(math.sin(yaw)))
    out[0][0]=c;out[0][2]=q;out[2][0]=-q;out[2][2]=c
    return out

def perspective():
    # Conventional perspective with a finite depth range, then quantize inputs as real_t.
    n,f=D('0.05'),D('3000');z=D(0)
    return decimalized(matrix32([[D('1.0'),z,z,z],[z,D('1.7777778'),z,z],[z,z,-(f+n)/(f-n),-2*f*n/(f-n)],[z,z,-D(1),z]]))
def orthographic():
    return decimalized(matrix32([[D('0.05'),D(0),D(0),D(0)],[D(0),D('0.08'),D(0),D(0)],[D(0),D(0),D('-0.000667'),D('-1.000033')],[D(0),D(0),D(0),D(1)]]))
def staged_world_oracle(previous_clip, pprev, pcurr, tprev, tcurr):
    # Oracle follows individual geometric operations, not the candidate combined matrix.
    previous_eye=mv(inverse(pprev),previous_clip)
    world=mv(tprev,previous_eye)
    current_eye=mv(inverse(tcurr),world)
    return ndc(mv(pcurr,current_eye))
def test_scenarios():
    scenarios=[('static-perspective',perspective(),(0,0,0,0),(0,0,0,0)),('moving-perspective',perspective(),(0,1,0,0.03),(2,1,4,0.05)),('jump-perspective',perspective(),(0,0,0,0),(1,0,500,0.12)),('jump-orthographic',orthographic(),(0,0,0,0),(1,0,500,0.12))]
    report=[]
    for name,p,previous,current in scenarios:
        prev=pose(*previous);cur=pose(*current)
        # Candidate factorized reverse, with each multiply rounded to binary32.
        reverse=fmul(fmul(fmul(matrix32(p),matrix32(inverse(cur))),matrix32(prev)),matrix32(inverse(p)))
        maximum=0.0
        for z in (-20,-50,-100):
            for x in (-2,0,2):
                for y in (-1,1):
                    world=[D(x),D(y),D(z),D(1)]
                    prev_clip=mv(p,mv(inverse(prev),world))
                    prev_clip=[D.from_float(f32(x/prev_clip[3])) for x in prev_clip]
                    expected=staged_world_oracle(prev_clip,p,p,prev,cur)
                    actual=fmv(reverse,[float(x) for x in prev_clip])
                    assert all(math.isfinite(v) for v in actual) and abs(actual[3])>1e-6
                    actual_ndc=[actual[i]/actual[3] for i in range(3)]
                    pixels=max(abs(actual_ndc[0]-float(expected[0]))*800,abs(actual_ndc[1]-float(expected[1]))*450)
                    maximum=max(maximum,pixels)
        assert maximum<1.0,(name,maximum)
        report.append({'case':name,'points':18,'max_screen_error_pixels':maximum})
    return report

def recorded_matrix():
    p=Path(__file__).resolve().parents[1] / 'failure' / 'trace-matrix.json'
    label=json.loads(p.read_text())['cases'][1]['exact_callsite_labels'][0]
    vals=[struct.unpack('<f',struct.pack('<I',int(x,16)))[0] for x in label['bits_column_major']]
    mat=[[D.from_float(vals[c*4+r]) for c in range(4)] for r in range(4)]
    det=D(0)
    for perm in itertools.permutations(range(4)):
        term=D((-1)**sum(perm[i]>perm[j] for i in range(4) for j in range(i+1,4)))
        for i,j in enumerate(perm): term*=mat[i][j]
        det+=term
    inv=inverse(mat); norm=lambda a:max(sum(abs(v) for v in r) for r in a)
    assert det != 0
    return {'real_bytes':label['real_bytes'],'exact_binary32_input_determinant':str(det),'condition_infinity':str(norm(mat)*norm(inv)),'meaning':'Exact Decimal arithmetic on recorded quantized matrix, not reconstruction of original factors.'}

if __name__=='__main__': print(json.dumps({'status':'PASS','scope':'Decimal factor inverses rounded to binary32 and binary32 products; compiled C++/GPU not tested','scenarios':test_scenarios(),'recorded':recorded_matrix()},indent=2))
