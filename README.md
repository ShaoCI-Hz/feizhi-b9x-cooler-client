# 飞智 B9X 散热器控制客户端

面向飞智（Flydigi）B9X 磁吸式手机散热器的开源控制客户端，支持 Android 与 Windows。
通信协议通过对官方 Android 客户端安装包进行静态分析还原，控制界面基于 Flutter 重新实现。

## 免责声明

- 本项目为个人开发的开源项目，与飞智科技及其关联公司无任何关系，不是官方产品。
- “飞智”“Flydigi”“B9X”等名称与商标归其权利人所有。
- 项目中的协议信息来自对官方公开发布的客户端安装包所做的静态分析，目的仅为实现互操作性，未包含官方代码或资源。
- 使用本软件对设备进行控制可能产生不可预期的结果，包括但不限于设备异常、配置丢失。使用者需自行承担相关风险。

## 功能

- 设备扫描与连接：按广播名过滤，支持连接状态回调与断线重连提示。
- 实时状态：制冷面温度、目标温度、热面温度、制冷档位、风量档位、风扇转速、运行模式、超频能力等级。
- 运行模式
  - 智能温控：安静、均衡、强劲三档预设。
  - 手动：制冷与风量独立调节。
  - 超频：10W 与 30W 两档能力识别。
  - 自定义曲线：九段温度区间功率分配。
- 灯效：19 种灯效类型、最多八色配色、亮度与流转速度调节、多彩律动开关。
- 定时关机：仅一次或每次生效，预设时长选择。
- 设备保护：冻结模式、低温保护、高温保护。
- 设备信息：MAC 地址、固件版本、超频能力。
- 温度历史：读取设备端记录并绘制曲线。
- 演示模式：无硬件时预览完整界面。

## 支持设备

主要目标设备为飞智 B9X。协议层同时包含 B8X、B7X、B7、B6X、B6、B5X、B5Pro、B5、B3 的广播名过滤与部分指令差异处理，但这些型号未经实机验证。

## 技术架构

| 层次 | 实现 |
| --- | --- |
| 界面 | Flutter 3.47，自定义 Liquid Glass 组件、弹簧动画、自定义绘制 |
| 协议编解码 | 纯 Dart 位运算，无平台依赖，附带单元测试 |
| 状态管理 | ChangeNotifier + 串行命令队列（同类命令合并、最小发送间隔） |
| Android 传输 | Kotlin `android.bluetooth`，BluetoothGatt 串行写队列与失败重发 |
| Windows 传输 | C++/WinRT `Windows.Devices.Bluetooth`，通过平台通道与 Flutter 通信 |

通信参数：

- 服务 UUID：`0000FFE0-0000-1000-8000-00805F9B34FB`
- 写入特征：`0000FFE1-0000-1000-8000-00805F9B34FB`（Write Without Response）
- 通知特征：`0000FFE4-0000-1000-8000-00805F9B34FB`

## 目录结构

```
app/                Flutter 工程
  lib/core/         协议编解码、状态模型、BLE 通道、业务控制器
  lib/ui/           主题、玻璃组件、页面
  android/          Kotlin 蓝牙实现与权限声明
  windows/          C++/WinRT 蓝牙实现
dist/               预编译安装包
docs/               协议文档
```

## 构建

### 环境要求

- Flutter 3.47 或更高版本
- Android SDK 36 与 NDK 28.2（Android）
- Visual Studio 2022 的“使用 C++ 的桌面开发”工作负载（Windows）

### Android

```bash
cd app
flutter pub get
flutter build apk --release --no-tree-shake-icons
```

`--no-tree-shake-icons` 用于保留运行时按索引选择的图标字形。

### Windows

```bash
cd app
flutter pub get
flutter build windows --release
```

### 测试

```bash
cd app
flutter test
flutter analyze
```

## 协议文档

指令帧、状态帧位域、档位编码、灯效结构与枚举见 [docs/B9X-PROTOCOL.md](docs/B9X-PROTOCOL.md)。

## 已知限制

- 固件 OTA 升级尚未实现。
- 状态帧由设备固件主动推送，界面刷新频率取决于推送间隔。
- 自定义曲线的九段数值未与温度点建立映射，当前仅原样下发。
- Windows 端依赖系统蓝牙栈，需在具备 BLE 适配器的 Windows 10 及以上版本运行。
- 预编译包使用调试签名，安装前需允许安装未知来源应用。

## 许可证

本项目采用 MIT 许可证，详见 [LICENSE](LICENSE)。
