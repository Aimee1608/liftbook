from PIL import Image, ImageDraw

S = 1024
img = Image.new("RGB", (S, S), (0, 0, 0))
d = ImageDraw.Draw(img)
lime = (198, 245, 66)
dark = (28, 28, 30)
cy = S // 2
bar_h = 64
d.rounded_rectangle((250, cy - bar_h // 2, S - 250, cy + bar_h // 2), radius=32, fill=lime)
for x in (150, S - 150 - 130):
    d.rounded_rectangle((x, cy - 210, x + 130, cy + 210), radius=40, fill=lime)
for x in (60, S - 60 - 80):
    d.rounded_rectangle((x, cy - 150, x + 80, cy + 150), radius=30, fill=lime)
d.rounded_rectangle((300, cy + 300, S - 300, cy + 340), radius=20, fill=dark)
img.save("Sources/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
print("ok")
