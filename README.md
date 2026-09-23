# 力训笔记

基于渐进超负荷的力量训练计划与记录 iOS app。

计划里只写动作、组数和次数区间，**不写重量**。重量由双重渐进引擎按你每一组的真实表现演进：
固定重量下先把所有组推到区间上限，全部达标才加重，次数回落到下限重新爬升。
打开 app 直接告诉你今天该练哪一天、每个动作用多重、做多少次，并解释为什么。

纯本地、无账号、无广告、无内购、不联网、不收集任何数据。

## 在 Mac 上跑起来

```bash
brew install xcodegen   # 只需装一次
cd liftbook
xcodegen generate       # 生成 Liftbook.xcodeproj(不进 git,每次改 project.yml 后重跑)
open Liftbook.xcodeproj
```

## 核心逻辑

`Sources/Models` 下全是纯逻辑，不依赖 SwiftUI，可以脱离 Xcode 直接编译验证：

```bash
swiftc -O Sources/Models/*.swift scripts/main.swift -o /tmp/liftbook_smoke
/tmp/liftbook_smoke
```

冒烟测试覆盖渐进引擎、退阶与中断衰减、分化调度、会话持久化，以及内置动作库与模板的一致性。

### 三个独立的东西

**计划（WorkoutPlan）** 只管结构：哪一天练哪些动作、几组、次数区间。

**动作进度（ExerciseProgress）** 管状态：每个动作当前的工作重量、目标次数、连续失败次数。
按动作全局共享，换计划不会重置你的卧推重量。

**会话（WorkoutSession）** 是不可变的历史快照：进入训练时把计划和进度合成出今日目标，
每组打卡实时落盘。渐进按单个动作独立判定，卧推做完了就算，不受飞鸟没做完的影响。

### 渐进规则

- 所有正式组都达到目标次数与重量 → 下次每组 +1 次；已到区间上限 → 加重一档，次数回到下限
- 未达标 → 保持不变再试一次；连续两次 → 建议减重 10%
- 距上次训练 14 / 30 / 60 天以上 → 建议按 0.95 / 0.90 / 0.80 衰减，60 天以上提示重新探底
- 加重步长按器械类型：杠铃 / 哑铃 / 绳索 2.5 kg，固定器械大肌群 5 kg，壶铃 4 kg，自重不加重只加次数
- 所有建议都可一键拒绝

### 分化调度

按「该训练日涉及的肌群里最近被练过的那个」排序，最久没练的排前面推荐。
正常节奏下等价于固定循环队列；漏练、乱序、临时改练别的，它也给得出合理答案。

## 目录结构

```
Sources/
  Models/     Enums / Exercise / Plan / Progress / Session / Progression / Scheduler / WorkoutStore
  Views/      SwiftUI 界面
  App/        app 入口
  Resources/  Library/ 内置动作库与 5 套分化模板
              Assets.xcassets/Exercises/ 动作演示图
scripts/
  main.swift  核心逻辑冒烟测试
  artwork/    演示图流水线(下载、渲染、装配),见该目录下 README
```

## 动作演示图

72 个动作各配一组起始 / 结束示意图，改编自 [Everkinetic](https://commons.wikimedia.org/wiki/Category:Weight_training_diagrams)
的插画，依据 **CC BY-SA 3.0** 使用。我们把原图渲染成只保留透明通道的图片，在 app 内按主题着色。

**依据相同方式共享条款，`Sources/Resources/Assets.xcassets/Exercises/` 与
`scripts/artwork/svg/` 下的图片同样以 CC BY-SA 3.0 发布**，详见
[图片许可说明](Sources/Resources/Assets.xcassets/Exercises/LICENSE.md)。
本仓库的 Swift 源代码不受该许可影响。

动作名称、肌群与器械归类、动作要点文字均为原创。
