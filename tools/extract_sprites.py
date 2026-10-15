"""Вырезает спрайты Милы и врагов из листов hero_bck.png / enemies.png.

Почему героиня раньше просвечивала: на старом листе hero.png фон был
белым, и альфа считалась от «белизны» пикселя — поэтому белая одежда
и светлые волосы Милы тоже становились полупрозрачными.

Теперь исходник героини — hero_bck.png на СЕРОМ фоне, а прозрачность
делается заливкой фона по связности (flood fill от краёв кадра):
прозрачным становится только настоящий фон, до которого можно «дойти»
от края, не пересекая тёмный контур персонажа. Белые и светлые участки
внутри силуэта остаются полностью непрозрачными, кромка слегка
смягчается и очищается от примеси цвета фона (без серого ореола).

Запуск:  python3 tools/extract_sprites.py   (нужны Pillow и numpy)
"""
from PIL import Image, ImageDraw, ImageFilter
import numpy as np, os

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites')
os.makedirs(OUT, exist_ok=True)
SENTINEL = (0, 255, 0)  # чисто зелёного в персонажах нет


def bg_to_alpha(im: Image.Image, thresh: int, bg_near: int = 0) -> Image.Image:
    """Прозрачность = фон, связный с краями кадра (flood fill)."""
    im = im.convert('RGB')
    w, h = im.size
    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1),
             (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2)]
    # цвет фона оцениваем по углам
    corners = np.array([im.getpixel(s) for s in seeds[:4]], dtype=np.float32)
    bg = corners.mean(axis=0)

    filled = im.copy()
    for s in seeds:
        if filled.getpixel(s) != SENTINEL:
            ImageDraw.floodfill(filled, s, SENTINEL, thresh=thresh)

    a = np.array(filled).astype(np.int16)
    is_bg = (np.abs(a - np.array(SENTINEL)).max(axis=2) == 0)
    if bg_near:  # добить карманы фона, отрезанные контуром (только серый лист)
        src = np.array(im).astype(np.int16)
        near = np.abs(src - bg).max(axis=2) < bg_near
        is_bg |= near

    alpha = np.where(is_bg, 0, 255).astype(np.uint8)
    # мягкая кромка ~1px
    alpha_im = Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(0.7))
    alpha = np.array(alpha_im)

    rgb = np.array(im).astype(np.float32)
    af = (alpha.astype(np.float32) / 255.0)[..., None]
    # очистка кромки от примеси фона: c = (c - bg*(1-a)) / a
    ok = af[..., 0] > 0.02
    clean = rgb.copy()
    clean[ok] = np.clip((rgb[ok] - bg * (1 - af[ok])) / np.maximum(af[ok], 0.05), 0, 255)
    clean[alpha == 0] = 0
    out = np.dstack([clean.astype(np.uint8), alpha])
    return Image.fromarray(out, 'RGBA')


def extract(sheet, box, name, thresh, bg_near=0):
    crop = bg_to_alpha(sheet.crop(box), thresh, bg_near)
    bbox = crop.getbbox()
    if bbox:
        crop = crop.crop(bbox)
    crop.save(os.path.join(OUT, name))
    arr = np.array(crop)
    opaque = (arr[..., 3] > 250).mean() * 100
    print(f"{name:22s} -> {crop.size}  непрозрачных пикселей: {opaque:.0f}%")
    return crop


hero = Image.open('hero_bck.png')   # героиня на сером фоне
enemies = Image.open('enemies.png')  # враги на белом фоне

# Мила: верх. ряд — стойка, бег x2, прыжок, выстрел; ниж. ряд — победа, урон, смерть
extract(hero, (70, 55, 285, 410),   'hero_idle.png',  thresh=52, bg_near=18)
extract(hero, (330, 65, 550, 400),  'hero_run1.png',  thresh=52, bg_near=18)
extract(hero, (585, 75, 815, 405),  'hero_run2.png',  thresh=52, bg_near=18)
extract(hero, (850, 45, 1075, 400), 'hero_jump.png',  thresh=52, bg_near=18)
extract(hero, (1065, 95, 1430, 430), 'hero_shoot.png', thresh=52, bg_near=18)
extract(hero, (640, 445, 950, 825), 'hero_win.png',   thresh=52, bg_near=18)
extract(hero, (345, 500, 595, 825), 'hero_hurt.png',  thresh=52, bg_near=18)
extract(hero, (1220, 580, 1540, 825), 'hero_dead.png', thresh=52, bg_near=18)

# Враги (подписи под спрайтами в вырезки не входят)
extract(enemies, (155, 95, 340, 270),   'enemy_slime.png',    thresh=34)
extract(enemies, (535, 75, 855, 265),   'enemy_bat.png',      thresh=34)
extract(enemies, (1030, 95, 1265, 280), 'enemy_spider.png',   thresh=34)
extract(enemies, (115, 400, 315, 660),  'enemy_mushroom.png', thresh=34)
extract(enemies, (530, 405, 820, 665),  'enemy_spiker.png',   thresh=34)
extract(enemies, (955, 425, 1225, 665), 'enemy_purple.png',   thresh=34)
print("done ->", os.path.normpath(OUT))
