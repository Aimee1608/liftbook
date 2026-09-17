# 迭代与发版指南

首次上架那一堆配置**都是一次性的**。下面第三节起才是每次迭代真正要做的事。

---

## 一、一次性配置（首次上架用，之后不用再碰）

| 项目 | 值 / 位置 |
|---|---|
| Bundle ID | `com.aimee.liftbook` |
| App Store 名称 | 力训笔记 |
| 隐私政策 URL | https://aimee1608.github.io/liftbook/privacy-policy |
| 分类 | 健康健美 |
| 年龄分级 | 4+（全选"无"） |
| App 隐私 | 不收集数据 |
| 权限 | 仅本地通知（休息计时器后台提醒），首次启用计时器时申请 |
| 上架文案 | [`app-store-listing.md`](app-store-listing.md) |

隐私政策靠 GitHub Pages 托管：仓库 Settings → Pages → Source 选 `main` 分支 `/docs` 目录。

---

## 二、日常开发闭环

```bash
xcodegen generate      # 改过 project.yml 就必须重跑
xcodebuild -project Liftbook.xcodeproj -scheme Liftbook \
  -destination 'id=<模拟器UDID>' test
```

跑 `xcrun simctl list devices` 拿模拟器 UDID。

核心逻辑（渐进引擎 / 衰减 / 调度 / 会话与落盘）不依赖 SwiftUI，可以不开 Xcode 直接编译跑：

```bash
swiftc -O Sources/Models/*.swift scripts/main.swift -o /tmp/liftbook_smoke && /tmp/liftbook_smoke
```

含顶层代码的文件必须叫 `main.swift` 并用 `swiftc` 编译，别用 `swift a.swift b.swift` 解释器模式。

UI 测试在 `UITests/`：`FlowTests` 走一遍完整训练闭环，`SecondaryFlowTests` 覆盖换一天、
临时加动作、退出再继续、计划编辑、自定义动作、单位切换、历史编辑。两条都用 `-resetData`
启动参数清空数据从头走（仅 DEBUG 构建生效）。截图靠 `XCTAttachment` 附在测试结果里：

```bash
xcodebuild ... -resultBundlePath /tmp/lb.xcresult test
xcrun xcresulttool export attachments --path /tmp/lb.xcresult --output-path /tmp/lbshots
```

---

## 三、发版流程（每次迭代就这 3 步）

### 1. 升版本号

改 `project.yml`：

```yaml
MARKETING_VERSION: "1.0.1"      # 用户看到的版本号
CURRENT_PROJECT_VERSION: "2"    # build 号，只增不减，不能跟已上传过的重复
```

同步到 Mac 后 `xcodegen generate`。

### 2. 打包 + 上传

```bash
xcodebuild -project Liftbook.xcodeproj -scheme Liftbook \
  -destination 'generic/platform=iOS' -allowProvisioningUpdates \
  -archivePath /tmp/Liftbook.xcarchive archive
```

看到 `** ARCHIVE SUCCEEDED **` 即成功。然后搬到 Organizer 能看到的位置：

```bash
mkdir -p ~/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d) && \
cp -R /tmp/Liftbook.xcarchive ~/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)/
```

Xcode → `Window` → `Organizer` → 选中这个 archive → **Distribute App** → App Store Connect → Upload。

> Organizer 只扫 `~/Library/Developer/Xcode/Archives`，放 `/tmp` 里它看不见。
>
> **archive 必须在 Mac 图形终端里跑**：SSH 会话拿不到登录钥匙串里的私钥，
> codesign 会报 `errSecInternalComponent`，在自己终端 `unlock-keychain` 也传递不过去。

### 3. App Store Connect

1. 我的 App → 力训笔记 → 左侧 **「+ 版本或平台」** → 填新版本号
2. **截图**：UI 有明显变化时必须换，否则违反 Guideline 2.3.3
3. 填「**本次更新内容**」
4. 选构建版本（上传后要等 10~30 分钟处理完才出现）
5. **添加以供审核** → **提交以供审核**

---

## 四、上架截图

ASC 的截图槽位会随 app 支持的设备变，**以页面上实际要求的为准**。通常是这三套：

| 显示屏 | 模拟器 | 像素 |
|---|---|---|
| iPhone 6.9" | iPhone 17 Pro Max | 1320 × 2868 |
| iPhone 6.5" | iPhone 11 Pro Max（Xcode 里默认没有，要临时建） | 1242 × 2688 |
| iPad 13" | iPad Pro 13-inch (M5) | 2064 × 2752 |

6.5" 的模拟器要现建现删：

```bash
SIM=$(xcrun simctl create 'iPhone65Shot' \
  com.apple.CoreSimulator.SimDeviceType.iPhone-11-Pro-Max \
  com.apple.CoreSimulator.SimRuntime.iOS-26-5)
# 跑完截图后
xcrun simctl delete $SIM
```

