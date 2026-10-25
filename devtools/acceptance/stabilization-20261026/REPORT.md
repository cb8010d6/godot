# Windows / RTX 稳定化公开验收证据

证据日期：2026-10-26，补入 C1 默认模板导出、打包、真实 Regina 生产包和启动器实际回执。本稿可供代码与功能审查，**不构成 RC、全面验收或性能改善声明**。
本公开副本文本已脱敏；PNG未编辑且逐字节哈希相同。所有链接相对本bundle；原始命令、退出码、二进制哈希、完整日志和截图保留在对应 receipt / matrix 中。失败记录没有被后续成功覆盖。

## 1. 两个候选与证据归属

| 候选 | 完整 SHA | 已直接实测的主要范围 |
| --- | --- | --- |
| d37 渲染基线 | `d37b63e72bd5b0b72c8d72adb7cceb1b20e1b1f8` | 六目标、13 strict、10 model、4 lifecycle、CPU/Mono、物理、PT/RR/DDGI、四模板导出 |
| C1 当前候选 | `c1fc0252a98913d3be394417b6977a8c5aa4d77d` | 六目标、CPU/两套 smoke、文档缓存回归、原 PT 导入、游戏17例、四默认模板导出运行、四归档、Regina生产包、启动器进程记录 |

C1 相对 d37 的原生实现只增加 `EditorHelp::load_script_doc_cache()` 的 6 行生命周期 guard；其他变化是 KB。渲染、SDK、PhysX、Jolt 源码相同。
这支持审查改动边界，不能把 d37 的 GPU 原始记录改记为“C1 重测”。分支为 `stabilization/4.8-beta1-sl214`，版本仍为 4.8 beta 1 / 自定义构建。
状态用语：PASS=所列断言与日志检查通过；FAIL=保留失败；LIMITED=仅所述证据层；PENDING=尚无最终回执；SKIP 不算 PASS。

## 2. 机器、工具链和锁定来源

机器原始快照见 [machine.json](evidence/source-environment.json)；工具链背景见 [旧验收记录](evidence/source-environment.json) 与 [升级指南](evidence/source-environment.json)。

| 项目 | 已记录环境 |
| --- | --- |
| OS / CPU / RAM | Windows 10 Pro 10.0.19045；Ryzen 9 7940H，8 核 16 线程；约 32 GiB |
| GPU / 驱动 | RTX 4060 Laptop，8188 MiB；NVIDIA 610.88；机器另有 Radeon 780M；HAGS 快照值 2 |
| VS / MSVC / SDK | VS 实例 17.14.37806.7，Developer Prompt 17.14.42；MSVC 14.44.35207 / cl 19.44.35229；选择 Windows SDK 10.0.26100.0 |
| Vulkan / D3D12 | 仓库头 1.4.335，真实驱动 API 1.4.341；正式验证层 1.4.366 nightly `bc5da10620168c5370f82257528c08756e19a7b2`；D3D12 FL12_0 |
| Python / 构建 | 既有记录 Python 3.12.10、SCons 4.11.1；真实 Windows/MSVC，4 jobs，后台优先级 |
| .NET | 便携 SDK 10.0.402 / runtime 10.0.13，net10.0；[本轮版本日志](evidence/source-environment.json) |
| 原生 SDK | PhysX `ovphysx-0.5.11` / 5.10.0，真实 CUDA GPU、Blast、Flow；CUDA nvcc 12.8.93，runtime/CCCL 12.8.90 |

| 来源 | 锁定 revision / 来源说明 |
| --- | --- |
| Diginaat dev 基线 | `25f6a147ed8ca36d521638ba2b5fe1715a3cbdaa` |
| Diginaat 发布分支参考 | `0d2488e2912b7004cd510906f5a6a61b09c6cf5f`，相对 dev 为 README 更新 |
| 官方 Godot 4.8 beta 1 | `4d10419cacd6d3009976e8f9fd3abd970fd58018` |
| NVIDIA Godot 集成 | `135dff3887a3d2ccf45cafbd9bdffa7b718e1e76` |
| Streamline v2.14.16 | `625db07d4bca5abc67d781c42af7e7fb0761f1b6` |
| 接收 / 阶段 A / B | `afa73e66c3fde2559d158e2caae2f1e08ad89ffc` / `4b97a9fc16fb9160f616258b3c72e1496565177d` / `0af58f0a62f05a901e99dde96f1654c35a6bdbc1` |

