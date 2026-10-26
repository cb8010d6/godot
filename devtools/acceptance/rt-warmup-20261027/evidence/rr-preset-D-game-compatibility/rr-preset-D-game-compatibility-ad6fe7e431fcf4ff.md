# RR-D 实际游戏：独立 CPU 审计

两项实际GPU记录的独立审计通过：单人和四人均为 `CLEAN / ESTABLISHED`，游戏正常进入PLAY，预热暂停、物理恢复及所有原始observer检查通过。本次审计仅重新读取、校验和解析既有证据，没有启动引擎或GPU。

| 实测项目 | 单人 | 四人 |
| --- | --- | --- |
| 原始 strict run | 20261026T202525Z-173685cc | 20261026T202918Z-454dbe42 |
| 实际 SL trace viewport IDs | 1、2 | 1、2、3、4、5 |
| 完整引导 tag / 非Off RR Evaluate eOk | 16 / 2 | 40 / 5 |
| 实际游戏活动视口 | 1 | 4 |
| 游戏视口 fresh-ready | 每视口至少2个不同真实serial | 四视口各serial1、2，TLAS2028，pending/failed0 |
| 实际SDK样本 | 130 | 130 |
| 实读RR版本 | SL2.14.16 / NGX310.9.16 | 相同 |
| SDK getter覆盖 | 仅viewport1/2 | 仅viewport1/2 |
| 归属、退出与回收 | 真实owned PID祖先链，exit0，Job/NGX清理通过 | 相同 |

编译二进制实际为 `8b1055662793954959fe5ce8b11843437af0adc3`，EXE SHA256 `e5d7ee0d0635ec9796917d4fcc15e2166b3783d0b0bd3817bc3c96c7718dd1c9`。录制时工作区为 `d29e7065306d670a643ca0ea7a362c4b38cea3c5`；两者独立记录并核对，没有冒充同一提交。快照的RT include、render_warmup、nvidia和party_game四文件与游戏提交 `3d51851c6eec09ff4cb8a2b0f818e837d06ca4e8` 原始Git blob逐SHA一致。

审计重新校验了每例48个冻结输入及所有已引用的原result、observer matrix、native receipt、raw log、module samples、wrapper和PLAY原PNG。PID记录与二进制路径/hash、observer命令、工作区SHA、每条已捕获祖先边相符。实际模块样本包含冻结路径的RR/SR/interposer及正确VVL；同步验证有读回，原日志没有VUID/SYNC错误；FG插件未加载，RTSS未采到。两例SL原生trace均记录非Off mode3/result0及每viewport八种tag。

机器可读详细证明：[AUDIT-GAME-D.json](AUDIT-GAME-D.json)，18,542字节，SHA256 `6b2511d4fa904062388b3457514011c95c4edc64e3fc88bea7d89f13338550d5`。

边界保留：

- D在第一次场景加载前由私有observer显式请求；引擎没有preset getter，不能称为实际preset/模型权重直接读回。
- 四人有五组SL trace：一组大厅尺寸、四组分屏尺寸，另有四个独立游戏视口的真实fresh-ready。SDK getter仍只查1/2；SL handle和Godot节点路径没有直接公开关联接口，不伪称逐四视口getter或直接handle映射。
- 原生marker证明每viewport首次真实RR Evaluate成功，不代表逐帧全部SDK状态。ready证明RT命令记录/有效live pipeline，不是GPU fence或物理present完成。
- 近景observer只在PLAY后覆盖首玩家相机。原PNG是实际捕获；本用例不是未经干预的自然生产运行、性能或延迟测量。
- 这是固定机器、SDK和场景下的D兼容路径实测。默认 `?` 和F的严格失败记录继续保留；没有修改游戏或引擎默认RR，也没有宣称通用SDK同步问题已修复、FG已验收或模型身份已确认。
