#!/usr/bin/env python3
"""把渲染好的 PNG 装进 Assets.xcassets。

图按 template 渲染，app 里用 Theme 的颜色 tint，所以源图只有 alpha 有意义。
用法：build_assets.py <png 目录>
"""
import json, os, shutil, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEST = os.path.join(ROOT, 'Sources/Resources/Assets.xcassets/Exercises')

def main(src):
    shutil.rmtree(DEST, ignore_errors=True)
    os.makedirs(DEST)
    # 不开 provides-namespace: 开了之后资源名会变成 "Exercises/<id>-1",
    # UIImage(named:) 按裸 id 查就找不到。
    json.dump({'info': {'author': 'xcode', 'version': 1}},
              open(os.path.join(DEST, 'Contents.json'), 'w'), indent=2)
    n = 0
    for f in sorted(os.listdir(src)):
        if not f.endswith('.png'): continue
        name = f[:-4]
        d = os.path.join(DEST, name + '.imageset')
        os.makedirs(d)
        shutil.copy(os.path.join(src, f), os.path.join(d, f))
        json.dump({
            'images': [{'filename': f, 'idiom': 'universal', 'scale': '3x'},
                       {'idiom': 'universal', 'scale': '1x'}, {'idiom': 'universal', 'scale': '2x'}],
            'info': {'author': 'xcode', 'version': 1},
            'properties': {'template-rendering-intent': 'template'},
        }, open(os.path.join(d, 'Contents.json'), 'w'), indent=2)
        n += 1
    print(f'写入 {n} 个 imageset -> {DEST}')

if __name__ == '__main__':
    main(sys.argv[1])
