# 动作演示图流水线

从维基共享资源抓 Everkinetic 的动作插画，转成 app 用的 template 图片资源。
全流程可复现，改动作库之后重跑即可。

许可义务见 `Sources/Resources/Assets.xcassets/Exercises/LICENSE.md`，**别删那个文件**。

## 文件

| 文件 | 作用 |
|---|---|
| `images.json` | 动作 id → 维基共享资源上的动作名 |
| `substitutions.json` | 原动作图库里没有、换成近似动作的记录（含换成了什么、为什么） |
| `credits.json` | 每张图的原始文件名与来源链接，`CreditsView` 的数据依据 |
| `svg/` | 下载并重命名后的 SVG 源文件（CC BY-SA 3.0） |
| `render_svg.swift` | SVG → 透明 PNG，只能在 Mac 上跑（靠 NSImage 认 SVG） |
| `build_assets.py` | PNG → `Assets.xcassets/Exercises/` |

## 重新生成

```bash
# 1. Mac 上渲染（Linux 没有 SVG 渲染器）
MAC=/Users/bytedance/Documents/web-infra-others/my-code-dev/liftbook
rsync -az -e "ssh -p 2222" scripts/artwork/svg/ bytedance@127.0.0.1:$MAC/scripts/artwork/svg/
ssh -p 2222 bytedance@127.0.0.1 "cd $MAC && swiftc -O scripts/artwork/render_svg.swift -o /tmp/rendersvg && /tmp/rendersvg scripts/artwork/svg /tmp/artpng 480"

# 2. 拉回并压成灰度+alpha（template 图只用 alpha，体积减半）
scp -P 2222 'bytedance@127.0.0.1:/tmp/artpng/*.png' /tmp/artpng/
python3 -c "
from PIL import Image; import glob, os
for f in glob.glob('/tmp/artpng/*.png'):
    im = Image.open(f).convert('RGBA')
    Image.merge('LA', (Image.new('L', im.size, 0), im.getchannel('A'))).save('/tmp/artopt/'+os.path.basename(f), optimize=True)"

# 3. 装进资源目录
python3 scripts/artwork/build_assets.py /tmp/artopt
```

## 坑

- **资源目录不能开 `provides-namespace`**：开了之后资源名变成 `Exercises/<id>-1`，
  `UIImage(named: "<id>-1")` 直接返回 nil，界面上表现为全都是「暂无演示图」。
- **抓维基共享资源必须带 User-Agent**，否则一律 403。
- 公司代理连不上维基共享资源，这一步要走默认代理。
- 换动作或加动作后，`images.json` 与 `credits.json` 都要更新，
  `CreditsView` 的逐条署名列表是按资源是否存在实时算的，不用手工维护。
