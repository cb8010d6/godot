# Stabilization acceptance bundle

本包是已有真实测量的精简公开副本；没有在整理阶段启动引擎、编译或运行GPU测试。请先读[21项报告](REPORT.md)。当前SDK Vulkan严格验证仍失败，不是RC声明。

## 证据与隐私

- `evidence/` 为原矩阵实际字段的派生摘要或已脱敏raw JSON；每项附原文件SHA256，状态直接取原记录。Launcher两份文件保留原schema，没有新增成功JSON。
- `logs/` 为精选完整日志，仅替换隐私文本，不删除错误、警告、失败段或行。
- `images/` 八张代表性真实PNG保留原始bytes，没有裁剪、重采样、涂改或图像生成；已目视检查无个人路径/用户名/房间凭证，哈希见[MANIFEST](MANIFEST.json)。
- 私有原件保持原样。`<WORKSPACE>`、`<PRIVATE_ACCEPTANCE_ROOT>`、`<LEGACY_ACCEPTANCE_ROOT>`、`<SOURCE_ROOT>`、`<USERPROFILE>`、`<SYSTEM32>`、`<PROGRAM_FILES>`、`<ABS_ROOT>`、`<USER>`、`<HOST>` 是明确脱敏占位符，不是可执行路径。
- 未归档SDK运行库、exe/lib/so、zip/tpz/res、私钥或Hub启动stdout/stderr。未知的旧本地链接只标“本地原始记录”，不伪造公开URL。
- C1源码SHA与d37测量SHA分开。未假定未推送的个人仓库C1URL可访问；源码位置以报告中的仓库相对code path和提交号定位。

## 代表图与范围

| 图 | 能证明的内容 |
| --- | --- |
| [Ultra L](images/sdk214-vulkan-ultra-L.png) / [Quality M](images/sdk214-d3d12-quality-M.png) / [Balanced K](images/sdk214-vulkan-balanced-K.png) | 真实渲染与指示器的preset/runtime；不等同所有模型权重身份 |
| [RR玻璃](images/rr-glass.png) / [guide31](images/rr-guide-31.png) | 真实RR/guide输出，不能替代严格验证或统计画质评估 |
| [C1四人](images/game-c1-four-players.png) / [C1 PT+RR](images/game-c1-pt-rr.png) | 真实应用viewport输出，非插帧中间画面、非FPS/物理延迟测试 |
| [C1 Regina生产包四人](images/regina-c1-production-four-players.png) | 实际导出PCK自身CLI捕获的四人1600×900输出，最终两API自然退出见原始矩阵 |

## 尚未完成的独立范围

Regina本体冷导入/release导出及两API生产包自然退出已有最终实际回执；[首轮script尝试记录](evidence/regina-c1-export-records.json)不作为捕获夹具通过，[中间frameguard派生FAIL](evidence/regina-c1-intermediate-guard-matrix.json)保留原值。启动器首轮wrapper失败与后续进程receipt分开解释，未用进程exit0改写首轮wrapper结果。
独立快捷入口已有[实际创建/读回JSON](evidence/desktop-nvidia-shortcut.json)，原快捷方式哈希保留；临时DLSS指示器的管理员恢复与只读复核、发布/PR仍未取得最终回执。仅interposer的partial-runtime两API回退保留eErrorNoPlugins，不能称无错误通过；未测试范围见报告第11节。
隐私/链接/PNG字节检查只验证本bundle的公开材料完整性，不把它标成GPU验收通过。自动检查结果和所有原件/公开件SHA见MANIFEST。
