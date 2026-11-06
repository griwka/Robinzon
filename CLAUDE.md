# Памятка для Claude Code — «Затерянный остров»

Уютная 3D-игра на Godot 4.7 (GDScript). Автор проекта общается по-русски: отвечай по-русски.

## Что прочитать в первую очередь
- `ОПИСАНИЕ.md` — вся игра и устройство проекта.
- `СЦЕНАРИЙ.md` — полный сюжет 8 глав. Главы 1–4 сделаны, 5–8 расписаны по заданиям. Это план работ.
- `docs/DESIGN.md` — стиль, системы, дорожная карта.

## Пожелания автора (соблюдать всегда)
- **Без энергии и таймеров «успей или потеряешь».**
- **Графика уютная:** насыщенная, округлая, не «мыльная» и не кислотно-зелёная. Иконки крупные, на светлом фоне.
- **Сюжет взрослый:** ищем брата Лёву. Тексты простыми словами: никаких редких морских и старинных слов.
- **Не копировать** оригинальную мобильную игру: берём только суть (заросший остров, расчистка инструментами, далёкие задания).
- **У каждой сущности — своя модель из Blender** (`tools/blender`).
- **Качество важнее экономии:** не хватает инструмента или библиотеки — скачай.
- **Ни одно задание не должно стать невыполнимым** из-за действий игрока: валидатор + автотест.
- **Экономика идёт за сюжетом:** монеты на покупки главы зарабатываются хозяйством.
- **Каждую готовую часть — сразу в git (commit + push)**, вместе с моделями, иконками и звуками.

## Устройство
- **Весь контент — в `scripts/data.gd`:**
  - предметы, рецепты, постройки, загоны, лавки, цены;
  - коллекции, острова (`LOCATIONS`), главы и задания (`CHAPTERS`), говорящие (`SPEAKERS`).
- **`scripts/game.gd`** (autoload `Game`) — состояние, задания, торговля, сохранения.
  Виды пунктов заданий: см. `QuestValidator.KNOWN_KINDS`.
- **`scripts/quest_validator.gd`** — проверка, что каждое задание выполнимо по порядку, плюс отчёт по монетам.
  Новых жителей, головоломки и ярусы добавляй в `NPCS`, `PUZZLES`, `DECKS`.
- **`scripts/dev_tools.gd`** — автотесты и скриншоты. Каждой новой главе нужен свой автотест.
- **Острова:** один генератор `scripts/island.gd`; особые места — `fort_ruin.gd`, `banyan_tree.gd`, `storm_station.gd`, `ice_glacier.gd`,
  `volcano_crater.gd`, `volcano_temple.gd`, `hot_springs.gd`, `stilt_camp.gd`, `signal_rock.gd`, `fog_shrine.gd`,
  `great_lighthouse.gd`, `eye_island.gd`, `eye_storm.gd` (бункер — в `storm_station.gd`), `story_place.gd`. Кольца преград вокруг мест — `Island.RINGS`.
- **Око шторма (глава 8)** — `GreatLighthouse` (три яруса `eye_deck1..3`, ветер порывами: `GreatLighthouse.gust`,
  `Climbable.wind`, `Player.ext_push`), `GreatFire` (выбор, ритуалы Хранителя), `EyeStorm` (стена и лучи),
  `EyeIsland` (сад, команда на берегу). Разговор по заданию — `NPCPerson.quest_talk()`: в пункте `say` — реплики,
  `give` — подарок, `"radio": true` — по рации (T). Финал: `Game.ended()`, флаги `ending_open_sea` / `ending_keeper`;
  после финала — `OrderBoard`, лавка `lyova`, `Game.sell_mult()`, `bounty_today()`, `window_open()`.
  Темы музыки — `Audio.play_theme()` (`music_eye`, `music_meeting`, `music_sea`, `music_keeper`).
- **Гроза** — `scripts/weather.gd` (только на Грозовом): `Game.storm_active()`; громоотвод — загон `lightning_rod`
  с `"storm": true` в `Data.PENS`. Ярусы бункера `bunker1..7` — свет от генератора (1–3) или фонарь.
- **Холод** — `scripts/warmth.gd` (только на Ледяном до флага `ice_thawed`): `Game.cold_active()`, `Game.warmth`,
  `Game.cold_mult()` по одежде; тёплые места — постройки из `Warmth.SOURCES` и узлы в группе `warm_spot`.
  Оттепель — `Island.thaw()`; одежда на герое — `Player.update_clothes()` (модели `wear_*` с кусками Torso/Sleeve*/Boot*/Mitten*).
