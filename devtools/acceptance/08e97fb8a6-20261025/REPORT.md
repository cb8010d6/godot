# 固定提交 08e97fb8a6 的 Windows / RTX 验收

日期：2026-10-25（Australia/Sydney）。**本轮没有完成实际 DLSS 4.5 模型确认，不能据此宣布全面验收通过。** 构建、实际 GPU 请求/运行和对应特性链检查已执行；D3D12 调试层已取得新的根因对照。

2026-10-26补充：用户说明此前只是没有留意覆盖层，不能把“未观察到”解释为字段没有显示。新的桌面尝试再次被Esc中止；本轮仍没有活动模型截图。远端状态只读核对显示integration已前进到`eface96b72e`，但本报告的实测对象仍为08e，本轮报告/证据归档在`validation/results-08e97fb8a6`，诊断代码另存`diagnostic/d3d12-legacy-08e97fb8a6`，以保留候选和诊断的边界。

## 1. 固定代码与机器

主验收源码：`08e97fb8a6871cfe39f83a24e2a5813936efd208`，本地分支 `validation/fixed-08e97fb8a6`。来自用户 fork 的 integration/dlss45-windows-validation，完整 SHA 已从云端解析、获取。开始与结束时工作区均干净；五个图形修复、FOV/相机轴修正、SR policy 和 Vulkan 特性链改动已核对。没有修改该候选的生产代码。

诊断标准编辑器单独来自 `a182f0c9f24411242f18b68aa5d91ece9acb983e`，其基线为固定候选，仅添加本地启动追踪和受控 legacy 开关。最后诊断知识库提交在 `diagnostic/d3d12-legacy-08e97fb8a6`，不属于候选、不作为生产修复，单独归档在诊断分支。最终已切回固定候选，并从保存副本恢复相同哈希的标准编辑器。

Windows 10 Pro 19045；Ryzen 9 7940H，8核16线程，32 GiB；RTX4060 Laptop 8GB，驱动610.88。VS2022 Community17.14.42，MSVC19.44.35229.0（工具目录14.44.35207），WindowsSDK10.0.26100.0。Python3.12.10/SCons4.11.1；便携.NET SDK10.0.402/runtime10.0.13，项目net10.0。PhysX5.10.0/ovphysx-0.5.11、真实CUDA12.8、Blast/Flow沿用已构建依赖。没有独立VulkanSDK；仓库头1.4.335，GPU API1.4.341；验证层1.4.366。

本轮下载、NuGet/临时目录、构建与验收产物使用F盘。NVIDIA驱动/App自己的系统缓存活动不受SDK OTA开关控制，没有宣称系统盘零写入。GPU测试串行，构建4并发/后台优先级；本轮自有进程树使用Job回收。

## 2. 构建、冒烟和实际模板导出

```powershell
devtools\build\build.ps1 -Target release -KeepGoing -Jobs 4 -VersionStatus beta1
devtools\test\smoke.ps1
devtools\test\smoke.ps1 -Mono
devtools\package\package_editor_win64.ps1
devtools\package\package_editor_win64.ps1 -Mono
devtools\package\package_templates_win64.ps1
devtools\package\package_templates_win64.ps1 -Mono
```

- **六目标真实MSVC构建通过，532.375秒**：两种编辑器、标准/Mono各Debug和Release模板，含glue及Debug/Release托管程序集。引擎版本为`4.8.beta1[.mono].custom_build.08e97fb8a`。
- 标准/Mono四项仓库冒烟均通过，包括真实PhysX落体、编辑器、Vulkan PT和DDGI。
- 四种生产模板PCK自动加载检查通过，标准各83项、Mono各84项；未绕过生产模板的路径保护。
- 四个真实公共ZIP/TPZ均完成打包和私有NVIDIA runtime排除检查；未上传发布包。
- 从`4.8.beta1`、`4.8.beta1.mono`安装目录默认查找模板，标准Debug/Release嵌入PCK游戏及Mono Debug/Release自包含游戏均导出并在真实D3D12/RTX上运行。Mono移除SDK查找环境后仍通过typed/dictionary PhysX查询断言。详见[四种导出结果](installed-exports.json)及各目录inventory.json。
- [12个原生可执行文件清单与SHA-256](fixed-binary-inventory.json)。本轮没有重跑Windows全量引擎单测或源生成器43项；不能把先前/云端计数记为当前头通过。

