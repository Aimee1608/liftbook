from PIL import Image, ImageDraw, ImageFilter
import sys

S = 1024
lime = (198, 245, 66)
ink = (11, 11, 13)
variant = sys.argv[1] if len(sys.argv) > 1 else "lime"
bg, fg = (lime, ink) if variant == "lime" else (ink, lime)

img = Image.new("RGB", (S, S), bg)
d = ImageDraw.Draw(img)
cy = S // 2

# 杠铃：细杆 + 每侧两片，外片略小，整体偏粗保证小尺寸可读
d.rounded_rectangle((176, cy - 34, S - 176, cy + 34), radius=34, fill=fg)
for x0 in (196, S - 196 - 118):
    d.rounded_rectangle((x0, cy - 232, x0 + 118, cy + 232), radius=44, fill=fg)
for x0 in (92, S - 92 - 84):
    d.rounded_rectangle((x0, cy - 168, x0 + 84, cy + 168), radius=36, fill=fg)
# 杆两端的卡箍
for x0 in (334, S - 334 - 40):
    d.rounded_rectangle((x0, cy - 62, x0 + 40, cy + 62), radius=16, fill=fg)

img.save(f"Sources/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" if variant == "lime" else f"/tmp/icon-{variant}.png")
print("ok", variant)
