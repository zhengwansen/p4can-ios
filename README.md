# P4-CAN Console · iOS App

给 `P4-CAN Universal v3.29.3` 固件配套的原生 iOS 控制台（SwiftUI，iOS 16+）。手机连上设备热点后直连 `http://192.168.4.1`，实时看车、改功能、升级固件 —— **不经过任何云端服务**。

调用的是固件 `web_api.h` 里已有的接口，没有为它改一行固件。

---

## 为什么是 Wi-Fi，而不是蓝牙

你说「蓝牙或者 WiFi」，但**当前固件没有蓝牙控制通道**，iPhone 连不上它：

| 证据 | 位置 |
| --- | --- |
| 设备只做 BLE **主机**：扫描广播并连接 S3XY 按钮 | `s3xy_ble.h:1591` `BLEDevice::getScan()`、`:1596` `setAdvertisedDeviceCallbacks` |
| 创建客户端并主动 connect | `s3xy_ble.h:2127` `BLEDevice::createClient()`、`:2178` `client->connect(...)` |
| 全仓库**没有** GATT 服务端 | 搜索 `BLEServer` / `addService` / `startAdvertising` 零命中 |

也就是说，设备是「去找按钮」的一方，不是「等手机来连」的一方。要让 iPhone 通过 BLE 连它，必须在固件里新增 GATT 服务（见文末「想加蓝牙」）。

因此本 App 走 **Wi-Fi**：`http://192.168.4.1` 的 HTTP JSON 接口，功能与设备自带网页版等价，但操作更快、更省电、可常驻后台轮询。

---

## 运行要求

| 项目 | 要求 |
| --- | --- |
| 系统 | iOS 16.0 或更高 |
| 开发 | Xcode 14 或更高（推荐 15/16） |
| 设备 | 任意 iPhone / iPad（支持真机与模拟器） |
| 账号 | 免费 Apple ID 即可自签名安装（7 天需重签）；上架需付费开发者账号 |
| 网络 | **不需要外网**，App 只访问设备局域网地址 |

---

## 在 Xcode 里跑起来

> **没有 Mac？** 看 [INSTALL-NO-MAC.md](INSTALL-NO-MAC.md)：用 GitHub Actions 的免费 macOS 机器编译出 ipa，再在 Windows 上用 Sideloadly 签名安装，全程不花钱。

1. 解压 `P4CANConsole.zip`，双击 `P4CANConsole.xcodeproj`。
2. 选中左侧工程 → TARGET `P4CANConsole` → **Signing & Capabilities** → Team 选你的 Apple ID。
3. 把 **Bundle Identifier** 改成全网唯一，例如 `com.你的名字.p4can`。
4. 顶部选择你的 iPhone（首次需在手机上「信任此电脑」）→ **⌘R** 运行。
5. 手机首次运行会弹「**允许访问本地网络**」→ 必须点允许（否则请求全部失败）。

> 没有 Apple ID 配置时也能在**模拟器**里跑，但模拟器连不上真机热点，只能用来看界面。

---

## 首次连接设备

1. 手机打开「设置 → 无线局域网」，连上 `P4-CAN-XXXX`（默认密码 `12345678`）。
   - iOS 会提示「**无互联网连接**」，选择「保持连接」。
2. 打开 App → 「设置」页 → 确认地址 `http://192.168.4.1` → 点 **保存并测试**。
3. 显示「连接成功」后，点 **接口自检**：5 个端点逐个探测，失败项会给出原因。

地址可改（设备改过热点 IP 或走局域网路由时）；点「恢复默认」回到 `192.168.4.1`。

---

## 四个页面

### 总览
- 车型 / 拓扑 / 三路总线映射（A、B、附加）
- AP 激活、NOA、NAG 扭矩、手扶状态、档位、DAS 状态字、AP 显示
- R79 扭矩注入：状态、触发原因、AP 门控、成功/失败、距上次发送
- 三路 CAN 的在线状态、RX、静默时长
- 运行时间、空闲 / 最低内存、固件版本
- 重启设备（二次确认）；下拉刷新

`home-fast` 快照 **1.2 秒**轮询，其余 6 秒。

