"""Вырезает спрайты Милы и врагов из листов hero.png / enemies.png.

Белый фон листов превращается в прозрачность: пиксель считается фоном,
если он почти белый и малонасыщенный. Вокруг каждого персонажа берётся
прямоугольник по сетке листа, затем картинка обрезается по непрозрачным
пикселям. Запуск:  python3 tools/extract_sprites.py
"""
from PIL import Image
import numpy as np, os

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites')
os.makedirs(OUT, exist_ok=True)

def white_to_alpha(im: Image.Image) -> Image.Image:
    a = np.array(im.convert('RGB')).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx = a.max(axis=2); mn = a.min(axis=2); sat = mx - mn
    alpha = np.full(mn.shape, 255, dtype=np.float32)
    # почти белый и малонасыщенный -> прозрачный, с мягкой кромкой 225..250
    cand = (mn > 215) & (sat < 38)
    alpha[cand] = np.clip((250 - mn[cand]) / 35.0, 0, 1) * 255
    out = np.dstack([np.array(im.convert('RGB')), alpha.astype(np.uint8)])
    return Image.fromarray(out, 'RGBA')

def extract(sheet, box, name):
    crop = white_to_alpha(sheet.crop(box))
    bbox = crop.getbbox()
    if bbox: crop = crop.crop(bbox)
    crop.save(os.path.join(OUT, name))
    print(f"{name:22s} box={box} -> {crop.size}")

hero = Image.open('hero.png')
enemies = Image.open('enemies.png')

# Мила: верх. ряд — стойка, бег x2, прыжок, выстрел; ниж. ряд — победа, урон, смерть
extract(hero, (70, 55, 285, 410),  'hero_idle.png')
extract(hero, (330, 65, 550, 400), 'hero_run1.png')
extract(hero, (585, 75, 815, 405), 'hero_run2.png')
extract(hero, (850, 45, 1075, 400),'hero_jump.png')
extract(hero, (1065, 95, 1430, 430),'hero_shoot.png')
extract(hero, (640, 445, 950, 825),'hero_win.png')
extract(hero, (345, 500, 595, 825),'hero_hurt.png')
extract(hero, (1220, 580, 1540, 825),'hero_dead.png')

# Враги (подписи под спрайтами в вырезки не входят)
extract(enemies, (155, 95, 340, 270),  'enemy_slime.png')
extract(enemies, (535, 75, 855, 265),  'enemy_bat.png')
extract(enemies, (1030, 95, 1265, 280),'enemy_spider.png')
extract(enemies, (115, 400, 315, 660), 'enemy_mushroom.png')
extract(enemies, (530, 405, 820, 665), 'enemy_spiker.png')
extract(enemies, (955, 430, 1185, 660),'enemy_purple.png')
print("done ->", os.path.normpath(OUT))