- **Жар** — `scripts/heat.gd` (только на Вулкане): `Game.heat`, `Game.salve_t`; источники — узлы в группе `lava`
  с `heat_at(p)` и `push_dir(p)` (`scripts/lava.gd`: `Lava.Arc`, `Lava.Pool`), остужают узлы в группе `cool_spot`.
  Постройка только на отмеченных местах — `"spot": [группы]` в `Data.BUILDINGS` (`bridge_spot`, `lantern_spot`,
  `shadow_spot`), метки — `LanternSpot` / `VolcanoTemple.BridgeSpot` с `set_bridged()`.
- **Туман** — `scripts/fog_system.gd` (Туманный остров до флага `fog_cleared`): объёмный туман + `FogVolume`
  с отрицательной плотностью у огня (группы `station_*` из `FogSystem.RADIUS` и узлы `fog_light` с `fog_radius`).
  Плыть туда — только `Game.fog_hours()`; пассажир — флаг `stepa_aboard` → `Game.arrive()`.
- **Ассеты собираются скриптами, руками не правятся:**
  - модели: `tools/blender/*.py` → `assets/models/*.glb`;
  - иконки: `tools/gen_icons.py` → `assets/icons/`;
  - звук: `tools/gen_audio.py` → `assets/audio/`.

## Графика (подробно — `docs/ГРАФИКА.md`)
- **Где что лежит:**
  - свет, небо, дымка, SSAO, свечение, постобработка и общие параметры шейдеров — `scripts/world_env.gd`;
  - цвета — `scripts/palette.gd`;
  - эффекты — `scripts/fx.gd`, погода — `scripts/weather.gd`.
- **Шейдеры моделей:**
  - общий код — `shaders/toon_common.gdshaderinc`, его подключают `toon` и `toon_foliage` (`#define FOLIAGE`);
  - общие параметры (`g_sun_dir`, `g_player_pos`, `g_wind`, `g_rain`, `g_light`, `g_cloud_*`) объявлены
    в `project.godot → [shader_globals]`.
- **Чего не делать — всё это даёт NaN-пиксели, которые свечение раздувает в белые пятна:**
  - не читать `COLOR` в проходе контура (`outline.gdshader`): у части сеток в моделях нет цвета вершин;
  - не писать `pow(x, дробное)`, если x может быть 0 (используйте `x * sqrt(x)`, `x * x` или `max(x, 1e-4)`);
  - не нормировать вектор, который может быть нулевым, без проверки длины.
- **Не использовать `instance uniform`** в шейдерах, которые попадают в MultiMesh (цветы, частицы):
  там в нём мусор. Вспышка при ударе сделана через `material_overlay` (`FX.flash`).

## Правила кода
- **Предупреждения GDScript считаются ошибками.** Если тип выводится как Variant, пиши тип явно:
  `var t: Vector3 = ...`, `var n: int = dict["x"]`.
- **Узлы в моделях с особыми именами:**
  - суставы персонажа: `Body`, `Head`, `ArmL`/`ArmR`, `LegL`/`LegR`, `HandR`;
  - листва: `Crown` и `*_leaf` (ветер и прозрачность у камеры);
  - остальное: `Fruit`, `Lid`, `DoorL`/`DoorR`, `Handle`, `FirePoint`, `Perch`, `Soil`.
- **Сохранение:** версия `SAVE_VERSION` в `game.gd`. Новые флаги для старых сохранений — через миграцию в `load_game`.

## Команды
Godot должен быть в PATH как `godot`; на Windows — консольная версия `Godot_v4.7.x-stable_win64_console.exe`.

```bash
godot --headless --path . -- --validate
godot --headless --path . -- --autotest
godot --headless --path . -- --autotest --location=banyan --chapter=2
godot --headless --path . -- --autotest --location=fort --chapter=3
godot --headless --path . -- --autotest --location=fort --chapter=4 --upto=1
godot --headless --path . -- --autotest --location=storm --chapter=4 --from=1
godot --headless --path . -- --autotest --location=storm --chapter=5 --upto=1
godot --headless --path . -- --autotest --location=ice --chapter=5 --from=1
godot --headless --path . -- --autotest --location=volcano --chapter=6
godot --headless --path . -- --autotest --location=fog --chapter=7 --upto=13
godot --headless --path . -- --autotest --location=home --chapter=7 --from=13 --upto=1
godot --headless --path . -- --autotest --location=fog --chapter=7 --from=14
godot --headless --path . -- --autotest --location=eye --chapter=8
godot --headless --path . -- --autotest --location=eye --chapter=8 --from=9 --ending=keeper
godot --path . --resolution 1600x900 -- --shot=shot.png --frames=90 --location=fort
```

