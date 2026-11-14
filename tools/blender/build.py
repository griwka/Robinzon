"""Собрать все 3D-модели игры в assets/models/*.glb.

Нужен Blender как Python-модуль:  pip install bpy   (Python 3.13)
Запуск:  python tools/blender/build.py            — все модели
         python tools/blender/build.py palm goat  — только указанные
"""
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
OUT = os.path.join(HERE, "..", "..", "assets", "models")

import kit  # noqa: E402
import texbake  # noqa: E402
import texbake_props  # noqa: E402

MODULES = ["models_characters", "models_nature", "models_buildings", "models_farm", "models_jungle", "models_banyan", "models_fort", "models_storm", "models_ice", "models_volcano", "models_fog", "models_eye", "models_tools", "models_flora"]


PEOPLE = ["player", "marta", "stepa", "timur", "ingrid", "vera", "misha", "renata", "gosha", "petya", "pasha", "lyova"]


ANIMALS = ["parrot", "chicken", "goat", "sheep", "pig", "goose", "penguin", "walrus", "tortoise", "monkey", "crab"]


# чем покрыто животное (texbake.detail): перья — ряды пёрышек, шкура — мягкие пятна; остальные — штрихи шерсти
SKIN_KIND = {"parrot": "feather", "chicken": "feather", "goose": "feather", "penguin": "feather",
             "pig": "hide", "walrus": "hide", "tortoise": "hide", "crab": "smooth"}

# одежда героя: куски надеваются на суставы игрока (Player.update_clothes)
WEAR = ["wear_sweater", "wear_jacket", "wear_boots", "wear_mittens", "wear_fire_gloves"]

# постройки из Data.BUILDINGS (v1.0.7): дерево, солома, камень, металл, верёвка, парусина, глина
BUILDINGS = ["tent", "campfire", "torch", "workbench", "hut", "coop", "goat_pen", "fence", "flowerbed", "bench",
             "hammock", "scarecrow", "shell_path", "garden_bed", "beehive", "sheep_pen", "pig_sty", "kiln",
             "shelter", "lightning_rod", "goose_house", "stove", "greenhouse", "tortoise_pen", "forge", "stone_bridge",
             "pumpkin_lantern", "village_house", "well", "long_table"]

# лодки и прочие суда — целые и разбитые
BOATS = ["raft", "canoe", "lifeboat", "boat_wreck", "stepa_boat", "stepa_boat_wreck", "seaplane",
         "albatros", "albatros_wreck", "albatros_mast", "albatros_helm", "albatros_lights"]

# своё разрешение атласа (иначе — по площади модели): шхуна 15 м и хижина (бамбук + три яруса соломы) — крупнее
TEX_SIZE = {"albatros": 2048, "albatros_wreck": 2048, "hut": 2048}

# эти модели запекаются в текстуру (texbake.py): чёткие границы цветов, ткань, пряди, шерсть, перья, дерево, камень
TEXTURED = PEOPLE + ANIMALS + WEAR + BUILDINGS + BOATS

# камни и мелочь (v1.0.9): валуны, скалы, лёд, ракушки, ящики, инструменты — texbake_props.py (вид по пикселю)
PROPS = texbake_props.PROPS
TEXTURED = TEXTURED + PROPS


def all_builders():
    out = {}
    for m in MODULES:
        try:
            mod = __import__(m)
        except ImportError as e:
            print("skip", m, e)
            continue
        out.update(mod.BUILDERS)
    return out


def texture_imports():
    """Текстуры запечённых моделей Godot извлекает из .glb сам (assets/models/<имя>_<имя>_albedo.png) с настройками
    «без сжатия». Ставим сжатие VRAM (S3TC/DXT1): на глаз как без сжатия, а места на диске и в видеопамяти —
    0.7 МБ на атлас 1024 вместо 1 МБ и 5.6 МБ (BPTC дал бы 1.4 МБ без видимой разницы).
    Работает для уже существующих .import — после первого импорта нового атласа запустить build.py ещё раз
    (или только эту функцию: python tools/blender/build.py --imports) и снова --import."""
    n = 0
    for name in TEXTURED:
        p = os.path.join(OUT, "%s_%s_albedo.png.import" % (name, name))
        if not os.path.exists(p):
            continue
        s = open(p, encoding="utf-8").read()
        t = s.replace("compress/mode=0", "compress/mode=2")
        if t != s:
            with open(p, "w", encoding="utf-8", newline="") as fh:
                fh.write(t)
            n += 1
    if n:
        print("сжатие S3TC выставлено у %d текстур — запустите godot --headless --path . --import" % n)


def main():
    if sys.argv[1:] == ["--imports"]:
        texture_imports()
        return
    os.makedirs(OUT, exist_ok=True)
    builders = all_builders()
    args = sys.argv[1:]
    report = "--kinds" in args          # напечатать виды поверхности построек (что угадалось по цвету)
    args = [a for a in args if a != "--kinds"]
    names = args or list(builders)
    for name in names:
        t = time.time()
        kit.reset()
        builders[name]()
        size = 0
        if name in BUILDINGS or name in BOATS:
            # дерево, солома, камень, металл, верёвка — texbake.detail_build
            size = texbake.bake_model(name, "build", size=TEX_SIZE.get(name), seed=len(name), report=report)
        elif name in PROPS:
            size = texbake_props.bake(name, seed=len(name), report=report)
        elif name in TEXTURED:
            # раскраска считается в каждом пикселе атласа; складки, пряди, шерсть — там же (texbake.detail)
            size = texbake.bake_model(name, "animals" if name in ANIMALS else "people", seed=len(name),
                                      default=SKIN_KIND.get(name, "fur"))
        kit.export(os.path.join(OUT, name + ".glb"), textured=size > 0)
        tris = sum(len(o.data.loop_triangles) if (o.data.calc_loop_triangles() or True) else 0
                   for o in kit.bpy.context.scene.objects if o.type == "MESH")
        print("%-16s %6d tris  %.1fs%s" % (name, tris, time.time() - t, "  tex %d" % size if size else ""))
    texture_imports()


if __name__ == "__main__":
    main()
