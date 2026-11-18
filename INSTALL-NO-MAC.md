# 没有 Mac，怎么把 App 装到 iPhone

思路一句话：**借 GitHub 的免费 macOS 机器编译**出一个未签名的 `.ipa`，再在 Windows 上用你自己的 Apple ID 给它签名安装。

整个过程不花钱，唯一代价是免费签名 **7 天过期**（到期重装一次即可，不用重新编译）。

---

## 开始前准备

| 需要 | 说明 |
| --- | --- |
| GitHub 账号 | 免费注册即可 |
| Windows 电脑 | 就是你现在这台 |
| iTunes | 从 **apple.com 官网**下载安装（**不要**用 Microsoft Store 版本，缺少驱动） |
| Sideloadly | <https://sideloadly.io> 免费下载 |
| iPhone 数据线 | 能连电脑的线 |

---

## 第 1 步：建仓库并上传源码

1. 打开 <https://github.com/new>，仓库名填 `p4can-ios`。
2. 可见性选 **Public**（公开仓库的 macOS 编译**完全免费**；私有仓库会按 10 倍消耗额度，见文末）。
3. 创建后进入仓库页 → 点 **Add file → Upload files**。
4. 把 `P4CANConsole` 文件夹里的**内容**全选拖进浏览器：
   ```
   P4CANConsole/            ← 源码目录
   P4CANConsole.xcodeproj/  ← 工程文件
   ci/
   project.yml
   README.md
   INSTALL-NO-MAC.md
   ```
   ⚠️ 关键：拖的是**文件夹里面的东西**，要让 `P4CANConsole.xcodeproj` 出现在仓库**根目录**，而不是外面再套一层 `P4CANConsole/`。
5. 底部点 **Commit changes**。

---

## 第 2 步：添加编译工作流

GitHub 网页拖拽**不会**上传以点开头的隐藏目录，所以手动建：

1. 仓库页 → **Add file → Create new file**。
2. 文件名输入：
   ```
   .github/workflows/ios-build.yml
   ```
   （输入斜杠会自动创建目录）
3. 用记事本打开本地的 `ci/ios-build.yml`，`Ctrl+A` 全选、`Ctrl+C` 复制，粘贴到网页编辑器里。
4. 点 **Commit changes**。

---

## 第 3 步：跑一次编译

1. 仓库顶部点 **Actions** 标签 → 左侧选 **Build unsigned IPA**。
2. 右侧点 **Run workflow** → 绿色 **Run workflow** 按钮。
3. 等 **3–6 分钟**（先黄后绿）。
4. 点进这次运行记录，页面**底部**有 **Artifacts** → 下载 `P4CANConsole-unsigned-ipa`。
5. 解压这个 zip，里面就是 `P4CANConsole-unsigned.ipa`。

> 如果这一步是红的（失败）：在同一页底部下载 `xcodebuild-log`，把最后 50 行发我。**这份代码还没在任何 Mac 上编译过**，首次报错很可能需要我修一两处语法。

---

## 第 4 步：用 Sideloadly 签名安装

1. iPhone 用数据线连电脑 → 手机上点「**信任**」。
2. 打开 Sideloadly，把 `P4CANConsole-unsigned.ipa` 拖进窗口，**Device** 里选你的 iPhone。
3. **Apple ID** 填你自己的（免费账号就行）。
   - ⚠️ 开了双重认证的账号：先到 <https://appleid.apple.com> → 登录与安全 → **App 专用密码** → 生成一个，把生成的密码填进 Sideloadly 的密码框（不是你的登录密码）。
4. 如果提示 Bundle ID 被占用：勾选 **Change Bundle ID**（会自动加唯一后缀）。
5. 点 **Start**，等进度条走完（约 1–3 分钟）。
6. **手机上还要做两件事**，否则点开闪退：
   - 设置 → 通用 → **VPN与设备管理** → 点你的 Apple ID → **信任**
   - iOS 16 及以上：设置 → 隐私与安全性 → **开发者模式** → 打开 → 重启手机

---

## 第 5 步：连接设备

1. iPhone 设置 → 无线局域网 → 连 `P4-CAN-XXXX`（默认密码 `12345678`）。提示「无互联网连接」选**保持连接**。
2. 打开 **P4-CAN** → 弹窗 **允许访问本地网络** → 必须点允许。
3. 进「设置」页 → 确认地址 `http://192.168.4.1` → **保存并测试** → 显示连接成功。
4. 点 **接口自检**，5 个端点应全绿。

---

## 7 天过期怎么办

免费 Apple ID 签的 App，**7 天后打开会提示「无法验证 App」**。

- 解决：手机连电脑 → 打开 Sideloadly → 重新拖入同一个 ipa → Start。**不需要重新编译**，1 分钟搞定。
- 想彻底免掉：Apple 开发者账号 **99 美元/年**，签名 1 年有效，还能用 TestFlight 直接发给别人装（不用连电脑）。
- 如果你只是自己上车用，7 天重签一次其实够用；也可以把 ipa 存好，到期重装。

---

## 常见问题

| 现象 | 原因 / 处理 |
| --- | --- |
| Actions 页面没有这个工作流 | 文件路径不对，必须是仓库根目录 `.github/workflows/ios-build.yml`（注意开头的点） |
| 编译失败，报 `requires a development team` | 粘贴的 yml 不完整，`CODE_SIGNING_ALLOWED=NO` 那几行必须在 |
| 编译失败，报 Swift 语法错误 | 把 `xcodebuild-log` 最后 50 行发我，我来改 |
| Sideloadly 报 `Could not find Apple Mobile Device Support` | 装了 Microsoft Store 版 iTunes，卸载后装 apple.com 官网版 |
| Sideloadly 报 `ApplicationVerificationFailed` | App 专用密码填错，或账号被锁；重新生成专用密码 |
| 图标在但点开闪退 | 没做「VPN与设备管理 → 信任」，或没开开发者模式 |
| App 一直「未连接设备」 | 手机没连设备热点，或「本地网络」权限没给（设置 → 隐私与安全性 → 本地网络） |
| 想用私有仓库 | 可以，但 macOS runner 按 **10 倍**计分钟：一次编译约 4 分钟 ≈ 40 分钟额度，免费额度 2000 分钟/月，够用约 50 次 |

---

## 安全提醒

- **公开仓库 = 源码公开**。这个 App 的代码本身不含密钥，但如果仓库里还要放固件源码，请改用私有仓库。
- 设备 HTTP 接口**没有鉴权**，热点密码是唯一门槛。装好 App 后第一件事：进「设置 → Wi-Fi 热点」把默认密码 `12345678` 改掉。

---

## 如果以后能借到 Mac

那就不用折腾了：解压 → 双击 `P4CANConsole.xcodeproj` → 选 Team → ⌘R，两分钟装完，且不用 7 天重签（免费账号仍是 7 天，付费账号 1 年）。