过程失败均保留：首次headless导入在共享缓存下出现EditorNode singleton错误，新旧引擎的干净项目对照都复现（控制中有0xC0000005退出）；新头暖导入两次正常。[导入对照](import-controls.json)。首次Mono导出还原运行库耗时553秒，导出退出0但出现safe-save错误，按失败保留。改用独立编辑器缓存后两种Mono导出/运行都无引擎错误；这支持缓存干扰，**不是已修复引擎缓存根因的声明**。未关闭杀毒或safe-save。观察到首次发布命令带GodotFloat64=true；本轮未完成其独立精度/interop审计，不据基本游戏通过宣称双精度覆盖。

已有ANGLE可选依赖、包readme及上游Pkcs9.0.10告警保留，没有宣称零警告。

## 3. SR请求策略与实际模型

MSVC `/W4 /WX` 编译执行：**85项参数检查、18次类型化SR回调捕获通过**，API smoke通过；这些是CPU边界检查，不是模型证据。

两个后端共**30个真实GPU请求/运行用例，30个通过**。Recommended在DLAA/Quality/Balanced请求K=11、Performance请求M=13、UltraPerformance请求L=12；另有K/M/L强制、默认`?`、1280×720/1400×600/600×900窗口。逐次核对实际backend、真实slDLSSSetOptions typed字段、`sl::eOk`、完整运行标记及错误日志。[SR矩阵](sr-matrix.json)。

Vulkan/D3D12各另跑7200更新的Recommended/Performance窗口，实际请求M、返回eOk、运行结束正常。代表性只读SDK状态记录SL2.14.16、NGX310.9.16（旧运行库对照另记实际版本），加载路径/哈希保留在相应状态和inventory中。原始报告里的scene frame budget是场景更新数，不冒充显示器实际呈现帧数。

另有两后端K/M/L Quality共六个图像捕获用例，均退出0、无引擎错误并保存真实应用viewport PNG：[捕获清单](sr-capture.json)。已查看实际场景图；这只是有限的非空渲染检查，不是生成帧视频、完整重影验收、画质提升或活动模型证明。应用PNG没有NVIDIA呈现覆盖层。

**实际模型仍未确认。** NVIDIA App Statistics已由用户手动操作；自动窗口截图最初报FrameArrived timed out，随后Computer Use通道被物理Escape停止，未取得能证明运行模型的覆盖层截图。用户发送的设置截图显示Statistics/Custom界面，不是活动模型证据。待补Vulkan与D3D12各一张运行时Model/Preset/版本覆盖层证据。

只读NVAPI再次记录全局SR/RR/FG Override开启，SR/RR preset原始值0x00FFFFFF，FG值0x00FFFFFE，MFG count0；未找到独立测试程序profile，本轮未保存驱动配置修改。[只读回执](nvidia-overrides-readonly-current.json)。SDK禁用OTA不关闭驱动自己的更新器/覆盖。**M/L请求、SDK/NGX版本、model-set编号、非空画面都不构成DLSS4.5模型确认。**