祖先关系、初始干净树、`version.py` 与上游一致、冲突和二进制/密钥扫描见 [intake-audit.json](evidence/source-environment.json)。
官方 SDK ZIP：276016170 bytes，SHA256 `32041e51db0cab709a271b72a352281b690c2abbd669a827809401a5dd23956b`；24 公共头及许可证逐项核对，运行库清单 19 项。[SDK provenance](evidence/source-environment.json)
没有通过桩库或伪造 SDK 边界替代原生构建；新增工具链、下载与测试缓存集中在工作盘。运行进程使用 Job Object 回收自身后代，并保留完整诊断。

## 3. 构建和 CPU 证据

d37 六目标 **PASS，382.000 s**：[receipt](evidence/builds-cpu.json)。C1 六目标现已 **PASS，527.406 s**：[receipt](evidence/builds-cpu.json)、[完整日志](logs/c1-six-build.log)。
六目标是标准/.NET 编辑器和两种版本各自的 Debug/Release 模板；命令为 `devtools/build/build.ps1 -Target release -KeepGoing -Jobs 4 -VersionStatus beta1`。
C1 单独标准编辑器先通过 **83.828 s**：[receipt](evidence/builds-cpu.json)。构建 exit0 不表示零警告：C1 日志仍有测试项目 Pkcs 9.0.10 的 NU1902/NU1903 及 NuGet 元数据提示。

| d37 检查 | 结果 / 边界 | 证据 |
| --- | --- | --- |
| Python devtools unittest | 25 项中 18 通过、7 Unix/PowerShell 平台条件跳过 | [log](logs/d37-cpu-unittests.log) |
| Windows SourceGenerators | 43/43，0 跳过 | [log](logs/d37-source-generators.log) |
| 真实 MSVC CPU 检查 | FG 策略 12；preset 85 / 捕获提交 18；SL 头 API；尺寸策略 35 | [API/preset](logs/d37-cpu-api-presets.log)、[sizing](logs/d37-cpu-sizing.log) |
| 标准/.NET 仓库 smoke | 各四项通过，28.032 / 24.172 s | [standard](logs/d37-smoke-standard.log)、[mono](logs/d37-smoke-mono.log) |
| 托管 API / PhysX 查询 | CSHARP_PHYSX_SMOKE_PASS | [receipt](evidence/builds-cpu.json) |

上述 CPU 策略检查不冒充 SDK/GPU 执行。云端曾报告的全量引擎测试也不计作本机 Windows 重测数量。
C1 SourceGenerators 已再次 **43 PASS / 0 FAIL / 0 SKIP**，receipt为16.719s：[log](logs/c1-source-generators.log)、[receipt](evidence/builds-cpu.json)。C1标准/Mono仓库smoke各四项通过、版本均为C1，29.172/24.234s：[standard](logs/c1-smoke-standard.log)、[mono](logs/c1-smoke-mono.log)。smoke内含GPU场景，不能归为纯CPU测试。

## 4. 21 项验收覆盖表（按主题归并）