### 控制
| 分组 | 能力 |
| --- | --- |
| 核心 | NAG 开关、注入方法（力矩 / TSL9）、模式模板（A/B/C/H）、自动转向灯 + 延时滑块、TLSSC、LAB |
| 驾驶辅助 | DMS 干预、ISA 抑制、ULC 自动变道、ULC Off 模式、盲区模式、确认时序、免确认变道 |
| 区域 | 国家覆盖（STOCK/US/KOREA/NEW ZEALAND）、地图区域（STOCK/US 0/KR 7） |
| 调试 | 展开查看设备返回的 ULC / 国家覆盖原始 JSON |

开关即时写 NVS；固件返回 `supported=false` 的项目自动禁用。

### 总线
三路 TWAI 物理层：接收帧数、最近流量、TX 成功/拒绝、总线关闭次数、**TEC/REC**、总线错误、仲裁丢失、RX 轮询、丢帧/溢出、驱动发送失败、恢复成功/失败、初始化与最近 RX 结果、快照年龄；另有原生接收溢出统计。可「清零统计」「强制重初始化 CAN」（各一次确认）。

### 设置
- 连接地址 + **保存并测试** + **接口自检**（5 个端点）
- 设备信息、**复制诊断信息**（一键复制纯文本报告）
- Wi-Fi 热点改名/改密码（会重建 AP）；默认密码时给出安全警告；可展开 `/api/wifi/status` 原始返回
- **OTA 升级**：从「文件」App 选 `.bin` → 上传 → 进度条 + 设备回报的接收字节/阶段
- 维护：重置固件设置（保留车型/蓝牙）、恢复出厂、重启

---

## 用到的固件接口

| 用途 | 方法 | 路径 | 参数 |
| --- | --- | --- | --- |
| 实时快照 | GET | `/api/snapshot` | `groups=home-fast` |
| 设置快照 | GET | `/api/snapshot` | `groups=settings-lite` |
| 车型配置 | GET | `/api/profile/status` | — |
| 系统统计 | GET | `/api/system/stats` | — |
| NAG 配置 | GET | `/api/nag/config` | — |
| NAG 开关/方法 | POST | `/api/nag/update` | `enabled`、`method=0\|1` |
| NAG 模式模板 | POST | `/api/nag/mode` | `m=0\|1\|3\|7`（A/B/C/H） |
| 自动转向灯 | POST | `/api/blinkA/enable` / `disable` | — |
| 转向灯延时 | POST | `/api/blinkA/delay` | `ms`（0–30000） |
| TLSSC | POST | `/api/summon/tlssc-enable` / `disable` | — |
| 实验室 | GET/POST | `/api/features/status`、`/api/features/lab` | `enabled` |
| DMS | GET/POST | `/api/driver-monitoring/config` | **仅** `enabled`（固件用 `args()==1` 严格校验） |
| ISA | GET/POST | `/api/isa-suppression/config` | **仅** `enabled` |
| ULC | GET/POST | `/api/ulc/stats`、`/api/ulc/update` | `alcOff`、`ulcOff=stock\|0\|1`、`blind=stock\|0\|1\|2`、`confirm`、`timing` |
| 国家/地图 | GET/POST | `/api/country/stats`、`/api/country/update` | `countryMode=0..3`、`mapMode=0..2` |
| Wi-Fi | GET/POST | `/api/wifi/status`、`/api/wifi/apply` | `ssid`、`password`（留空沿用） |
| OTA | GET/POST | `/api/ota/status`、`/update` | multipart 上传 |
| 维护 | POST | `/api/system/reboot`、`reset-settings`、`factory-reset`、`reset-stats`、`reinit-can` | — |

POST 统一 `application/x-www-form-urlencoded`。

---

## 工程结构

```
ios/P4CANConsole/
├── P4CANConsole.xcodeproj/project.pbxproj   由脚本生成，可重复重建
├── project.yml                              XcodeGen 备用规格
└── P4CANConsole/
    ├── P4CANConsoleApp.swift                @main 入口
    ├── Info.plist                           ATS 明文豁免 + 本地网络权限说明
    ├── Assets.xcassets/                     AppIcon（1024，脚本生成）+ AccentColor
    ├── Core/
    │   ├── API.swift                        Payload(宽松 JSON) / APIClient / 错误翻译 / 多部分上传
    │   ├── Models.swift                     视图状态 + 与固件一致的选项常量（MODE_H=7 等）
    │   ├── DeviceModel.swift                轮询、动作、OTA 状态机（@MainActor）
    │   └── Formatters.swift                 字节/时长/毫秒/总线状态格式化
    └── Views/
        ├── Theme.swift                      设计令牌 + Card/InfoRow/StatCell/Tag/Banner
        ├── RootView.swift                   TabView + 全局 toast/alert
        ├── OverviewView.swift
        ├── ControlView.swift
        ├── CANView.swift
        └── SystemView.swift
```