截图脚本沿用 `UITests/` 的 `XCTAttachment` 套路，导出方式见第二节。空数据的首页说明不了
产品在干什么，出图前先在模拟器里真实练一两次，或者补录几条历史。

---

## 四·二、App 预览录屏

App 预览是**可选**的（截图才是必需），但做了转化率更好。硬要求：**15~30 秒**、
只能是 app 内画面、分辨率跟截图一样分档。

脚本在 `scripts/shots/PreviewVideoTests.swift`（同样不进 target，用时复制到 `UITests/`），
录制和裁剪分两步：

```bash
SIM=<模拟器UDID>
cp scripts/shots/PreviewVideoTests.swift UITests/ && xcodegen generate
# 先预编译,否则 xcodebuild 的准备时间会被录进去
xcodebuild -project Liftbook.xcodeproj -scheme Liftbook -destination "id=$SIM" \
  -derivedDataPath /tmp/liftbookbuild build-for-testing
xcrun simctl io $SIM recordVideo --codec h264 --force /tmp/preview.mov & echo $! > /tmp/recpid
sleep 1.5
xcodebuild -project Liftbook.xcodeproj -scheme Liftbook -destination "id=$SIM" \
  -derivedDataPath /tmp/liftbookbuild \
  -only-testing:LiftbookUITests/PreviewVideoTests test-without-building
kill -INT $(cat /tmp/recpid)
rm UITests/PreviewVideoTests.swift && xcodegen generate

# 看时长和分辨率
swiftc -O scripts/shots/trim_video.swift -o /tmp/trimvid
/tmp/trimvid /tmp/preview.mov
```

录出来一般 45~65 秒，超了 30 秒上限，要剪掉中间的空转。`cut_video` 按若干
`<起点> <时长>` 把片段拼成一条（passthrough，不重编码、不改分辨率），
第三个参数给了目录就顺便按 1.5 秒抽帧，用来核对剪的位置：

```bash
swiftc -O scripts/shots/cut_video.swift -o /tmp/cutvid
/tmp/cutvid /tmp/preview.mov /tmp/out.mov /tmp/frames -- 7.4 3.5 12.2 7.0 20.5 8.5 32.8 7.5 43.0 3.0
```

**片段起点每台设备都不一样**，因为开头那段安装 + 启动的耗时不同（6.9" 约 7s，
6.5" 约 21s，iPad 约 18s）。做法是先整段抽帧看一遍，找到首页出现的时刻当锚点，
再按 1.0.0 这组相对偏移（+0.0 / +4.8 / +13.1 / +25.4 / +35.6，时长 3.5 / 7.0 / 8.5 / 7.0 / 3.0）平移。

五段分别是：首页今日计划 → 执行页打卡与休息计时 → 次数面板改数字 → 结束训练与下次建议 → 历史日历。

三个坑：

- **XCUITest 的每步操作都有查找元素的开销**，实际录出来比脚本里 sleep 的总和长不少，
  所以是「录长了再裁」，不是掐着 30 秒写脚本。
- **录屏前必须确保不会弹系统通知权限框**，否则会盖住画面。`-demoData` 启动参数下
  `NotificationManager.requestIfNeeded()` 直接跳过申请（见 `RestTimer.swift`）。
- 6.5" 那台是**临时建的模拟器**，录完记得 `xcrun simctl delete`，否则下次 `simctl list`
  里会攒一堆同名设备。

---

## 五、审核要当心的

| Guideline | 现象 | 修法 |
|---|---|---|
| 2.3.7 | 副标题/关键词/宣传文本里出现"无广告""无内购""免费" | 这些算价格表述，会被拒。**只能写在描述里** |
| 2.3.3 | 截图跟实际界面对不上 | UI 改了就要换截图 |
| 5.1.1 | 健康类目被问医疗声明 | 免责声明首次启动强制阅读，设置页常驻；审核备注里写明"训练记录工具，不提供医疗建议" |
| — | 上传报 `No orientations were specified` | `project.yml` 里 `INFOPLIST_KEY_UISupportedInterfaceOrientations` 必须声明全部四个方向（iPad 多任务强制），已配好别删 |
| 2.1 | 要求补充信息 | 审核备注写清楚"完全离线、无需账号、无 HealthKit、无第三方 SDK" |

重新提交前若「重新提交至 App 审核」按钮是灰的，说明版本没有任何改动，
随便编辑一处（比如补审核备注）存一下就会亮。

## 六、排队卡住怎么办

新账号首个 App 在「正在等待审核」滞留一周是常态。按这个顺序查：

1. **「协议、税务和银行业务」有没有待处理项**。免费 App 也要签「免费应用程序协议」
2. **App 审核页和注册邮箱（含垃圾箱）**，Apple 的问询只发邮件
3. 前两条都正常就**申请加急审核**：https://developer.apple.com/contact/app-store/?topic=expedite

**不要 Remove from Review 重新提交**——会回到队尾重新排，只会更慢。