| # | 主题 | 当前结论与主要证据 |
| --- | --- | --- |
| 1 | 机器与真实工具链 | 已记录；仅此 RTX4060/Windows 机器，不外推所有设备 |
| 2 | 来源、SHA、SDK 完整性 | 锁定与祖先审计完成；见第 2 节 |
| 3 | 六种原生目标 | d37、C1 均 PASS；见第 3 节 |
| 4 | 标准/.NET 编辑器 | d37、C1 两套 smoke PASS；C1 headless import 修复回归 PASS |
| 5 | CPU 策略与构建工具测试 | 实际 MSVC / Python 检查通过，7 平台跳过独立保留 |
| 6 | C# / SourceGenerators | d37、C1 各43项通过，真实托管 PhysX API通过；net10.0迁移要求保留 |
| 7 | 缺 Streamline DLL / 旧 SDK | no-SL可运行；C1仅interposer缺plugins的两API可完成回退，但eErrorNoPlugins保留；2.10严格Vulkan仍失败 |
| 8 | Vulkan / D3D12 Forward+ | 两 API 实际截图；d37 D3D12 strict 六例干净，SL Vulkan 六例未干净 |
| 9 | DLSS SR 模式 | Q/Balanced/Performance/Ultra 两 API 实际渲染，Ultra 尺寸修复生效 |
| 10 | DLAA | 两 API 1.0 缩放实际渲染；无性能/画质提升量声明 |
| 11 | L/M/K 与真实模型证据 | 10 model 用例渲染通过；代表原始指示器图确认 preset 与运行库，见第 6 节 |
| 12 | NIS / 输出同步 | strict 锐化 0/0.2 与 lifecycle0.2 覆盖；D3D12 干净，Vulkan SDK 剩余诊断保留 |
| 13 | Path Tracer | Vulkan 复杂场景和 smoke 运行；D3D12 请求 PT 按栅格回退验收 |
| 14 | Ray Reconstruction / 引导缓冲 | Vulkan 28 张复杂场景捕获完成；RR D/E/F 为请求值，未当作实际模型身份 |
| 15 | 普通 2X FG | 三个 strict FG 用例各 239 个前台 presented=2 样本；Vulkan strict 仍 FAIL |
| 16 | 生命周期 / 多视口 FG | 四个非 strict lifecycle PASS；多视口明确降级，C1 游戏多人用例通过 |
| 17 | Reflex | 原生 driver 时间报告有效；availability、active、物理延迟分开，见第 7 节 |
| 18 | DDGI | d37 六项实际 Vulkan 场景 + 两套 smoke；不外推 D3D12 动态 RT DDGI |
| 19 | PhysX CPU/GPU、Blast、Flow | 六例 PASS / 全部 skip=false；真实 CUDA volume、GPU 回读和渲染计数 |
| 20 | 默认安装模板 / 实际导出 | C1 四种标准/.NET Debug/Release TPZ 导出并在 D3D12/4060 运行 PASS，四归档也通过 |
| 21 | 真实游戏与交付审查 | C1冻结17/17、Regina生产包两API自然退出PASS；旧d37整体FAIL保留；独立快捷入口已读回，发布待办 |

## 5. 严格 GPU 验证：通过和失败必须同时保留

[d37 strict 原始矩阵](evidence/strict-summary.json)：13 例均 exit0，但严格结果为 **7 PASS / 6 FAIL**。
D3D12 六例为 no-SL native、2.14 SR 锐化0/0.2、2.14 FG、2.10 SR 锐化0/0.2，全部 0 D3D debug errors、0 engine errors。
Vulkan no-SL native 干净；加载 SL 的六例仍报告下列错误，不能用“能出图”或 FG 计数改写为 PASS。

| 剩余诊断 | 当前对象/命令归属证据与范围 |
| --- | --- |
| `VUID-vkCmdDraw-None-09600` | 2.14 SDK pacer 的 fake-swapchain copy/layout 路径；实际消息需连同 CopyImage、资源名读取 |
| `VUID-vkQueueSubmit2-semaphore-03868` | 2.14 SDK pacer 呈现 semaphore 重用 |
| `VUID-vkQueueSubmit-pSignalSemaphores-00067` | 2.10 对照的呈现 semaphore 路径仍失败 |
| `03238` / `03873` | 2.14 FG 内部 wait semaphore / stage 约束诊断 |
| `SYNC-HAZARD-WRITE-AFTER-WRITE` / `READ-AFTER-WRITE` | `nv.ngx.dlssg.Evaluate` 内部 clear/copy 与 barrier 序列 |
| `UNASSIGNED-Threading-MultipleThreads-{Read,Write}` | SDK latency marker/sleep 与 SDK pacer 访问同一 swapchain |

