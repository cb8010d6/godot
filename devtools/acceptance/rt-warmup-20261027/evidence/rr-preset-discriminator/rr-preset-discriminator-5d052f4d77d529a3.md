# RR D/F 实测记录的独立 CPU 审查

结论：D 的 CLEAN 结果不是通过关闭 RR 得到的。原始日志实录 `SL_RR_EVALUATE viewport=1 mode=3 result=0`，并记录同一 viewport 的八种引导资源 tag。F 同样实际执行 RR，但仍报告同步错误。D 可作为这个固定环境下的兼容性候选；不能据此宣布全部 RR 问题解决或确认 AI 模型身份。

| 项目 | D | F |
| --- | --- | --- |
| 实际 native | 同一 8b1055662793954959fe5ce8b11843437af0adc3 / e5d7ee0d… EXE | 相同 |
| SDK 实读 | Streamline2.14.16 / RR NGX310.9.16 | 相同 |
| 非 Off RR Evaluate | viewport1、mode3、eOk0 | 相同 |
| 实际 tag | 0、1、3、4、7、8、14、42 | 相同 |
| 原生 SDK 样本 | 160 | 160 |
| 运动帧与原 PNG | 49 / 49 | 49 / 49 |
| 实验功能与基础设施检查 | 全部通过 | 全部通过 |
| 严格验证 | CLEAN，无 VUID/SYNC 错误 | FAIL：2条 WAW、2条09600消息 |

独立审查重新读取并匹配原日志、metadata、SDK state、frames、modules及全部98张原 PNG 的 SHA256，重新解析原生 Evaluate/tag 证据，并核对精确编译提交的 C++ 请求路径。结果见 [AUDIT-D-F.json](AUDIT-D-F.json)，SHA256 `c7eeca44967a5c1ac512fcea3f0155d7b284fed622dd359a953e1955a7cbb0f3`。审查没有启动引擎或 GPU，也没有改写原 `?`、D、F 结果。

`requested_rr_preset=D/F` 是请求元数据，不是 SDK 实际 preset getter。这个引擎只绑定 `set_parameter`、能力及 FG 状态接口，没有 `get_parameter`。精确8b源码证明：setter保存单字符 RR 请求，渲染器传入 `preset='?'`，RR分支读取该全局值，把D映射到SDK `ePresetD=4`、F映射到 `ePresetF=6`，再提交 `slDLSSDSetOptions`；提交失败会报引擎错误。本次D无此错误，且真实非Off RR Evaluate返回eOk。因此“确实请求并执行RR D路径”有源码和实测证据；“直接读回了内部实际preset或权重身份”没有证据。

SDK getter eOk只作辅助证据。现有探针只查询viewport1/2，即使未渲染的viewport2也可能返回eOk、估算显存0，不能单凭getter判断RR执行。这里的主要执行证据是实际原生 RR Evaluate 与对应引导资源。该探针没有运行库内部模型权重标识。

两例使用单视口、同一运动夹具、NIS0、FG插件不加载和同一VVL。VVL同步验证读回及实际模块路径检查通过，采样未见RTSS；两例都观察到了NVIDIA覆盖层模块 `nvspcap64.dll`，不能称为所有覆盖层绝对缺席。D/F的独立新profile不代表驱动缓存完全冷。F的2条09600消息在含规范引用的原日志中出现4次token；保留消息数和token数的单位区别。

后续只读NVAPI检查位于 `../../stabilization-20261026/driver-overrides-d29-readonly.json` 及对应原日志：支持读取的base/global SR、RR、FG override值为0；列出的应用profile返回-166不存在。`SL_DLSS_OVERRIDE`等-160项是未取得设置，不能冒称OFF。该检查是后续快照，不代替每一帧的模型状态。

真实<game>游戏的D预设1/4人严格对照使用独立工具目录，仍须另有实际运行结果。默认 `?` 及F失败记录继续保留；本报告不把D最小夹具结果外推为全游戏或所有设备通过。