核对方法参考[NVIDIA官方DLSS4.5 FAQ](https://www.nvidia.com/en-us/geforce/forums/geforce-graphics-cards/5/580689/dlss-45-super-resolution-faq/)及[SDK2.14.16指南](https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/docs/ProgrammingGuideDLSS.md)。

## 4. Vulkan 1.4和NIS/FG隔离

六组实际API均1.4.341，日志确认验证层加载。目标VUID在六组均为0；先前138控制同层会报告该VUID。**特性链修正在这些实际1.4用例通过；不是所有VUID通过。**

| 用例 | API | pNext-02830次数 | SYNC次数 | 全部严格验证干净 |
| --- | --- | --- | --- | --- |
| vk14-control-no-sl | 1.4.341 | 0 | 0 | False |
| vk14-control-214-nis0-fg0 | 1.4.341 | 0 | 0 | False |
| vk14-control-214-nis1-fg0 | 1.4.341 | 0 | 10 | False |
| vk14-control-214-nis0-fg1 | 1.4.341 | 0 | 20 | False |
| vk14-control-214-nis1-fg1 | 1.4.341 | 0 | 20 | False |
| vk14-control-210-nis0-fg0 | 1.4.341 | 0 | 0 | False |

[完整计数与控制配置](vulkan14-controls.json)。NIS0/FG0为0条SYNC，NIS开启或FG开启仍存在内部同步/格式/交换链诊断；Win32 surface hinstance诊断也仍存在。全量原始日志保留，未压制。未测试旧于Vulkan1.2的实际硬件路径。

## 5. 保留的图形修复及回归

两后端各48个实际运动截帧，与同场景旧native控制对照，保留前8帧但仅在稳定统计中排除：新头相位偏移均约**-0.004105帧**，先前缺陷约0.988额外帧。[相位测量](motion-analysis.json)。不是物理输入延迟测量。

D3D12游戏模式三次完整场景中，额外呈现2/eOk且前台PID一致的样本分别591/589/589，各613个样本。[FG结果](fg-scene-summary.json)。Vulkan FG开关对照也实际运行。RTX40普通2X和Reflex状态仍可用；viewport PNG不含中间生成帧，没有据此宣称生成帧画质或物理延迟通过。Vulkan复杂PT/RR实际运行、29张原始PNG以及多视口/guide状态保留，常规运行无引擎错误。[回归回执](fixed-regressions.json)。

本轮未重新插桩捕获每个camera constants字段，不把#17/#18旧head的逐例计数转记为08e通过。新相机代码已审查、编译并用于本轮动态场景。RR preset与SR policy保持独立；未新增MFG控制。RTX50/6X/Dynamic MFG未测试，Vulkan Dynamic MFG不支持的既有限制保持。

## 6. D3D12调试层归因

此部分使用明确单列的诊断衍生二进制，不冒充固定08e的原始二进制。legacy开关在必要库加载后跳过factory，保留相同LUID、请求11_0、IID_ID3D12Device；正常D3D12实际能力12_0。使用只调试自身子进程的原生launcher捕获设备创建前的OutputDebugString，Job回收后代。[8组完整矩阵](d3d12-matrix.json)。

| 用例 | 实际后端 | 首个CreateDevice HRESULT | Core/Layer不匹配消息 |
| --- | --- | --- | --- |
| d3d12-no-sl-factory-normal | d3d12 | 0x00000000 | 0 |
| d3d12-no-sl-factory-validation | d3d12 | 0x00000000 | 0 |
| d3d12-no-sl-legacy-normal | d3d12 | 0x00000000 | 0 |
| d3d12-no-sl-legacy-validation | vulkan | 0x80070057 | 2 |
| d3d12-sl210-legacy-normal | d3d12 | 0x00000000 | 0 |
| d3d12-sl210-legacy-validation | vulkan | 0x80070057 | 3 |
| d3d12-sl214-legacy-normal | d3d12 | 0x00000000 | 0 |
| d3d12-sl214-legacy-validation | vulkan | 0x80070057 | 3 |

关键证据：**无SL强制legacy也失败**，因此先前factory/no-SL与legacy/SL的比较混入了runtime路径变量。三个失败行都明确报SDKLayers与Core的SDKVersion不匹配：系统Core10.0.19041.7291搭配应用目录SDKLayers1.618.5.0.20251205.1；factory使用本地Core/SDKLayers配套版本1.618.5.0.20251205.1并成功。系统也安装SDKLayers10.0.19041.5794，但失败路径实际选中了应用目录的另一版本。

[实际模块版本/哈希](d3d12-module-inventory.json)及每行`.debug.log`保存调用期间的模块/函数所有者。系统/本地同名Core可能在后续CUDA等初始化阶段共同出现，不能把较晚的load event直接当作渲染device使用的Core；使用创建前后追踪归因。

这是**已复现并定位的legacy运行库/调试层选择问题，未实现生产修复**，也不是2.14特有回归。没有删换Agility DLL来造通过。后续修复应选择匹配的runtime/layer组合并重跑矩阵，不能仅转发一个GetDebugInterface指针。诊断版第一次因我使用错误DXGI GetDesc1接口编译失败，纠正为GetDesc后重建通过，首个失败日志保留。

### 升级前引擎对照（2026-10-26）

复用保存的真实旧引擎`25f6a147ed8ca36d521638ba2b5fe1715a3cbdaa`（4.8-dev），没有重新编译。旧/新副本的Core和SDKLayers文件哈希一致，D3D12驱动代码及依赖安装脚本在25f6到阶段A之间没有差异。普通旧版SL2.10启动为D3D12；加`--gpu-validation`后同样0x80070057、Core/Layer mismatch并回退Vulkan；旧版无SL factory加调试层则成功。[新增三个对照](prebeta-comparison.json)。

因此**在当前相同依赖环境下，该复现不是beta1才出现的问题**。这不是对旧机器历史驱动/操作系统状态的重建；也不证明beta1所有其他D3D12行为都没有变化。旧引擎没有新版SDK OTA opt-out，控制日志显示其可加载驱动缓存的下载插件，不能把该行声称为完全禁OTA、纯旧模型验收；本对照聚焦早于SR求值的legacy设备/调试层选择。

## 7. 验收结论

| 项目 | 状态 |
| --- | --- |
| 固定08e六种Windows构建 | 已通过 |
| 标准/.NET冒烟、四种安装模板导出运行 | 最终夹具通过；过程导入/缓存失败及对照保留 |
| Recommended K/M/L、强制M/L、默认? | CPU边界及30个真实GPU用例通过 |
| 实际DLSS4.5 SR模型 | **未确认，缺实际覆盖层证据** |
| Vulkan1.4特性链目标VUID | 六组实际用例消失 |
| Vulkan NIS/FG全面严格验证 | **仍失败** |
| D3D12普通运行 | 当前候选及诊断控制可用 |
| D3D12调试层legacy | **仍失败；已定位Core/SDKLayers不匹配** |
| RR、普通FG2X、Reflex及既有图形修复 | 指定回归实际运行；不包括生成帧视频或物理延迟验收 |
| 是否建议合并/发布 | 可继续Draft审查；当前不建议直接发布或宣称全部通过 |

剩余项目：模型覆盖层、legacy配套修复、NIS/FG严格诊断、首次导入/文档缓存缺陷、首次C#publish精度标志核对、长期稳定性/RTX50/物理延迟/生成帧视觉验收。用户要求的排查和对照已执行，模型确认这一步仍待证据。本次仅归档报告、证据和独立诊断分支；没有创建PR或发布Release。

最终[资源快照](final-resource-state.json)中**本轮Godot/NGX均为0**；全机另有其他工作区的Godot任务，未处理它们。快照可用内存约15GiB，具体为一时观测，不能证明系统完全无泄漏。SDK/DLL、原始桌面/进程证据都留在本地；本目录发布去路径化日志/回执及原始应用viewport PNG。AI协助实现测试工具、诊断和报告；所有运行/编译/截图数据均来自实际执行，没有生成伪造图像或通过记录。

结果文档分支为`validation/results-08e97fb8a6`（本次归档前文档提交`33adb12800abc19d0164ec4fa094b988fabcec99`）；诊断记录分支为`diagnostic/d3d12-legacy-08e97fb8a6` / `1232c5cc4e`（其中实际测试二进制为a182，末提交只更新知识库）。工作区最终保持固定08e。报告与诊断分支独立归档，不推进integration分支；该分支的后续云端提交不在本轮验收范围内。

## 8. 命令与日志索引

公开副本替换本机绝对路径、规范化LF换行并格式化JSON；少数原始非UTF-8日志字节用十六进制转义保留，不丢弃。数字、错误、退出码、时间和图像不改。原始/公开SHA-256见[证据清单](publication-manifest.json)，目录范围与复现说明见[README](README.md)。表中日志为去路径化副本。

退出0不等于验收通过；Vulkan fallback、VUID以及夹具错误按上文单列。source_sha是执行时检出，输入二进制另有哈希及版本，诊断版与候选版不可混记。

| 标签 | 退出码 | 秒 | 引擎ERROR行数 | 原始证据 |
| --- | --- | --- | --- | --- |
| `build-d3d12-diagnostic-fixed` | 0 | 42.969 | 0 | [log](logs/build-d3d12-diagnostic-fixed.log), [receipt](build-d3d12-diagnostic-fixed.json) |
| `build-d3d12-diagnostic` | 1 | 111.828 | 0 | [log](logs/build-d3d12-diagnostic.log), [receipt](build-d3d12-diagnostic.json) |
| `compile-local-debug-capture` | 0 | 2.594 | 0 | [log](logs/compile-local-debug-capture.log), [receipt](compile-local-debug-capture.json) |
| `d3d12-no-sl-factory-normal` | 0 | 50.375 | 0 | [log](logs/d3d12-no-sl-factory-normal.log), [receipt](d3d12-no-sl-factory-normal.json) |
| `d3d12-no-sl-factory-validation` | 0 | 9.218 | 0 | [log](logs/d3d12-no-sl-factory-validation.log), [receipt](d3d12-no-sl-factory-validation.json) |
| `d3d12-no-sl-legacy-normal` | 0 | 9.109 | 0 | [log](logs/d3d12-no-sl-legacy-normal.log), [receipt](d3d12-no-sl-legacy-normal.json) |
| `d3d12-no-sl-legacy-validation` | 0 | 22.172 | 3 | [log](logs/d3d12-no-sl-legacy-validation.log), [receipt](d3d12-no-sl-legacy-validation.json) |
| `d3d12-sl210-legacy-normal` | 0 | 83.906 | 0 | [log](logs/d3d12-sl210-legacy-normal.log), [receipt](d3d12-sl210-legacy-normal.json) |
| `d3d12-sl210-legacy-validation` | 0 | 40.329 | 34 | [log](logs/d3d12-sl210-legacy-validation.log), [receipt](d3d12-sl210-legacy-validation.json) |
| `d3d12-sl214-legacy-normal` | 0 | 95.657 | 0 | [log](logs/d3d12-sl214-legacy-normal.log), [receipt](d3d12-sl214-legacy-normal.json) |
| `d3d12-sl214-legacy-validation` | 0 | 46.735 | 34 | [log](logs/d3d12-sl214-legacy-validation.log), [receipt](d3d12-sl214-legacy-validation.json) |
| `fixed08e-d3d12-motion` | 0 | 10.938 | 0 | [log](logs/fixed08e-d3d12-motion.log), [receipt](fixed08e-d3d12-motion.json) |
| `fixed08e-fg-d3d12-scenes` | 0 | 73.235 | 0 | [log](logs/fixed08e-fg-d3d12-scenes.log), [receipt](fixed08e-fg-d3d12-scenes.json) |
| `fixed08e-rr-complex` | 0 | 82.157 | 0 | [log](logs/fixed08e-rr-complex.log), [receipt](fixed08e-rr-complex.json) |
| `fixed08e-vulkan-motion` | 0 | 12.657 | 0 | [log](logs/fixed08e-vulkan-motion.log), [receipt](fixed08e-vulkan-motion.json) |
| `import-control-08e-fresh` | 3221225477 | 4.156 | 1 | [log](logs/import-control-08e-fresh.log), [receipt](import-control-08e-fresh.json) |
| `import-control-08e-warm-1` | 0 | 3.953 | 0 | [log](logs/import-control-08e-warm-1.log), [receipt](import-control-08e-warm-1.json) |
| `import-control-08e-warm-2` | 0 | 3.922 | 0 | [log](logs/import-control-08e-warm-2.log), [receipt](import-control-08e-warm-2.json) |
| `import-control-138-fresh` | 3221225477 | 4.688 | 1 | [log](logs/import-control-138-fresh.log), [receipt](import-control-138-fresh.json) |
| `installed-import-standard` | 3221225477 | 5.171 | 1 | [log](logs/installed-import-standard.log), [receipt](installed-import-standard.json) |
| `installed-mono-debug-export` | 0 | 553.219 | 1 | [log](logs/installed-mono-debug-export.log), [receipt](installed-mono-debug-export.json) |
| `installed-standard-debug-export` | 0 | 4.485 | 0 | [log](logs/installed-standard-debug-export.log), [receipt](installed-standard-debug-export.json) |
| `installed-standard-debug-run` | 0 | 5.328 | 0 | [log](logs/installed-standard-debug-run.log), [receipt](installed-standard-debug-run.json) |
| `installed-standard-release-export` | 0 | 4.297 | 0 | [log](logs/installed-standard-release-export.log), [receipt](installed-standard-release-export.json) |
| `installed-standard-release-run` | 0 | 4.297 | 0 | [log](logs/installed-standard-release-run.log), [receipt](installed-standard-release-run.json) |
| `managed-project-build` | 0 | 3.578 | 0 | [log](logs/managed-project-build.log), [receipt](managed-project-build.json) |
| `managed-solution-add` | 0 | 5.657 | 0 | [log](logs/managed-solution-add.log), [receipt](managed-solution-add.json) |
| `managed-solution-create` | 0 | 0.907 | 0 | [log](logs/managed-solution-create.log), [receipt](managed-solution-create.json) |
| `model-d3d12-recommended-performance` | 0 | 133.312 | 0 | [log](logs/model-d3d12-recommended-performance.log), [receipt](model-d3d12-recommended-performance.json) |
| `model-vulkan-recommended-performance` | 0 | 130.562 | 0 | [log](logs/model-vulkan-recommended-performance.log), [receipt](model-vulkan-recommended-performance.json) |
| `msvc-preset-and-api-checks` | 0 | 2.453 | 0 | [log](logs/msvc-preset-and-api-checks.log), [receipt](msvc-preset-and-api-checks.json) |
| `native-debugger-control` | 0 | 0.078 | 0 | [log](logs/native-debugger-control.log), [receipt](native-debugger-control.json) |
| `nvidia-overrides-readonly-current` | 0 | 0.282 | 0 | [log](logs/nvidia-overrides-readonly-current.log), [receipt](nvidia-overrides-readonly-current.json) |
| `package-editor-mono` | 0 | 32.0 | 0 | [log](logs/package-editor-mono.log), [receipt](package-editor-mono.json) |
| `package-editor-standard` | 0 | 25.062 | 0 | [log](logs/package-editor-standard.log), [receipt](package-editor-standard.json) |
| `package-templates-mono` | 0 | 9.36 | 0 | [log](logs/package-templates-mono.log), [receipt](package-templates-mono.json) |
| `package-templates-standard` | 0 | 9.016 | 0 | [log](logs/package-templates-standard.log), [receipt](package-templates-standard.json) |
| `pck-mono-debug` | 0 | 7.89 | 0 | [log](logs/pck-mono-debug.log), [receipt](pck-mono-debug.json) |
| `pck-mono-release` | 0 | 6.5 | 0 | [log](logs/pck-mono-release.log), [receipt](pck-mono-release.json) |
| `pck-standard-debug` | 0 | 7.125 | 0 | [log](logs/pck-standard-debug.log), [receipt](pck-standard-debug.json) |
| `pck-standard-release` | 0 | 6.61 | 0 | [log](logs/pck-standard-release.log), [receipt](pck-standard-release.json) |
| `prebeta-no-sl-validation` | 0 | 9.953 | 0 | [log](logs/prebeta-no-sl-validation.log), [receipt](prebeta-no-sl-validation.json) |
| `prebeta-sdk210-normal` | 0 | 119.094 | 0 | [log](logs/prebeta-sdk210-normal.log), [receipt](prebeta-sdk210-normal.json) |
| `prebeta-sdk210-validation` | 0 | 51.406 | 34 | [log](logs/prebeta-sdk210-validation.log), [receipt](prebeta-sdk210-validation.json) |
| `release-all-fixed-08e` | 0 | 532.375 | 0 | [log](logs/release-all-fixed-08e.log), [receipt](release-all-fixed-08e.json) |
| `repo-smoke-mono` | 0 | 26.578 | 0 | [log](logs/repo-smoke-mono.log), [receipt](repo-smoke-mono.json) |
| `repo-smoke-standard` | 0 | 29.515 | 0 | [log](logs/repo-smoke-standard.log), [receipt](repo-smoke-standard.json) |
| `rerun-installed-mono-debug-export` | 0 | 10.984 | 0 | [log](logs/rerun-installed-mono-debug-export.log), [receipt](rerun-installed-mono-debug-export.json) |
| `rerun-installed-mono-debug-run` | 0 | 5.937 | 0 | [log](logs/rerun-installed-mono-debug-run.log), [receipt](rerun-installed-mono-debug-run.json) |
| `rerun-installed-mono-release-export` | 0 | 12.172 | 0 | [log](logs/rerun-installed-mono-release-export.log), [receipt](rerun-installed-mono-release-export.json) |
| `rerun-installed-mono-release-run` | 0 | 3.718 | 0 | [log](logs/rerun-installed-mono-release-run.log), [receipt](rerun-installed-mono-release-run.json) |
| `sr-capture-d3d12-k` | 0 | 13.219 | 0 | [log](logs/sr-capture-d3d12-k.log), [receipt](sr-capture-d3d12-k.json) |
| `sr-capture-d3d12-l` | 0 | 12.313 | 0 | [log](logs/sr-capture-d3d12-l.log), [receipt](sr-capture-d3d12-l.json) |
| `sr-capture-d3d12-m` | 0 | 12.609 | 0 | [log](logs/sr-capture-d3d12-m.log), [receipt](sr-capture-d3d12-m.json) |
| `sr-capture-vulkan-k` | 0 | 17.359 | 0 | [log](logs/sr-capture-vulkan-k.log), [receipt](sr-capture-vulkan-k.json) |
| `sr-capture-vulkan-l` | 0 | 12.938 | 0 | [log](logs/sr-capture-vulkan-l.log), [receipt](sr-capture-vulkan-l.json) |
| `sr-capture-vulkan-m` | 0 | 12.969 | 0 | [log](logs/sr-capture-vulkan-m.log), [receipt](sr-capture-vulkan-m.json) |
| `sr-d3d12-default-performance-1280x720` | 0 | 10.969 | 0 | [log](logs/sr-d3d12-default-performance-1280x720.log), [receipt](sr-d3d12-default-performance-1280x720.json) |
| `sr-d3d12-k-dlaa-1400x600` | 0 | 11.156 | 0 | [log](logs/sr-d3d12-k-dlaa-1400x600.log), [receipt](sr-d3d12-k-dlaa-1400x600.json) |
| `sr-d3d12-k-performance-600x900` | 0 | 10.938 | 0 | [log](logs/sr-d3d12-k-performance-600x900.log), [receipt](sr-d3d12-k-performance-600x900.json) |
| `sr-d3d12-k-quality-1280x720` | 0 | 11.078 | 0 | [log](logs/sr-d3d12-k-quality-1280x720.log), [receipt](sr-d3d12-k-quality-1280x720.json) |
| `sr-d3d12-l-dlaa-1400x600` | 0 | 10.953 | 0 | [log](logs/sr-d3d12-l-dlaa-1400x600.log), [receipt](sr-d3d12-l-dlaa-1400x600.json) |
| `sr-d3d12-l-performance-600x900` | 0 | 10.937 | 0 | [log](logs/sr-d3d12-l-performance-600x900.log), [receipt](sr-d3d12-l-performance-600x900.json) |
| `sr-d3d12-l-quality-1280x720` | 0 | 10.937 | 0 | [log](logs/sr-d3d12-l-quality-1280x720.log), [receipt](sr-d3d12-l-quality-1280x720.json) |
| `sr-d3d12-m-dlaa-1400x600` | 0 | 10.953 | 0 | [log](logs/sr-d3d12-m-dlaa-1400x600.log), [receipt](sr-d3d12-m-dlaa-1400x600.json) |
| `sr-d3d12-m-performance-600x900` | 0 | 11.282 | 0 | [log](logs/sr-d3d12-m-performance-600x900.log), [receipt](sr-d3d12-m-performance-600x900.json) |
| `sr-d3d12-m-quality-1280x720` | 0 | 11.0 | 0 | [log](logs/sr-d3d12-m-quality-1280x720.log), [receipt](sr-d3d12-m-quality-1280x720.json) |
| `sr-d3d12-recommended-balanced-1280x720` | 0 | 10.938 | 0 | [log](logs/sr-d3d12-recommended-balanced-1280x720.log), [receipt](sr-d3d12-recommended-balanced-1280x720.json) |
| `sr-d3d12-recommended-dlaa-1280x720` | 0 | 11.141 | 0 | [log](logs/sr-d3d12-recommended-dlaa-1280x720.log), [receipt](sr-d3d12-recommended-dlaa-1280x720.json) |
| `sr-d3d12-recommended-performance-1280x720` | 0 | 10.969 | 0 | [log](logs/sr-d3d12-recommended-performance-1280x720.log), [receipt](sr-d3d12-recommended-performance-1280x720.json) |
| `sr-d3d12-recommended-quality-1280x720` | 0 | 11.016 | 0 | [log](logs/sr-d3d12-recommended-quality-1280x720.log), [receipt](sr-d3d12-recommended-quality-1280x720.json) |
| `sr-d3d12-recommended-ultra_performance-1280x720` | 0 | 11.328 | 0 | [log](logs/sr-d3d12-recommended-ultra_performance-1280x720.log), [receipt](sr-d3d12-recommended-ultra_performance-1280x720.json) |
| `sr-vulkan-default-performance-1280x720` | 0 | 12.969 | 0 | [log](logs/sr-vulkan-default-performance-1280x720.log), [receipt](sr-vulkan-default-performance-1280x720.json) |
| `sr-vulkan-k-dlaa-1400x600` | 0 | 11.437 | 0 | [log](logs/sr-vulkan-k-dlaa-1400x600.log), [receipt](sr-vulkan-k-dlaa-1400x600.json) |
| `sr-vulkan-k-performance-600x900` | 0 | 11.61 | 0 | [log](logs/sr-vulkan-k-performance-600x900.log), [receipt](sr-vulkan-k-performance-600x900.json) |
| `sr-vulkan-k-quality-1280x720` | 0 | 11.375 | 0 | [log](logs/sr-vulkan-k-quality-1280x720.log), [receipt](sr-vulkan-k-quality-1280x720.json) |
| `sr-vulkan-l-dlaa-1400x600` | 0 | 11.766 | 0 | [log](logs/sr-vulkan-l-dlaa-1400x600.log), [receipt](sr-vulkan-l-dlaa-1400x600.json) |
| `sr-vulkan-l-performance-600x900` | 0 | 11.516 | 0 | [log](logs/sr-vulkan-l-performance-600x900.log), [receipt](sr-vulkan-l-performance-600x900.json) |
| `sr-vulkan-l-quality-1280x720` | 0 | 11.468 | 0 | [log](logs/sr-vulkan-l-quality-1280x720.log), [receipt](sr-vulkan-l-quality-1280x720.json) |
| `sr-vulkan-m-dlaa-1400x600` | 0 | 11.969 | 0 | [log](logs/sr-vulkan-m-dlaa-1400x600.log), [receipt](sr-vulkan-m-dlaa-1400x600.json) |
| `sr-vulkan-m-performance-600x900` | 0 | 11.453 | 0 | [log](logs/sr-vulkan-m-performance-600x900.log), [receipt](sr-vulkan-m-performance-600x900.json) |
| `sr-vulkan-m-quality-1280x720` | 0 | 11.5 | 0 | [log](logs/sr-vulkan-m-quality-1280x720.log), [receipt](sr-vulkan-m-quality-1280x720.json) |
| `sr-vulkan-recommended-balanced-1280x720` | 0 | 11.344 | 0 | [log](logs/sr-vulkan-recommended-balanced-1280x720.log), [receipt](sr-vulkan-recommended-balanced-1280x720.json) |
| `sr-vulkan-recommended-dlaa-1280x720` | 0 | 12.218 | 0 | [log](logs/sr-vulkan-recommended-dlaa-1280x720.log), [receipt](sr-vulkan-recommended-dlaa-1280x720.json) |
| `sr-vulkan-recommended-performance-1280x720` | 0 | 11.406 | 0 | [log](logs/sr-vulkan-recommended-performance-1280x720.log), [receipt](sr-vulkan-recommended-performance-1280x720.json) |
| `sr-vulkan-recommended-quality-1280x720` | 0 | 11.453 | 0 | [log](logs/sr-vulkan-recommended-quality-1280x720.log), [receipt](sr-vulkan-recommended-quality-1280x720.json) |
| `sr-vulkan-recommended-ultra_performance-1280x720` | 0 | 11.266 | 0 | [log](logs/sr-vulkan-recommended-ultra_performance-1280x720.log), [receipt](sr-vulkan-recommended-ultra_performance-1280x720.json) |
| `vk14-control-210-nis0-fg0` | 0 | 11.094 | 25 | [log](logs/vk14-control-210-nis0-fg0.log), [receipt](vk14-control-210-nis0-fg0.json) |
| `vk14-control-214-nis0-fg0` | 0 | 11.375 | 37 | [log](logs/vk14-control-214-nis0-fg0.log), [receipt](vk14-control-214-nis0-fg0.json) |
| `vk14-control-214-nis0-fg1` | 0 | 12.375 | 78 | [log](logs/vk14-control-214-nis0-fg1.log), [receipt](vk14-control-214-nis0-fg1.json) |
| `vk14-control-214-nis1-fg0` | 0 | 10.953 | 47 | [log](logs/vk14-control-214-nis1-fg0.log), [receipt](vk14-control-214-nis1-fg0.json) |
| `vk14-control-214-nis1-fg1` | 0 | 12.469 | 88 | [log](logs/vk14-control-214-nis1-fg1.log), [receipt](vk14-control-214-nis1-fg1.json) |
| `vk14-control-no-sl` | 0 | 6.515 | 1 | [log](logs/vk14-control-no-sl.log), [receipt](vk14-control-no-sl.json) |
