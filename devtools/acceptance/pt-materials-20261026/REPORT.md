# PT 材质修复：A028 部分修复与 A738 窄范围 COLOR 回归

整理日期：2026-10-27（Australia/Sydney）。本文是供审阅的增量实测记录。最新已测原生候选为 `a73826e8c0fd90351a1bae5095ce87bc6210be7f`（A738）；Godot 4.8 beta 1 / Streamline 2.14.16。它不是全部材质与引擎功能验收、RC 或合并许可。既有 A028 50 文件审计稿及原始 FAIL 记录保持原样。

## 已结束的真实结果

| 目标/提交 | 结果与范围 | 原始回执的脱敏副本 |
| --- | --- | --- |
| A738 标准编辑器构建 | PASS，145.687 秒，Jobs 2，工作树干净 | [回执](evidence/build-a738-editor.json)、[完整日志](logs/build-a738-editor.log) |
| A028 标准 COLOR 红对照 | FAIL，exit 1，19.422 秒；四阶段实际像素均失败，配置/TLAS符合旧 merged 路径 | [回执](evidence/standard-color-red-a028.json)、[完整摘要](evidence/standard-color-red-summary.json)、[日志](logs/standard-color-red-a028.log) |
| A738 标准 COLOR 绿对照 | PASS，exit 0，27.0 秒；ArrayMesh 条纹、MultiMesh RGB、linear/sRGB 两个独立 reference 比较共四阶段 | [回执](evidence/standard-color-green-a738.json)、[完整摘要](evidence/standard-color-green-summary.json)、[日志](logs/standard-color-green-a738.log) |
| A028 完整 12-case | 自动模式/配置/PLAY/相机/TLAS/日志断言 PASS；仍有遮阳棚目视 FAIL，不能改写为完整画质通过 | [完整矩阵](evidence/a028-complete-twelve-matrix.json) |
| A028 两/四人分屏四例 | 自动断言 PASS；只强制首玩家拍照相机，其余保留游戏自然相机，不能宣称全部自然机位逐图通过 | [完整矩阵](evidence/a028-split-two-four-matrix.json) |
| A028 六 Windows 目标 | PASS，454.313 秒；标准/.NET editor、template_debug、template_release | [回执](evidence/build-a028-six.json)、[日志](logs/build-a028-six.log) |
| A028 标准/.NET smoke | 各四项 PASS，30.672 / 26.906 秒；PhysX 游戏/编辑器、Vulkan PT、DDGI | [标准](logs/smoke-a028-standard.log)、[Mono](logs/smoke-a028-mono.log) |
| A028 owner 回归 | 相同公开夹具 BCC red FAIL / A028 两阶段 PASS；扩展生命周期六阶段 PASS | [red](evidence/owner-red-summary.json)、[green](evidence/owner-green-summary.json)、[扩展](evidence/owner-extended-summary.json) |
| 游戏六项 CPU 检查 | PASS；tools 122+293 subtests、hub 251、Node 12、Ruff、i18n、conventions（4 个既有 SIZE 警告） | [完整矩阵](evidence/cpu-six-matrix.json) |
| A738 六 Windows 目标 | PASS，454.266 秒，Jobs 2；标准/.NET editor、template_debug、template_release | [回执](evidence/build-a738-six.json)、[完整日志](logs/build-a738-six.log) |
| A738 标准/.NET smoke | 各四项 PASS，31.031 / 27.078 秒；PhysX 游戏/编辑器、Vulkan PT、DDGI | [标准](logs/smoke-a738-standard.log)、[Mono](logs/smoke-a738-mono.log) |
| A738 游戏首次 PT+RR 两例 | 自动 PASS；滑板回访条纹恢复，滑雪首张近景仍灰、之后机位恢复，不列为完整逐图通过 | [完整矩阵](evidence/a738-first-two-matrix.json) |
| A738 三场景×PT0/PT+RR 六例 | 自动断言全部 PASS；指定同机位后图中建筑/窗/地砖/绿白遮阳棚及近景雪纹恢复 | [完整矩阵](evidence/a738-final-six-matrix.json) |
| A738 两/四人分屏四例 | 自动断言全部 PASS；首玩家控制机位，其余保留游戏自然相机，全部有效视口核对 TLAS 与缩放 | [完整矩阵](evidence/a738-final-split-four-matrix.json) |
| A738 实际游戏 DDGI 两例 | skate0、ski0 自动断言 PASS；与 PT/RR 分别运行 | [完整矩阵](evidence/a738-final-ddgi-two-matrix.json) |
| A738 owner 两阶段/扩展六阶段 | 两个独立回归均 PASS，11.547 / 14.86 秒；无 Streamline 控制路径 | [公开 owner](evidence/owner-final-a738-summary.json)、[生命周期](evidence/owner-lifetime-a738-summary.json) |
| A738 标准/.NET 模板打包 | 两包 PASS，8.891 / 9.094 秒；未在公开证据包内分发 TPZ 或 DLL | [标准回执](evidence/package-a738-standard.json)、[Mono 回执](evidence/package-a738-mono.json) |
| 最终四种安装模板导出运行 | 四例 PASS，21 步 wrapper/进程全部 exit 0；标准/.NET Debug/Release，独立安装模板、D3D12 与无 Streamline DLL 降级 | [完整矩阵](evidence/installed-exports-a738-matrix.json) |
| 官方 4.7.2 兼容回归 | headless 17 项 PASS，63.407 秒；受影响 skate/ski 两/四人自然完整 smoke 回合 PASS，outer 两例合计 206.063 / 216.719 秒 | [headless](logs/official472-headless-smoke.log)、[两人](logs/official472-rendered-p2.log)、[四人](logs/official472-rendered-p4.log) |
| 实际 Regina PCK 导出/RT include 入包 | PASS；import 356.578 秒，release export 14.171 秒；PCK 实际 1,662,380,392 字节、1148 个目录项，RT include 的实际 payload 与源字节/SHA/目录 MD5 匹配 | [import/export 矩阵](evidence/regina-a738-export-matrix.json)、[PCK 完整目录与 payload 校验](evidence/regina-a738-pck-inventory.json)、[模板安装](evidence/regina-a738-template-install.json) |
| 实际生产 EXE / D3D12 | skate 两人，light=0，三张 1600×900 原图，exit 0、无错误、正确 A738/API/RTX4060；37.531 秒为实际 wrapper 耗时 | [完整自然入口矩阵](evidence/regina-a738-natural-matrix.json) |
| 实际生产 EXE / Vulkan | skate 一人，请求 light=2（PT+RR）、DLSS Quality，三张 1600×900 原图，exit 0、无错误、正确 A738/API/RTX4060；45.266 秒为实际 wrapper 耗时 | [完整自然入口矩阵](evidence/regina-a738-natural-matrix.json) |

