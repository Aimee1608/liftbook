# 动作演示图许可

本目录下全部动作演示图改编自 Everkinetic 的健身动作插画。

- 原作者：Everkinetic（http://everkinetic.com/）
- 原始来源：维基共享资源 https://commons.wikimedia.org/wiki/Category:Weight_training_diagrams
- 原始许可：Creative Commons Attribution-ShareAlike 3.0 Unported (CC BY-SA 3.0)

## 我们做了什么修改

1. 从维基共享资源下载 SVG 原图（少数几张取自 chaosbastler/opentraining-exercises，同一作者同一许可）
2. 按动作重命名为 `<动作 id>-1.svg` / `-2.svg`（起始 / 结束两帧）
3. 渲染为带透明通道的 PNG，仅保留 alpha 通道，在 app 内按 template 方式着色以适配深色界面

SVG 源文件保留在 `scripts/artwork/svg/`，逐张的原始文件名与来源链接记录在
`scripts/artwork/credits.json`。

## 本目录的许可

**根据 CC BY-SA 3.0 的相同方式共享条款，本目录下的图片（含 `scripts/artwork/svg/`
下的 SVG 源文件）同样以 Creative Commons Attribution-ShareAlike 3.0 Unported 许可发布。**

许可全文：https://creativecommons.org/licenses/by-sa/3.0/

注意：CC BY-SA 的传染性仅作用于图片本身及其演绎作品，**不影响本仓库中 Swift 源代码
与其他原创内容的许可**——代码不是图片的演绎作品。
