# 飞智 B9X 散热器 BLE 协议（逆向自官方飞智游戏厅 7.2.11）

> 来源：官方 APK `com.flydigi.sdk.waspwing` / `com.flydigi.sdk.bluetooth`，jadx 反编译。
> 仅用于互操作性实现（自研客户端控制自己拥有的硬件）。

## 1. 发现与连接

| 项目 | 值 |
| --- | --- |
| 广播名 | `Flydigi B9X` |
| 其他型号 | `Flydigi B3 / B5 / B5Pro / B5X / B6 / B6X / B7 / B7X / B8X` |
| Service | `0000FFE0-0000-1000-8000-00805F9B34FB` |
| Write 特征 | `0000FFE1-0000-1000-8000-00805F9B34FB` |
| Notify 特征 | `0000FFE4-0000-1000-8000-00805F9B34FB` |
| CCCD | `00002902-0000-1000-8000-00805F9B34FB` |
| 连接方式 | `connectGatt(ctx, false, cb, TRANSPORT_LE, PHY_LE_2M)` |
| 写类型 | `WRITE_TYPE_NO_RESPONSE`（1），无需应答 |
| 分包 | 单包 ≤ 20 字节（ATT 默认 MTU，未主动协商） |

流程：扫描（按名字过滤）→ 连接 → `discoverServices()` → 取 FFE1/FFE4 →
`setCharacteristicNotification(FFE4, true)` → 写 CCCD = `01 00` → 开始收发。

## 2. 命令帧（写 FFE1，原始字节，无帧头/校验）

| 帧 | 含义 | 参数 |
| --- | --- | --- |
| `11 LL` | 设风速档 | LL = 档位值（见 §4） |
| `12 LL` | 设制冷档 | LL = 档位值 |
| `10 00` | 关闭灯效 | |
| `10 FF` | 打开灯效 | |
| `10 FF R G B V P` | 直接更新灯色 | R/G/B 0–255，V 亮度，P 周期 |
| `20 mode tgt cold wlo_hi wlo_lo temp cl wl_hi 00` | 设置运行模式（9 字节，B7/B8/B9X） | 见 §3 |
| `20 04 c1..c9` | 自定义曲线模式（11 字节，B9X） | 9 段温度曲线值 |
| `22 n` | 读取运行模式参数 | n=4 时设备回 `22 04 v1..v9` |
| `33 a b c d e f` | 设置最大冷/风档组合 | 6 字节 |
| `34 v1..vn` | 一次性写入全部曲线参数 | |
| `40 00` | 请求温度历史 | 设备回 `41`/`42` |
| `51 ...` | 设置灯效（20 字节） | 见 §5 |
| `52 01 c v` | 实验性智能模式开关 | c=档位，v=目标温度/100 |
| `57 m` | 快捷切换运行模式 | m = RunMode |
| `61 mode once hi lo` | 定时关机 | mode, 0/1=仅一次/每次, 秒数(大端) |
| `A5 A0 00 00` | 握手/进入自定义模式 | |
| `FF 0A` | 恢复出厂（resetFlash） | |

## 3. 运行模式与 setRunMode 参数

RunMode 枚举：

| 值 | 含义 |
| --- | --- |
| 0 | 智能温控 SMART |
| 1 | 手动 MANUAL |
| 2 | 超频 OVERCLOCK |
| 3 | 实验性智能 EXPERIMENTAL_SMART |
| 4 | 自定义曲线 CUSTOM（仅 B9X 支持曲线帧） |

`setRunMode(mode, targetTemperature, windLevel, coldLevel, windLevelOverclock, coldLevelOverclock, modeCustom, customLevels[])`

B9X 常规帧（9 字节）：

```
[0] 0x20
[1] mode
[2] coldLevelOverclock
[3] windLevelOverclock / 100
[4] windLevelOverclock % 100
[5] targetTemperature
[6] coldLevel
[7] windLevel / 100
[8] 0
```

B9X 自定义曲线帧（mode==4，11 字节）：`20 04 v1 v2 v3 v4 v5 v6 v7 v8 v9`

## 4. 档位值编码（电压）

档位以「电压×19」编码，`voltage = ((level - 19) * 0.5 / 19) + 1.5`：

| level | 电压 |
| --- | --- |
| 0 | --（关闭） |
| 19 | 1.5V |
| 38 | 2.0V |
| 57 | 2.5V |
| 77 | 3.0V |
| 95 | 3.5V |
| 115 | 4.0V |
| 134 | 4.5V |
| 145 / 155 / 175 | 固定功率 / 固定功率-强 / 固定功率-极强（超频回报值） |

智能模式三档由组合值判定：

