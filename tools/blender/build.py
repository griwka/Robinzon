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

MODULES = ["models_characters", "models_nature", "models_buildings", "models_farm", "models_jungle", "models_banyan", "models_fort", "models_storm", "models_ice", "models_volcano", "models_fog"]


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


def main():
    os.makedirs(OUT, exist_ok=True)
    builders = all_builders()
    names = sys.argv[1:] or list(builders)
    for name in names:
        t = time.time()
        kit.reset()
        builders[name]()
        kit.export(os.path.join(OUT, name + ".glb"))
        tris = sum(len(o.data.loop_triangles) if (o.data.calc_loop_triangles() or True) else 0
                   for o in kit.bpy.context.scene.objects if o.type == "MESH")
        print("%-16s %6d tris  %.1fs" % (name, tris, time.time() - t))


if __name__ == "__main__":
    main()
