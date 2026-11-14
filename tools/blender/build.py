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

# особые и сюжетные места (v1.0.10): форт, баньян, бункер, ледник, храм, лагерь на сваях, маяки — семейство "places"
# (виды поверхности мест — texbake_places.py: тёсаный камень, бетон, ржавое железо, лёд, базальт, резьба, мокрые сваи)
PLACES = ["fort_wall", "fort_gate", "gatehouse", "lever", "cellar_wall", "fresco_slab", "fisher_hut",
          "banyan_giant", "deck", "fire_bowl", "treehouse", "treehouse_ruin",
          "met_station", "bunker_wall", "bunker_ceiling", "bunker_deck", "ladder", "bunker_rail", "bunker_chain",
          "bunker_lamp", "bunker_shelves", "bunker_crates", "bunker_hatch", "bunker_hatch_inner", "generator",
          "generator_broken", "station_desk", "radio", "radio_broken", "graves", "storm_tower", "storm_tower_ruin",
          "glacier_wall", "ice_steps", "frozen_waterfall", "ice_ledge", "observatory", "telescope", "star_dial",
          "star_ring_1", "star_ring_2", "star_ring_3", "ice_tower", "ice_tower_frozen",
          "hot_springs", "clinic", "crater_wall", "rock_holds", "lava_rim", "temple_facade", "temple_door", "monolith",
          "lava_chute", "lava_bowl", "lava_crack", "cold_stone", "volcano_tower", "volcano_tower_ruin",
          "stilt_platform", "stilt_pier", "stilt_hut", "signal_rock", "standing_stone", "screen_rock", "fog_tower",
          "fog_tower_ruin",
          "great_lighthouse", "tower_holds", "tower_ledge", "great_fire", "grandfather_house", "grandpa_bench",
          "order_board", "perch", "wild_bed",
          "lighthouse_ruin", "old_camp"]
# атлас мест — по площади (70 пикселей на метр, 256–1024); крупнее — то, что видно вплотную или очень большое
PLACES_SIZE = {"banyan_giant": 2048, "great_lighthouse": 2048, "bunker_wall": 2048, "grandfather_house": 2048,
               "fresco_slab": 512, "cellar_wall": 512, "bunker_ceiling": 1024}
# кому в атласе больше места (имя сетки → во сколько раз крупнее): у баньяна огромная крона съедала ствол у ярусов
PLACES_BOOST = {"banyan_giant": {"Trunk": 4.0, "AerialRoots": 2.0}}

# эти модели запекаются в текстуру (texbake.py): чёткие границы цветов, ткань, пряди, шерсть, перья, дерево, камень
TEXTURED = PEOPLE + ANIMALS + WEAR + BUILDINGS + BOATS + PLACES


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
        if name in PLACES:
            size = texbake.bake_model(name, "places", size=PLACES_SIZE.get(name), boost=PLACES_BOOST.get(name),
                                      seed=len(name), report=report)
        elif name in BUILDINGS or name in BOATS:
            # дерево, солома, камень, металл, верёвка — texbake.detail_build
            size = texbake.bake_model(name, "build", size=TEX_SIZE.get(name), seed=len(name), report=report)
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