A738 游戏最终回归的 12 例组成是 **6 个 PT0/PT+RR + 4 个两/四人分屏 + 2 个 DDGI**，不是在 A738 重跑三场景×四模式的默认 12 例。后者属于 A028 历史记录。官方 4.7.2 的单场景日志耗时分别为两人 skate 121.23 / ski 83.02 秒、四人 skate 132.16 / ski 83.0 秒；它们与 wrapper 的双场景总耗时分别保留，不能混写，也不是 RTX 功能证明。

## A738 代码范围与保守边界

A028 已恢复部分程序化建筑/地面材质，但实际 PT+RR 遮阳棚仍白，光栅/DDGI 则保留绿白条纹。源码确认它使用普通 ArrayMesh 顶点色与 `StandardMaterial3D.vertex_color_use_as_albedo=true`；HG0 不读取 `COLOR`，此前自动断言没有覆盖这项视觉要求。

A738 在实际 ShaderCompiler 使用标记和 RTClassification 中记录 `COLOR`，把普通不透明、非自发光顶点色材质送入其已有生成 shader 的 custom hit group，从而保留纹理/材质乘法、source-color uniform 和可选顶点 sRGB 转换。共享 RT globals 的 `SHADER_IS_SRGB=false` 对应真实线性材质求值约定。提交涉及四处 renderer 文件、公开独立夹具与文档，共 11 文件、+461/-9。

alpha、clip/alpha-pass、自发光、折射、height-map/parallax、矩阵/位置改写、particle trails 和 point size 等路径被保守排除。自发光仍沿用 HG0 的 mesh-light/NEE 路径；这是避免改变采样语义的代码边界，不是已实测所有发光或透明材质正确。被排除路径的顶点色限制仍在，不能宣称全 StandardMaterial3D 功能已支持。

依赖 `COLOR` 的 MultiMesh 使用既有 expanded 路径，merged 格式没有改变。对照的预期 TLAS 因此明确不同：红对照四阶段为 `[1,1,2,2]`，绿对照为 `[1,3,4,4]`，实际值各自符合预期。展开会增加 TLAS/几何工作；没有成本上限或性能改善结论。

## COLOR 红绿夹具的证据强度