原始示例：[Vulkan SR](logs/d37-strict-vulkan-sr.log)、[FG0](logs/d37-strict-vulkan-fg.log)、[FG0.2](logs/d37-strict-vulkan-fg-nis.log)。重复上限 10 不是实际总发生次数。
宿主 feature/pNext、资源 usage、输出同步和关闭顺序已分别修正；d37 终结等待后 `05149` / `01282` 未再出现，local-RD 的 `01387` / `04564` / `02830` 控制也消失。[local control](evidence/local-device-summary.json)
公开 SDK 私有 pacer 实现不可见，现有归属不代表穷尽所有集成因素；本驱动仍调用 legacy `vkCmdPipelineBarrier`，已排除“host core Barrier2/KHR alias 漏钩”这一具体假设。[只读审查](REFLEX_METHODS.md)

## 6. SR / DLAA、尺寸和模型

[10 model 矩阵](evidence/model-summary.json) 覆盖两 API 各 Ultra Performance L、Quality M、Balanced Recommended、Performance M、DLAA M，全部实际渲染通过、无引擎错误。
这组没有启用 validation layers，字段已明确 `validation_requested=false / strict_clean=null`；不能拿空 diagnostics 当 strict-clean。
真实 SDK 查询表明 2560×1440 Ultra 的合法内部尺寸为 853×480；原先 `ceil(target×1/3)` 为 854×480。现保留已合法尺寸，只在所有模式不合法时接受每轴最多1px的合法边界调整，不放宽 SDK min/max。[双 API 查询](evidence/optimal-settings.json)
代表原始截图已确认 L、M、K 的解析结果及 `NGX 310.9.16 (default)`；图像位于各 model 用例的 `static.png`，如 [Ultra L](images/sdk214-vulkan-ultra-L.png)、[Quality M](images/sdk214-d3d12-quality-M.png)、[Balanced](images/sdk214-vulkan-balanced-K.png)。
请求参数 `eOk`、运行库版本、实际 Render Preset 与神经网络权重身份是不同证据；未以请求日志单独证明全部 AI 模型代际或画质提升。
用户已将 NVIDIA App 设为 Use 3D application setting；只读 NVAPI 快照中 SR/RR/FG Override 和 preset 均为0。[快照](logs/overrides-readonly.log)
禁用 OTA 只约束进程的 Streamline OTA 选择，不等于关闭驱动模型缓存或全局 Override。临时指示器的最终恢复待回执，见第 11 节。

## 7. FG / Reflex 的证据层

| d37 实测 | 实际结果 | 不能据此推断 |
| --- | --- | --- |
| strict FG：Vulkan0、Vulkan0.2、D3D12 | 各239个前台 PID 匹配且 presented=2/eOk 样本 | Vulkan 无验证错误、生成帧画质或物理输入延迟 |
| lifecycle0.2：两 API 各一例 | 各772个前台 presented=2；模式切换、窗口重建完成 | 长期性能或全部资源组合覆盖 |
| scene_restart：D3D12 / Vulkan | 两次整场景替换；分别570 / 569个前台 presented=2 | PNG 内已包含生成的中间帧 |

[四例 lifecycle 矩阵](evidence/lifecycle-summary.json) 全部无引擎错误，未开验证层，`strict_clean=null`。应用 viewport PNG 记录真实渲染结果，不能替代交换链插帧画面采集。
RTX4060 的 SDK 报告 `max_generated_frames=1 / dynamic_mfg_supported=0`：这里只验证普通2X；RTX50、MFG/6X、Dynamic MFG 未验证，也未新增这些控制。
Reflex 三个 strict FG case 各261次查询均 SDK result0；两 Vulkan 各249条完整8时间戳，从 engine12开始；D3D12 182条有非零时间，其中162完整、20条缺 GPU end，从 engine79开始。[逐样本数据](evidence/reflex-summary.json)
探针扫描64槽按最大 frameID 取样，ABI与2.14头一致；它可能选到尚未完整结束的最新报告。Quality/Reflex Off 对照也有非零报告，因此 `low_latency_available/report_available` 不等于 active。
D3D12 GPU start 早于同条 simulation start 的关联疑点在1000/036c也存在；没有据此计算可信端到端延迟。当前仅证明请求、sleep/marker路径和 driver 时间报告通路工作；未做物理延迟或 Off/On 改善量验收。[审查结论](REFLEX_METHODS.md)

