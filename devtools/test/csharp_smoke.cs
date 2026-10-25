using Godot;
using System;

public partial class ManagedSmoke : Node3D
{
	private int _frames;

	public override void _PhysicsProcess(double delta)
	{
		if (++_frames != 3) return;
		try
		{
			// Compile custom bindings without starting their GPU features.
			Type[] customTypes = { typeof(DdgiVolume), typeof(PhysXVehicle3D), typeof(PhysXBlastAsset), typeof(PhysXFlow3D) };
			foreach (string nativeClass in new[] { "DDGIVolume", "PhysXVehicle3D", "PhysXBlastAsset", "PhysXFlow3D" })
				if (!ClassDB.ClassExists(nativeClass)) throw new Exception("Missing native class " + nativeClass);
			using var query = PhysicsRayQueryParameters3D.Create(new Vector3(0, 2, 0), new Vector3(0, -2, 0));
			var state = GetWorld3D().DirectSpaceState;
			using var oldResult = state.IntersectRay(query);
			if (!oldResult.ContainsKey("position")) throw new Exception("Dictionary ray query missed ground");
			var oldPosition = oldResult["position"].AsVector3();
			var oldNormal = oldResult["normal"].AsVector3();
			if (Math.Abs(oldPosition.Y + 0.5f) > 0.001 || oldNormal.Dot(Vector3.Up) < 0.99f)
				throw new Exception("Unexpected dictionary ray result " + oldPosition + " / " + oldNormal);
			if (oldResult["collider"].AsGodotObject() != GetNode("Ground")) throw new Exception("Wrong dictionary ray collider");
			using var result = new PhysicsIntersectRayResult3D();
			if (!state.IntersectRayInto(query, result)) throw new Exception("Typed ray query missed ground");
			if (Math.Abs(result.Position.Y + 0.5f) > 0.001 || result.Normal.Dot(Vector3.Up) < 0.99f)
				throw new Exception("Unexpected typed ray result " + result.Position + " / " + result.Normal);
			if (result.Collider != GetNode("Ground")) throw new Exception("Wrong typed ray collider");
			GD.Print("CSHARP_PHYSX_SMOKE_PASS typed_and_dictionary_ray_queries custom_types=", customTypes.Length);
			GetTree().Quit();
		}
		catch (Exception error)
		{
			GD.PushError("CSHARP_PHYSX_SMOKE_FAIL " + error);
			GetTree().Quit(1);
		}
	}
}