| 档 | targetTemp | wind | cold | windOC | coldOC |
| --- | --- | --- | --- | --- | --- |
| 0 | 18 | 77 | 115 | 77 | 134 |
| 1 | 16 | 95 | 115 | 95 | 153 |
| 2 | 16 | 115 | 115 | 134 | 173 |

超频可用等级（状态帧 [2] 低 4 位）：0=不可用，1=10W，2=30W。

## 5. 灯效

LedType：

| 值 | 名称 | 值 | 名称 |
| --- | --- | --- | --- |
| 0 | OFF | 12 | RAINBOW_SMART |
| 1 | STARTING | 16 | ROTATION_MULTIPLE_COLOR |
| 2 | SHUTDOWN | 17 | THROB |
| 3 | RAINBOW | 19 | RHYTHM |
| 4 | CORONA | 20 | CYBERPUNK |
| 5 | BREATH | 21 | COLLISION |
| 6 | GRADUAL | 22 | THEME |
| 7 | BLINKING | | |
| 8/9 | TWO_STARTING / TWO_SHUTDOWN | | |
| 10 | BLACK | | |
| 11 | LONG | | |

`setLedColor(ledType, period, colors[], light, colorful)` 发送 20 字节：

```
[0] 0x51          [1] ledType        [2] period(周期)
[3] 颜色总数      [4] 包序号(1/2)     [5..] RGB 三元组
[17] 亮度         [18] colorful(1/2 仅 type=19)   [19] 0
最后追加 2 字节：51 ledType（触发应用）
```

> 超过 4 个颜色分两包（每包 4 个颜色），第二包 [4]=2。

## 6. 状态回报（Notify FFE4，首字节 0x13）

B9(B8/B9X) 布局，长度 20：

| 字节 | 字段 |
| --- | --- |
| [0] | 0x13 |
| [1] | ipType（0 标准 / 1 OP_RED / 2 OP_BH3） |
| [2] | 高 4 位 = runMode；低 4 位 = 超频可用等级 |
| [3] | coldLevel |
| [4..5] | windLevel = v[4]*100 + v[5] |
| [6] | targetTemperature |
| [7] | temperature（有符号，摄氏度整数） |
| [8] | temperatureDecimal（小数位） |
| [9] | hotSurfaceTemperature（有符号） |
| [10] | coldRunLevel |
| [11] | windRunLevel |
| [12..13] | 风扇转速 speed = v[12]*100 + v[13] |
| [14] | lightState：255=开，0=关 |
| [15] | ledType |
| [16] | quickSwitchRunMode |
| [17] | 位域：bit0 冷保护触发，bit1 正在最大档，bit2 定时关机模式，bit3 定时关机运行中，bit4 高温保护开关，bit5 低温保护开关，bit6 倒计时按分钟，bit7 冻结模式 |
| [18..19] | timeCountdown = (v[18]<<8) + v[19]（秒） |

其他响应帧：

| 帧 | 含义 |
| --- | --- |
| `22 04 v1..v9` | 自定义曲线 9 个值 |
| `24 b6 b5 b4 b3 b2 b1` | MAC 地址（反序） |
| `40 ...` / `41 ...` / `42` | 温度历史（分片 ack / 数据 / 完成） |
| `51 ...` | 灯效回报（同 §5 结构） |
| `52 v1 v2` | 实验智能模式回报，v1=0xE6 && v2=0x39 表示开启 |
| `61 mode run hi lo` | 定时关机回报 |
| 其他（长度>5） | 固件版本字符串（取前 5 字符） |

## 7. 功能清单（对端 UI 具备的全部能力）

1. 扫描 / 连接 / 断开 / 重连（按广播名过滤）
2. 实时状态：温度、目标温度、热面温度、冷/风档、转速、运行模式、超频等级
3. 制冷档位滑杆、风速档位滑杆
4. 运行模式：智能温控（3 档）、手动、超频（10W/30W）、自定义 9 段曲线、实验性智能
5. 快捷切换运行模式（device 端按键轮换）
6. 灯效：类型、颜色（单色/最多 8 色分段）、亮度、周期、多彩色、开关
7. 定时关机：模式（仅一次/每次）、时长
8. 冻结模式（Freeze Mode）开关与提示
9. 温度保护：低温保护 / 高温保护开关
10. 最大冷/风档限制设置
11. 温度历史曲线（设备记录、本地上报）
12. MAC 地址读取、固件版本读取
13. 固件 OTA 升级（Telink OTA 协议，官方 `sdk/bluetooth/ota`）
14. 设备信息/关于页

## 8. 尚未确认项

- OTA 详细帧格式（Telink OTA 通用协议，需抓包或读 `TelinkOtaFactory`）
- 温度历史的采样周期与存储格式
- `33`（最大冷档）各字节语义
- 自定义曲线 9 个值的物理含义（温度点 vs 电压点）
