#!/usr/bin/env python3
"""CM Health branding asset generator.

Runs in CI after the upstream source is checked out and the overlay applied.
Reads the master CM logo (grey/gold on transparent) and produces:
  - assets/images/icon.png     master app icon (dark square, recolored logo)
  - assets/images/icon_fg.png  adaptive-icon foreground (transparent, padded)
  - assets/splash/splashscreen.mp4  dark fade-in splash built with ffmpeg

Usage: python3 tool/cm_branding.py <path-to-cm-logo.png>
(cwd must be the flutter source root)
"""
import subprocess, sys, tempfile, os
import numpy as np
from PIL import Image

BG = (20, 20, 22, 255)          # #141416
LIGHT = np.array([216, 213, 208], dtype=float)  # warm light grey

def load_logo(path):
    src = Image.open(path).convert('RGBA')
    a = np.array(src)
    alpha = a[:, :, 3]
    ys, xs = np.where(alpha > 30)
    logo = a[ys.min():ys.max()+1, xs.min():xs.max()+1].copy()
    rgb = logo[:, :, :3].astype(float)
    brightness = rgb.mean(axis=2)
    is_gold = (rgb[:, :, 0] - rgb[:, :, 2]) > 50
    is_dark = (brightness < 100) & ~is_gold
    t = np.clip((100 - brightness) / 100, 0, 1)[:, :, None] * is_dark[:, :, None]
    rgb = rgb * (1 - t) + LIGHT * t
    logo[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    return Image.fromarray(logo, 'RGBA')

def compose(logo, size, logo_frac, bg):
    canvas = Image.new('RGBA', (size, size), bg)
    lw = int(size * logo_frac)
    lh = int(lw * logo.height / logo.width)
    li = logo.resize((lw, lh), Image.LANCZOS)
    canvas.alpha_composite(li, ((size - lw) // 2, (size - lh) // 2))
    return canvas

def main():
    logo_path = sys.argv[1]
    logo = load_logo(logo_path)

    os.makedirs('assets/images', exist_ok=True)
    compose(logo, 1024, 0.74, BG).save('assets/images/icon.png')
    compose(logo, 1024, 0.52, (0, 0, 0, 0)).save('assets/images/icon_fg.png')
    print('icons written')

    # Splash: 720x1280, 4s, logo fades in over dark background.
    frame = compose(logo, 720, 0.62, BG).convert('RGB')
    full = Image.new('RGB', (720, 1280), BG[:3])
    full.paste(frame, (0, (1280 - 720) // 2))
    with tempfile.TemporaryDirectory() as td:
        fp = os.path.join(td, 'frame.png')
        full.save(fp)
        os.makedirs('assets/splash', exist_ok=True)
        subprocess.run([
            'ffmpeg', '-y', '-loop', '1', '-i', fp, '-t', '4',
            '-vf', "fade=t=in:st=0.2:d=1.2:color=0x141416",
            '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-r', '30',
            '-movflags', '+faststart', 'assets/splash/splashscreen.mp4',
        ], check=True, capture_output=True)
    print('splash written')

if __name__ == '__main__':
    main()
