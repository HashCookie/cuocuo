# 把「错错」装到自己的 iPhone 上

这份说明是给 AI 助手看的。朋友把它整段交给自己电脑上的 AI，让 AI 克隆仓库、改签名、编译并安装到他插着的那台 iPhone。

人只要准备：一台 Mac、装好 Xcode、一根数据线、自己的 Apple ID。不需要付费开发者账号。装上去的 App 大约 7 天后会打不开，再用同样的步骤装一次即可。

## 交给 AI 的任务

你是在朋友的 Mac 上操作。目标是把仓库 `https://github.com/HashCookie/cuocuo.git` 的 iOS App「错错」编译并安装到他已经用数据线连上的 iPhone。

不要把签名改动提交或推送回 GitHub。那是原作者的仓库。

### 1. 确认环境

- 系统是 macOS，并且安装了完整的 Xcode，不是只有 Command Line Tools。`xcode-select -p` 应指向 `Xcode.app/Contents/Developer`。如果不是，让用户安装 Xcode，或执行 `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`。
- iPhone 已解锁，并在手机上点了「信任这台电脑」。
- 用 `xcrun devicectl list devices` 或 `xcrun xctrace list devices` 找到那台物理 iPhone，记下 UDID 和系统版本。

这个工程的部署目标是 iOS 27.0。手机系统低于 27 时不要假装能装上。告诉用户需要 iOS 27，或先停下来问他要不要改部署目标。不要为了迁就旧系统大改代码。

### 2. 克隆

```bash
git clone https://github.com/HashCookie/cuocuo.git
cd cuocuo
```

如果克隆失败并提示没有权限，仓库还是私有的。让用户请仓库主人把他加为协作者，或把仓库改为公开。不要换一个来源。

### 3. 换成朋友自己的签名

工程里现在写死的是原作者的个人团队，朋友的电脑上没有这个团队：

- `DEVELOPMENT_TEAM = PL22H57D77`
- App 的 `PRODUCT_BUNDLE_IDENTIFIER = dev.fanyu.cuocuo`

这两项必须改，否则真机编译会失败。

1. 让用户打开 Xcode → Settings → Accounts，登录他自己的 Apple ID。免费的 Personal Team 就够用。不要选公司团队，除非这台电脑上只有那个团队而且用户明确同意。
2. 在本机已登录的团队里找出他的 Personal Team ID。可以看 Xcode 的账号页面，或看 `security find-identity -v -p codesigning` 里 `Apple Development: 他的邮箱 (团队ID)`。
3. 只改 App 目标 `cuocuo` 的 Debug 和 Release：
   - `DEVELOPMENT_TEAM` 改成他的团队 ID。
   - `PRODUCT_BUNDLE_IDENTIFIER` 改成他名下唯一的名字，例如 `dev.他的名字.cuocuo`。不要继续用 `dev.fanyu.cuocuo`，这个包名已经登记在原作者账号下，朋友注册会失败。
4. 测试目标 `cuocuoTests`、`cuocuoUITests` 不用安装到手机。它们的团队号和包名可以一起改掉，避免签名报错，但不要花时间跑测试，除非用户要求。

改完不要 `git commit`，不要 `git push`。

### 4. 编译并安装到那台 iPhone

用第 1 步拿到的物理设备 UDID，不要选模拟器。

```bash
xcodebuild \
  -project cuocuo.xcodeproj \
  -scheme cuocuo \
  -destination 'id=这里换成手机的UDID' \
  -allowProvisioningUpdates \
  build
```

Xcode 若弹出登录或授权签名，让用户在电脑上点允许。第一次安装时，手机上若出现开发者模式，按提示打开并重启，然后再编译一次。

安装可以用 Xcode 打开 `cuocuo.xcodeproj`，运行目标选他的 iPhone，点运行。命令行装到真机时，优先让 Xcode 直接 Run 到该设备。不要使用 Archive，不要上传 App Store 或 TestFlight。

### 5. 手机上信任开发者

安装后若打开 App 提示「不受信任的开发者」：

1. 打开「设置」。
2. 进入「通用」。
3. 点最下面的「VPN 与设备管理」。没有这一项时，找「设备管理」。
4. 点他的 Apple ID 邮箱。
5. 点「信任」。

然后再从桌面打开「错错」。

### 6. 做完后告诉用户

用几句话说明：App 已经装到哪一台手机、用的是哪个 Bundle ID、大约 7 天后会过期、过期后在同一目录再执行一次安装即可。不要把团队 ID 和包名推送到 GitHub。

## 人可以自己做的最短路径

不想把上面整段交给 AI 时，自己做这几步：

1. 用浏览器或 Git 克隆 `https://github.com/HashCookie/cuocuo.git`。
2. 用 Xcode 打开 `cuocuo.xcodeproj`。
3. 选中目标 `cuocuo`，打开 Signing & Capabilities。
4. Team 选自己的 Personal Team。Bundle Identifier 改成一个别人没用过的名字。
5. 插上 iPhone，顶部运行目标选这台手机，点运行。
6. 到「设置 → 通用 → VPN 与设备管理」里信任自己的开发者证书。