两次运行的脚本 SHA-256 均为 `32c50befae8d888884607f3e52064192f74e7004b4be26f9b63863fc359cd28d`。像素断言完全相同，路径/TLAS 预期由显式 `--mm-path=merged` 与 `--mm-path=expanded` 区分。它没有把原 lifecycle phase 07 的 merged 失败重写为通过。

两次都使用可见 Vulkan PT 窗口、640×360、同步 shader 编译、4 spp、2 bounces，RR/DDGI/DLSS 关闭。前两阶段检查实际绿白条纹和 RGB 三实例；后两阶段比较 0.5 linear 与 0.5 sRGB 输入对独立 HG0 reference 的每通道误差（阈值 0.045），要求 reference 实际受光并核对背景负采样，不能仅“看到灰色”就通过。全部实际数值与布尔判定保留在完整 JSON 中。

绿对照冻结二进制 SHA-256 为 `a73a3555c39d0b1bdce13cb3fd6f793788d0c27fbd677f6d81108cdbebf9abfc`。runtime 记录 Windows 10.0.19045、RTX 4060 Laptop、Vulkan 1.4.341、驱动 32.0.16.1088。该小夹具没有 Streamline DLL；它证明所列 Vulkan RT 材质行为，不是 RR、DLSS、FG 或真实游戏的替代验收。

## 原失败与中间画面继续保留

- 858 编辑器构建 exit 1、130.531 秒，MSVC C2664（const RID 不能传给 RID &）：[回执](evidence/build-858-failed.json)、[日志](logs/build-858-failed.log)。
- BCC 初版 helper 的两例 shader 前端 `INV_VIEW_MATRIX` 错误仍为 FAIL，尽管引擎 exit 0：[矩阵](evidence/bcc-helper-failed-matrix.json)。后续 helper 将 stage built-ins 从 `fragment()` 显式传参，光栅导数原路径保留。
- A028 首轮自动 PASS 但滑板早图仍灰，后续机位与独立正常异步重跑恢复；这不能证明所有冷启动问题已解决。[首轮](evidence/a028-first-functional-matrix.json)、[正常回访](evidence/a028-normal-recheck-matrix.json)、[同步诊断](evidence/a028-sync-diagnostic-matrix.json)。
- A738 首次 PT+RR 两例再次出现滑雪 `snow_near` 灰色早图，之后 `snow_far`/`tree_band` 恢复；最终独立六例同机位近景雪纹恢复。冷异步等待边界已实际再次出现，未被当作只发生一次的偶然；后续温热结果不能证明冷启动总能立即显示完整材质。首轮所有自动 PASS、实际参数与机位记录继续保留：[A738 首轮](evidence/a738-first-two-matrix.json)、[最终六例](evidence/a738-final-six-matrix.json)。
- A028 遮阳棚顶点色的目视 FAIL 由新 COLOR 夹具 red 重现；A738 小夹具 green 不能单独把 A028 全部游戏材质状态改为通过。
- A028 六构建日志保留 NU1902/NU1903（测试项目 Pkcs 9.0.10）与 NuGet readme 提示；exit 0 不等于无警告。

四张既有原图继续保留为历史比较，**前图来自 BCC 初版 helper 前端失败，不是原 C1 缺陷复现原图；后图仅为 A028 部分恢复，不是 A738 最终后图**。没有通过这四图给单个引擎提交作因果或性能归因。

| 场景 | BCC helper 前端失败原图 | A028 中间候选原图 |
| --- | --- | --- |
| 建筑 | [left_near](images/skate-bcc-helper-failure.png) | [正常异步 left_near](images/skate-a028-normal-recheck.png)，遮阳棚仍白 |
| 滑雪 | [snow_near](images/ski-bcc-helper-failure.png) | [snow_near](images/ski-a028-functional.png) |

最终六例运行 `a73826e8c0-20261026T132931Z-dc98e9` 的以下同机位原始图已人工检查。两图保留原字节，不是运行时指示器、性能数据或冷启动全部通过证明。建筑图显示绿白遮阳棚、窗与地砖恢复；滑雪图显示近景雪纹恢复。

| 场景 | A738 最终指定后图 | 原始 SHA-256 |
| --- | --- | --- |
| 建筑 PT+RR | [skate0 / left_near](images/skate-a738-final-pt-rr.png) | `65467c99f67575b0bfdfd2a17d1ce5ec2f5d0365d21c0b15056c6347a16c5cc6` |
| 滑雪 PT+RR | [ski0 / snow_near](images/ski-a738-final-pt-rr.png) | `0a6b7863b39dfcec043d275d4c279601a9031c24d1ce6cdf85a9cd946739fadb` |