## 8. PT / RR、DDGI 和原生物理

[remaining-render 矩阵](evidence/remaining-render-summary.json) 保留 d37 import FAIL；其中真实 Vulkan RR、托管 API 与 DDGI六例运行通过。
RR 复杂场景完成28次捕获：玻璃、发光、材质/顶点 shader、光照、动态网格/摄像机、D/E/F请求、6类引导缓冲、双视口、竖屏重建与返回栅格。[原始日志](logs/d37-rr-complex.log)
DDGI 六项为 none/ddgi/scroll/light-switch/bake/load，均有实际运行/截图；与 PT 独立验证，不宣称 D3D12 动态硬件 RT。两套 smoke 的 interior mean_linear=0.0124 是短样本输出，不是性能改善统计。

| d37 物理项 | 实测断言 |
| --- | --- |
| PhysX CPU | 明确禁用 GPU，落体5m→0.499m，tick59落地 |
| PhysX GPU rigid | 真实 RTX4060 CUDA context、`initialized [GPU]` 与落体结果 |
| CUDA soft body | 四条真实 `PxDeformableVolume` 创建，形变/接触/冲量约+12.3m/固定点通过 |
| Blast | 真实资产加载，损伤后 spawned=8 / body_count=8 |
| Flow GPU readback | 8,164,864 bytes，气顶4.78m，近烟0.287/远0.000 |
| Flow render | 29 pipelines / 0 failures，compute passes>0，464次render输出，CPU readback=0 |

[physics-d37-matrix.json](evidence/physics-summary.json)：六项 PASS，全部 skip=false。GPU 落体本身不足以证明 CUDA，故同时保留 GPU-volume 原生创建及结果；Flow 使用 RenderingDevice compute，不把 CUDA初始化日志当 Flow 证据。
软体用 PGS，soft-vs-soft 明确 n/a；未声称 TGS 叠放完整覆盖。未修改 Jolt 或以新示例中不存在的 PhysX singleton API 代替当前 vendored 模块验证。

## 9. 模板、包与真实游戏