Скриншот в Forward+ без видеокарты (облако): поставить `mesa-vulkan-drivers` и запускать так:
```bash
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --resolution 1600x900 -- --shot=shot.png --frames=60 --nohud --demo
```

Полезные аргументы для `dev_tools`:
- `--time=0..1` — время суток;
- `--demo` — построить лагерь с фермой;
- `--gallery` — все модели рядом;
- `--at=x,y,z` — поставить героя в точку;
- `--deck=N` — ярус баньяна;
- `--fortview=closed|open|cellar` — вид форта;
- `--near=stepa` — герой рядом со Стёпой;
- `--yaw= --pitch= --dist= --camy=` — камера;
- `--lookat=old_camp` — камера на сюжетное место;
- `--nohud` — кадр без интерфейса;
- `--flush` — закрыть вступительные диалоги;
- `--rain=0.8` — дождь;
- `--storm=1` / `--storm=0` — на Грозовом: гроза всё время / без грозы;
- `--bunker=N` (+ `--lit=1` — генератор и фонарь) — герой на ярусе N бункера;
- `--near=timur|storm_tower|seaplane|stepa_boat` — герой у места;
- `--near=glacier_top|ingrid|walrus|penguins|ice_tower|ice_ledge|ice_chest_3` — то же на Ледяном;
- `--thaw=1` — Ледяной остров уже оттаял; `--wear=sweater|jacket|fire` — герой в тёплой одежде / огнеупорных рукавицах;
- `--near=vera|springs|temple_gate|crater_top|volcano_tower` — места на Вулкане; `--view=temple` — вид на вход в храм;
  `--solved=1` — мостки построены и монолит решён;
- `--near=stilt_camp|signal_rock|fog_shrine|fog_tower|misha|renata` — места на Туманном; `--view=albatros` — вид на корабль;
  `--fogdone=1` — туман ушёл, «Альбатрос» починен;
- `--near=eye_tower|eye_top|grandfather_house|great_lighthouse` — места на Оке; `--eyedeck=1..3` — герой на балконе маяка;
  `--lens=1` — Великий огонь золотой; `--ending=sea|keeper` — финал (для скриншотов и автотеста главы 8);
- автотест: `--from=K` — начать с K-го задания главы, `--upto=K` — пройти только K заданий;
- `--fxtest` — все эффекты перед кадром;
- `--dbgdraw=1|2|5|12` — без света / только свет / нормали / SSAO.

Пересборка ассетов (Python 3.13 с `pip install bpy numpy scipy pillow`, для музыки и фона — ffmpeg в PATH;
`python tools/gen_audio.py thunder0 radio` — только указанные эффекты, без ffmpeg). Иконки главы 4 — в `tools/icons_storm.py`, главы 5 — в `tools/icons_ice.py`, главы 6 — в `tools/icons_volcano.py`, главы 7 — в `tools/icons_fog.py`, главы 8 — в `tools/icons_eye.py`.
Без ffmpeg `.ogg` пишется через `pip install soundfile`; музыка главы 8: `python tools/gen_audio.py music_eye music_meeting music_sea music_keeper`.
На Windows Godot можно вызывать полным путём, если его нет в PATH.
```bash
python tools/blender/build.py
python tools/blender/build.py marta sheep
python tools/gen_icons.py
python tools/gen_audio.py
```
`build.py` без имён пересобирает все модели, с именами — только указанные.

При выходе из headless Godot пишет «resources still in use» про .ogg — это известная особенность Godot, не ошибка проекта.

## Порядок работы над новой главой
1. Задания, реплики, предметы — из `СЦЕНАРИЙ.md` в `data.gd`.
2. Новые системы и места (`island.gd`, свои скрипты).
3. Модели в `tools/blender/models_<имя>.py` (подключить в `build.py`), иконки, звуки.
4. Пополнить валидатор и автотест.
5. `--validate` → 0 проблем, все `--autotest` проходят. Проверить скриншотами, как выглядит.
6. Обновить `ОПИСАНИЕ.md` (задания главы, история версий) и `README.md`.
7. Коммит и `git push`.