辅助脚本（在仓库根 `tools/`）：

```bash
python tools/gen-xcodeproj.py     # 重新生成 project.pbxproj（加文件后跑一次）
python tools/make-icon.py         # 重新生成 1024 图标
python tools/verify-ios.py        # 离线校验（171 项）
```

---

## 校验情况

**已做**（`python tools/verify-ios.py`，171 项全过）：

- `project.pbxproj` 结构：括号平衡、24 位 UUID 引用闭合、11 个 Swift 全部进入 Sources 阶段、Info.plist 未被误当资源拷贝、Debug/Release 与关键构建设置齐全
- `Info.plist`：ATS 明文豁免、`NSLocalNetworkUsageDescription`、`UILaunchScreen`、包类型、竖屏声明
- 资源：xcassets JSON 合法、AppIcon 1024×1024 且无 alpha
- **字段契约**：Swift 里每一个 JSON 键与表单键都回查固件源码；总线键（`can%u%s` 动态拼装）从 `p4CanWriteStatus()` 提取真实后缀集合后逐个比对 —— 这一步抓出并修正了 `apSsid`（固件实际是 `ssid`）
- Swift 静态结构：每个文件括号平衡、类型无重复、无 `#Preview`（兼容 Xcode 14）、`import Combine` 存在

**未做**：

- **没有编译过**。这台构建机是 Windows + 无 Xcode/Swift 工具链，无法执行 `xcodebuild`。请在 Mac 上首次打开时留意编译错误。
- 没有真机运行、没有连真车；界面渲染、轮询节奏、iOS 本地网络弹窗均未实测。

---

## 想加蓝牙（需要改固件）

如果希望手机走到车边就通过 BLE 连上（不必切 Wi-Fi），需要两步：

**固件侧**（必须，当前完全没有）：

1. 在 `s3xy_ble.h` 同进程内增加 GATT **服务端**：自定义 Service UUID，一个 `write` 特征（收 JSON 指令）+ 一个 `notify` 特征（推状态）
2. 复用现有 `p4_ble_security.h` 的配对/加密能力，或加 6 位配对码，避免任何人可连
3. 处理角色共存：现有 BLE 主机扫描 + 新增外设 + SoftAP 三者共存，需要实测吞吐与内存（当前 `Web` 任务栈 8192、空闲堆约 77 KB 级，需评估）
4. 指令层建议直接复用现有 JSON 语义，App 侧只换传输层

**App 侧**（改动很小）：把 `APIClient` 抽成 `Transport` 协议，新增 `CoreBluetoothTransport`，`DeviceModel` 不变。

需要的话我可以把这两端都实现出来 —— 但请知悉：固件那边我无法在真实 C6/P4 上验证共存表现。

---

## 常见问题

| 现象 | 原因 / 处理 |
| --- | --- |
| 一直「未连接设备」 | 手机没连 `P4-CAN-XXXX`；或连了但 iOS 走了蜂窝网络 → 设置里关掉「无线局域网助理」再试 |
| 提示 HTTP 被拦截 | Info.plist 的 ATS 豁免被改掉了，检查 `NSAllowsArbitraryLoads` |
| 弹窗没点「允许」 | 设置 → 隐私与安全性 → 本地网络 → 打开 P4-CAN |
| OTA 选不到文件 | 先把 `.bin` 存到「文件」App / iCloud 云盘，再从 `fileImporter` 里选 |
| OTA 上传后失败 | 固件要求先停下 CAN 才能升级；若报 `CAN stop not confirmed`，重启设备后重试 |
| 改完热点手机掉线 | 正常：SoftAP 重建，手动连新 SSID 后回 App |

> 安全提醒：固件 HTTP 接口**没有鉴权**，热点密码是唯一门槛。请务必改掉默认密码 `12345678`（App「设置 → Wi-Fi 热点」里可直接改）。