d37 标准/.NET 编辑器 ZIP 与模板 TPZ 共四包检查通过；[库存及 SHA256](evidence/packages-d37-history.json)、[打包矩阵](evidence/packages-d37-history.json) 保留精确大小与哈希，旧包单独存档。
公共包排除私有 Streamline/NGX 运行库；开源 PhysX/Blast/Flow 的必需依赖和许可证按包规则处理，不能把“缺 SL 可回退”外推成删掉全部原生依赖仍能运行。
[C1 默认安装 TPZ 的四项实际导出矩阵](evidence/exports-c1-summary.json) 全部 PASS：standard-debug、standard-release、mono-debug、mono-release，运行的 engine hash均C1、D3D12/4060，含真实 PhysX/C#断言；feed/托管伴随文件/编辑器/归档最终输入哈希均未变。
Mono 为全新运行隔离 NuGet缓存、net10.0 self-contained；运行时移除 .NET SDK 发现环境且导出目录有 hostfxr/coreclr。机器仍安装SDK，不能称净机验收。此四项是物理夹具导出，不是完整 sport-games 导出。
d37 no-SL 与 SDK214 镜像使用同一标准 EXE 哈希 `ef03a26cd8ce8a01b6f8b985592ac609ae10627209bb5a8264f824808146aa16`，区别为运行库部署；因此缺 SL 的启动/功能回退不是仅编译 stub 对照。
C1另做仅有签名`sl.interposer.dll`、故意缺少plugins/NGX的partial-runtime两API控制：exit0、DLSS不advertise、实际捕获与场景完成、NGX after为空；Vulkan有1条、D3D12有2条`ERROR: sl::eErrorNoPlugins`。[原矩阵](evidence/partial-runtime-c1-summary.json)仅标startup/fallback verified；这不是无错误或strict-clean通过，完整错误原样保留。
C1 四个 ZIP/TPZ 已实际重制并检查：[打包矩阵](evidence/packages-c1.json)、[精确库存哈希](evidence/packages-c1.json)。d37归档仍独立保留，不改标C1。
真实 Regina 本体已从完整独立副本用同C1已安装模板完成冷导入337.562s及Windows release导出14.156s，均exit0/no ERROR：[import](evidence/regina-c1-export-records.json)、[export](evidence/regina-c1-export-records.json)。[模板安装库存](evidence/regina-c1-export-records.json)保留TPZ与实际文件哈希。
[生产包自然退出矩阵](evidence/regina-c1-natural-exit-matrix.json)两项实际PASS：D3D12 skate2、Vulkan basketball4各三张1600×900真实PNG、exit0/no ERROR、Job负责后代回收且NGX before/after为空；命令无`--path`、`--script`、`--quit-after`，由生产`--shots`在最后8s捕获后退出。代表图：[Vulkan四人生产PCK](images/regina-c1-production-four-players.png)。
首轮尝试的外部`--script`被生产模板禁用，没有FINISHED标记；该进程exit0不算捕获夹具通过。[原始进程receipt](evidence/regina-c1-export-records.json)与完整日志保留。下一轮按walltime<19判断自然退出时将SDK启动时间也计入，[原派生矩阵](evidence/regina-c1-intermediate-guard-matrix.json)两个`passed=false`仍原样保留；最终移除frameguard的自然退出实测另立记录，没有重写前两轮结果。

C1 [冻结游戏17项矩阵](evidence/game-matrices-summary.json) 已 **17/17 整体 PASS，无 global_error**。两 API 单人 Q/DLAA/Performance、多人数2/3/4、Vulkan DDGI/PT+RR、D3D12 PT栅格回退、两API no-SDK FSR回退均有真实1600×900 PNG和metadata。
这批使用隔离数据、Jolt120Hz、HDR关、180次真实post-draw、固定模拟步长；多人FG请求按当前root/3D视口资格明确降级。该游戏矩阵未开验证层，不替代第5节 strict结果，也不作为FPS或真人输入性能测试。
旧 [d37游戏矩阵](evidence/game-matrices-summary.json) 虽17个分例PASS，整体仍 **FAIL**：执行期间冻结输入发生变化（父任务确认是测试执行器变动）。原 global_error 和证据保留，未事后修改旧判定。

独立 NVIDIA 启动入口的首轮 Windows PowerShell wrapper 因未缓存进程 Handle 而取得空 ExitCode，首轮 wrapper 失败保留，不能用内部游戏exit0替它改判。
父任务缓存 Handle 后复测 wrapper 通过；[实际进程receipt](evidence/launcher-game-process.json) 的 `game_exit_code=0 / helper_exit_code=0 / owned_ngx_remaining=[] / ngx_updaters_before=[] / ngx_updaters_after=[]` 均直接来自真实原文件。
[首轮内部进程记录](evidence/launcher-before-handle-fix-game-process.json) 同样保留；它不包含 wrapper 最终退出判定。没有手写新的成功JSON，Hub启动stdout不进入公开材料。
[独立桌面快捷入口读回](evidence/desktop-nvidia-shortcut.json)确认`Regina Sports NVIDIA.lnk`指向冻结C1标准编辑器SDK214，固定二进制SHA256 `436ddd6b7aab06cb0f4f74cde1a2fc56b6012a6fa07e0a1ae3e3a5d24563ef20`并使用D3D12。原快捷方式SHA256仍为`D78160BF218622C7E29F04F9965AD82BEF73AD2305AEE8EF393357A3389B2DE9`；只归档实际JSON，不公开快捷方式或启动stdout。