未复制运行中画面或生成替代图。所有已收录 PNG 保持原字节，源文件与公开副本对应见 [manifest](MANIFEST.json)。

## 实际 Regina PCK 与生产入口

本次真实导出包使用本轮安装的标准 release template，在独立私有项目副本 headless import/export 后补齐冻结 SDK DLL，相对布局和同名 SHA 校验保留；没有使用旧 C1/A028 导出包。实际 PCK 是 format 4，其 SHA-256 为 `ef56751132f51f34a8c996cc2b31971c4c18fef5faa1d5b2e85ccb49c2cc7be0`。PCK 实际目录中的 `res://shaders/rt_pixel_footprint.gdshaderinc` 为 1654 字节，payload/source SHA-256 均为 `93d533e430c52ff222eb18ac96953855797c22b42de09298004d3037c17e63a1`，目录 MD5 也吻合；这超出仅检查 `export_filter=all_resources` 的静态结论。[完整导出产物清单](evidence/regina-a738-inventory.json)、[运行后清单](evidence/regina-a738-runtime-inventory.json)、[脚本来源清单](evidence/regina-a738-prepared-provenance.json)

两个自然入口均从实际 `RTXAcceptance.exe` 及旁边 PCK 运行，cwd 为导出游戏目录，未传 `--path`、`--script` 或 `--quit-after`。D3D12 的生产请求为 skate 两人、lighting=0，模拟截图时间 `1,4,8`；Vulkan 为 skate 一人、lighting=2，模拟截图时间 `15,30,45`。共同请求 quality=2、upscaling=7（DLSS Quality）、NIS sharpness=0、FG/HDR=false。生产脚本没有场景注入来读取有效环境值，所以这些设置字段仍按“请求”记录；实际 PT/RR 视口 readback 由独立游戏 harness 另行覆盖，不从生产配置单独推断模型、preset 或 FG 已生效。

每例实际生成三张 PNG、版本/API/GPU/CLI game 检查通过、无 ERROR/SCRIPT ERROR/SHADER ERROR 且进程 exit 0。180 秒只作外部超时清理，未设置墙钟通过阈值；`--at`/固定步长不是 FPS 测量。主 EXE 自然退出后，Windows Job 仍关闭了各自记录的一批子进程，随后 NGX updater 列表为空。这证明本轮受控清理完成，不能写作所有后代自行退出或长期无泄漏证明。实际子进程 PID 列表完整保留在原生回执中。

准备期 [export-location](evidence/regina-a738-export-location-preparation.json) 的 `runtime_pending=true` **原样保留**。它是在生产运行前写下的历史状态；后续 [natural 矩阵](evidence/regina-a738-natural-matrix.json) 才记录两例实际完成，没有覆盖该历史记录。

| 实际生产包原图 | 所示范围 |
| --- | --- |
| [Vulkan 最后一张](images/regina-a738-production-vulkan-last.png) | 自然单人游玩机位，建筑/窗/彩色遮阳棚/地砖可见；不是相同固定机位的前后因果比较 |
| [D3D12 最后一张](images/regina-a738-production-d3d12-last.png) | 双人分屏、自然相机与场景正常；不是 D3D12 路径追踪验收 |

## 尚未扩大的结论

旧 d37 六项 Streamline Vulkan 严格验证失败仍保留；本次 COLOR 恢复不解决它们。D3D12、实际 DLSS AI 模型、普通 FG/Reflex 物理延迟、HDR、BLE/真实手柄、RTX50/MFG、长期性能和全部物理插件的功能边界未因本次材质测试扩大。

未执行/PENDING：本轮没有新增实际 AI 模型身份覆盖层确认、普通 FG/Reflex 物理延迟测试、HDR/BLE/真实手柄或 RTX50/MFG 验收，也没有重做旧 d37 的六个严格验证失败用例。生产入口的设置请求、正常渲染或 exit 0 都不替代这些独立项目。

本轮所列材质修复、构建、游戏矩阵、模板与实际生产包的真实结果可进入代码审查；冷异步灰图、严格验证失败及未测能力仍需明确披露，不能声明全部引擎功能通过。发布/合并决定仍须完成差异、许可和私有依赖复核。本证据记录只含文本和真实原图，不含 SDK/DLL、权重、二进制或游戏素材包，既有许可不变。诊断、代码和整理有 OpenAI Codex 辅助，没有生成 GPU 截图、日志、性能数据或 native 通过记录。