## 10. 关键修复与新导入崩溃

| 提交 | 具体边界 |
| --- | --- |
| `48facf8789` | 标准/Mono 原生构建缓存按模块版本分离 |
| `2775e4384f`、`0b7a7f7758`、`147b47cae5` | DLSS输出写依赖/GENERAL-UAV、transfer usage与外部callback stages |
| `5507e26d7d`、`dc2ae21ba3` | PT abandoned pipeline释放顺序；PT/RR storage-image格式匹配 |
| `94c27203b1` | NIS格式与图依赖修正 |
| `b8d791fa87`、`92dd424cf0` | Vulkan surface窗口instance与已注册窗口类兼容 |
| `59d1f2bd5e`、`6e157d1131`、`99f59c8232` | Vulkan SDK features、swapchain transfer、明确的多视口FG资格 |
| `f9207b88db`、`e627be688e`、`eb9cd21be9`、`1000baebda` | Agility查找隔离、D3D native callback资源/绑定、VectorView traversal、兼容PIX事件包 |
| `036c6c7023` | SDK合法尺寸内的一像素重协调，保留原有合法尺寸 |
| `d040fbbe7d`、`e48cc54293` | SDK全局状态仅主RD拥有；仍经interposer的local设备保留SDK创建要求 |
| `d37b63e72b` | 主 Vulkan device 终结idle callback，经真实SL GDPA保留SDK wait hooks，失败明确记录 |
| `c1fc0252a9` | 仅对已无EditorNode的script-doc-cache callback提前返回 |

`c76e671d0d` 的 R32F depth 是失败的诊断假设，未消除目标错误，后续已移除；实际保留的相关修复是 `6e157d1131` 的真实 swapchain transfer usage。旧实验不列为留存修复。

导入根因用无任何GDExtension的空项目也复现：真实1000旧文档缓存→d37退出时 deferred文档任务越过EditorNode生命期，`is_cmdline_mode` null后崩溃。冷/匹配暖缓存8个对照通过；旧缓存两例均AV。
C1 rebuilt 后相同 empty/probe 两例 **exit0 / errors=[]**，原 PT fixture import也 **exit0 / no ERROR**：[CPU回归](evidence/import-controls-summary.json)、[原导入receipt](evidence/import-controls-summary.json)。未跳过扩展注册、未过滤ERROR、未改变全局flush顺序。

## 11. 审查、限制和交付待办

| 审查问题 | 结论 |
| --- | --- |
| 是否有可审查的具体修复与真实本机证据？ | 有；源码、SHA、原始失败和成功边界可对照 |
| 是否可把D3D12列为本机严格验证通过？ | 可，仅限d37所列六例；C1原生渲染源码相同，未把它冒充另一次strict重测 |
| 是否全部后端严格干净、可称RC？ | 不可；SL Vulkan六例仍FAIL，私有SDK诊断保留 |
| C1构建、smoke、游戏17例、四默认模板、归档及Regina生产包是否完成？ | 对应最终回执已PASS；独立快捷入口已读回，发布/PR尚未完成 |

未测范围明确保留：RTX50/MFG/6X/Dynamic MFG、HDR、BLE真实设备与真人联机/手感、长时间温度/功耗/帧率/内存曲线、生成中间帧的物理画质与物理延迟、所有GPU/系统组合。
PGS软体接触限制、D3D12 PT/动态RT DDGI能力边界、上游测试依赖警告保留；不由短帧截图或功能计数推断性能改善。
临时 `ShowDlssIndicator=1024` 的原值为不存在：[备份](evidence/indicator-original-state.json)。管理员恢复及只读复核尚待父任务最终回执；用户选择的 NVIDIA App Use3DAppSetting 应保留。
整理本稿没有新增原生构建/GPU测试、修改源码共享日志、commit或push。最终发布/PR状态应引用实际交付回执，不从本稿推断已经完成。
