# Памятка для Claude Code — «Затерянный остров»

Уютная 3D-игра на Godot 4.7 (GDScript). Автор проекта общается по-русски: отвечай по-русски.

## Что прочитать в первую очередь
- `ОПИСАНИЕ.md` — вся игра и устройство проекта.
- `СЦЕНАРИЙ.md` — полный сюжет 8 глав. Главы 1–4 сделаны, 5–8 расписаны по заданиям. Это план работ.
- `docs/DESIGN.md` — стиль, системы, дорожная карта.

## Пожелания автора (соблюдать всегда)
- **Без таймеров «успей или потеряешь».** Голод есть (по просьбе автора), но мягкий: никто не умирает и ничего
  не запирается — голодный только медленнее ходит и хуже отдыхает (`Game.HUNGER_*`).
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
- **Цены у торговцев** — `Data.BUYERS` (общий множитель `base` и любимые `like`: по id предмета или по виду `cat`),
  `Game.shop_mult(лавка, товар)`, `Game.sell_price(лавка, товар)` (целое ≥ 1, ×`sell_mult()`), `Game.better_buyer()` — подсказка
  в окне продажи. Новую лавку в `Data.SHOPS` — и сразу в `Data.BUYERS` (валидатор `_check_buyers` проверит: прибавка ≤ +60 %,
  Румба по прейскуранту, заряженный аккумулятор дороже всего у Тимура). Продажа везде идёт через `Game.sell(лавка, id, n)`.
- **Перечитать разговоры** — окно коллекций (`hud.gd`: `_fill_replays`, `replay_quests`, `replay_lines`): только пройденные задания
  и идущее сейчас; `show_dialogue(lines, open_collections)` возвращает окно после разговора.
- **Польза вещей** — у предметов в `Data.ITEMS` поле `"tip"` (показывается в подсказке, инвентаре и лавке, `HUD.item_tip`).
  Фонарь: `Game.has_light()` (включён ли), `light_kind()`, `night_light()`, `LANTERN_WARM/BITE/RARE` (холод, рыбалка). Огнеупорные рукавицы:
  `Game.gloves_on()`, `glove_power(kind)`, `THORNY`, `HOT_KINDS` (`ResourceNode.interact`), на герое — `Player.update_clothes()` на любом острове.
  Выключатели: `Game.GEAR` / `gear_off` / `toggle_gear("light"|"gloves")`, клавиши 5 и 6 (`main.gd`), ячейки внизу и кнопки в сумке (`hud.gd`);
  для эффектов не проверять `Game.has_tool("lantern")` / `("fire_gloves")` — только `has_light()` и `gloves_on()`.
- **Туман** — `scripts/fog_system.gd` (Туманный остров до флага `fog_cleared`): объёмный туман + `FogVolume`
  с отрицательной плотностью у огня (группы `station_*` из `FogSystem.RADIUS` и узлы `fog_light` с `fog_radius`).
  Плыть туда — только `Game.fog_hours()`; пассажир — флаг `stepa_aboard` → `Game.arrive()`.
- **Ассеты собираются скриптами, руками не правятся:**
  - модели: `tools/blender/*.py` → `assets/models/*.glb`;
  - иконки: `tools/gen_icons.py` → `assets/icons/` (подробности — раздел «Иконки» ниже);
  - звук: `tools/gen_audio.py` → `assets/audio/`.

## Иконки предметов
- Рисуем в 512×512, итог 160 px (сжатие LANCZOS). Каждая деталь — `poly(d, pts, цвет, detail=…, gloss=…, puff=…)`: объём считает
  `_cel_mask` (высота по расстоянию до края → нормали → свет сверху-слева, цветная тень, блики, контур под цвет детали).
  `detail(dd)` рисует узор в цвете детали до освещения (`ink_line`, `paint_soft`), поэтому свет ложится и на узор.
- Помощники: `spline` (плавный контур), `bez`, `tube` (трубка с переменной толщиной), `Frame` (оси вдоль предмета),
  `poly([...несколько многоугольников...])` — одна деталь (облако, гроздь). Блик у страниц и портретов слабее (`set_gloss`).
- Основные предметы (фрукты, материалы, инструменты) — `tools/icons_core.py`, главы — `icons_storm|ice|volcano|fog|eye.py`.
  Единые цвета дерева и железа (`WOOD`, `STEEL`…) — в начале `icons_core.py`; инструменты лежат диагональю, головка вверху справа.
- Проверка: `python tools/gen_icons.py banana shovel` — пересобрать только эти (`ICON_OUT=папка` — писать не в `assets/icons`);
  `python tools/icon_sheet.py лист.png` — лист всех иконок с подписями; `python tools/icon_compare.py out.png папка_было имена…` —
  лист «было / стало». После пересборки — `godot --headless --path . --import`.

## Графика (подробно — `docs/ГРАФИКА.md`)
- **Где что лежит:**
  - свет, небо, дымка, SSAO, свечение, постобработка и общие параметры шейдеров — `scripts/world_env.gd`;
  - сутки непрерывные: солнце и луна — по дугам небесной сферы (`WorldEnv._celestial`), один свет `Sun` днём — солнце,
    ночью — луна; палитра суток — `Palette.at_elevation()`; звёзды и созвездия — `scripts/sky_stars.gd`; фаза луны — по
    `Game.day`; плавное «насколько ночь» — `WorldEnv.night_amount(t)` (а `Game.is_day()` — для правил игры);
  - цвета — `scripts/palette.gd`;
  - эффекты — `scripts/fx.gd`, погода — `scripts/weather.gd`.
- **Шейдеры моделей:**
  - общий код — `shaders/toon_common.gdshaderinc`, его подключают `toon` и `toon_foliage` (`#define FOLIAGE`);
  - общие параметры (`g_sun_dir`, `g_player_pos`, `g_wind`, `g_rain`, `g_light`, `g_cloud_*`, `g_moon_dir`, `g_daylight`, `g_lamp` — сила огней) объявлены
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
- **Действия у грядок и загонов** — круг действий: `wheel_request(player)` / `wheel_options()` у `GardenBed`, `AnimalPen`, `Animal`,
  сигнал `Game.wheel_requested`, рисует `HUD.show_wheel()`. `interact()` по-прежнему делает главное дело сразу (его зовут автотесты).
- **Ячейки инструментов:** `Game.BAR_SIZE` (4), `Game.bar`, `hold_slots()`, `hold(id)` вытесняет давно не нужный инструмент.
- **Износ:** `Game.WEAR` (ударов до поломки), `Game.wear`, `use_tool()`, `tool_hp()`; железная замена — `Game.UPGRADE`,
  `tool_for(need)`, `tool_power()` (железо бьёт вдвое). `has_tool("stone_axe")` верно и при железном топоре.
  Каждый ломающийся инструмент должен делаться из возобновляемого — это проверяет валидатор (`_check_tools`).
- **Голод:** `Game.hunger` 0..100, `hunger_stage()` 0–4, `hunger_speed()`, `hunger_regen()`, `can_sprint()`, еда — `eat_best_food()`,
  `eat_item(id)`, сигнал `ate`. В автотестах голод стоит (`hunger_on`), включить — `--hunger`.
- **Железо на острове крушения** — `scripts/tide_scrap.gd` (`TideScrap`): волны выносят кучки на сухой песок (высота 0.4–0.8),
  на свободное место; такие кучки (`ResourceNode.washed`) не вырастают снова на том же месте. Любой ресурс не вырастает
  на постройке (`ResourceNode._spot_taken()`). Грядку убирает `GardenBed.remove_bed()` (круг действий).
- **Модели инструментов** — `tools/blender/models_tools.py` (хват в нуле, рукоять вниз по −Z, рабочая сторона — +Y).
  Как их держат — `Player.CARRY_*` (перед собой, вперёд-вверх) и замахи в `Player._work_pose()`. Автотест `_test_tool_clip()`
  меряет, не входит ли инструмент в голову, туловище и ноги (несёт, идёт, весь замах); быстро — `--autotest --cliponly`.
- **Звуки событий** (подобрал, урожай, крафт, стройка, монеты, кнопки, задание…) — `tools/gen_audio.py`, раздел `COZY`:
  калимба и дерево в до мажоре, всё выше ~4.5 кГц срезано, громкость через `level()`. Пересобрать только их:
  `python tools/gen_audio.py pickup harvest craft …`. У звуков с нотами высоту не качаем — `Audio.TONAL`.
- **Преграды:** густая трава (`ResourceNode.SOFT`) — слой 8, замедляет (`Player.in_grass`); над преградами с инструментом —
  невидимая «крышка» (`CAP_LAYER` = 32), чтобы на них не запрыгивали.
- **Мелкая трава** — `scripts/grass_field.gd` (`GrassField`, `Island.grass_field`): слои Grass/Flowers/Clover кусками 10 м,
  клетки 1 × 1 м; `clear_at(p, r)` — расчистить (сохраняется в `Game.grass`, битовая карта base64 на остров), маска `clear_mask`
  в `terrain.gdshader` — ровный газон. Цель героя — `GrassField.Spot`. Постройка расчищает траву под собой (`BuildSystem`).
- **Столкновения по модели** — `Models.add_trimesh(body, visual)` (листва, огонь, плоды пропускаются; масштаб запекается).
  Подключено к постройкам, сюжетным местам и особым местам. Проверка `--colcheck --location=…` (0 дыр на всех островах);
  нарочно проходимое — в `COLCHECK_OK` в `dev_tools.gd` с причиной.
- **Культуры** — модели `crop_<вид>`: растения-узлы `P0..P8`, в каждом `P<n>_leaf`, `P<n>_stem`, плоды `P<n>_fruit<k>` (точка вращения
  в центре плода). `GardenBed._grow_visual()` растит их плавно по `progress`; у деревьев узел `Fruit` с плодами `Fruit_<k>`
  (`FruitTree._grow_visual()`). Стадии `stage()` для заданий не менялись.
- **Новые растения** — `tools/blender/models_flora.py`, вид в `ResourceNode.KINDS`, расстановка — `Island._spawn_flora()` со своим
  случайным рядом (номера прежних преград не сдвигаются). Кусты под мачете и деревца под топор — только дальше 17 м от лагеря.
- **Текстуры моделей** (люди, животные, птицы, одежда `wear_*` — список `TEXTURED` в `build.py`): `tools/blender/texbake.py`
  запекает раскраску в атлас (UV smart project, 256–1024 px). `kit.paint` запоминает программу раскраски (`kit.PAINTS`, атрибуты
  `pid`/`p0`/`n0`), и `fn(co, n)` считается в каждом пикселе — границы чёткие. Перекраска собранного тела — `kit.overpaint(ob, fn)`,
  не писать `color_srgb` напрямую. Вид поверхности для мелкой детали — `paint(..., mat="hair"|"beard"|"stubble"|"cloth"|"skin"|"fur"|
  "wool"|"feather"|"hide"|"smooth"|"clean")`, у животных по умолчанию — `SKIN_KIND`. Godot извлекает текстуру в
  `assets/models/<имя>_<имя>_albedo.png` (+ `.import` со сжатием S3TC — `build.py` ставит его сам, затем ещё раз `--import`) — коммитить вместе с `.glb`. В игре — `Models.tex_mat()`
  (`use_albedo_tex`, `terminator_soft`); модели без текстуры — как раньше, цвет вершин.
- **Текстуры построек и лодок** (v1.0.7, списки `BUILDINGS` и `BOATS` в `build.py`, семейство `"build"`): деталь — `texbake.detail_build`,
  виды `paint(..., mat="wood"|"painted"|"planked"|"bark"|"endgrain"|"bamboo"|"straw"|"hay"|"stone"|"brick"|"clay"|"metal"|"iron"|"rust"|
  "plate"|"rope"|"canvas"|"soil"|"leaf"|"plain")`; без `mat=` — по цвету (`texbake.KNOWN`), проверить: `build.py --kinds <имена>`.
  Направление волокон — атрибут `u0` от `kit.tube`/`lathe`/`cyl`, у ящиков — оси формы. Размер атласа — по площади (512/1024),
  свой — `TEX_SIZE`. Узоры для текстур пишите без полос «через одну» и `sin`-полос пятнами (станут «зеброй»): обшивка — `boards()`,
  кладка — `masonry()` (`models_buildings.py`), пятна (ржавчина, мох) — по шуму `mathutils.noise`.
- **Текстуры растений и деревьев** (v1.0.8, список `PLANTS` в `build.py`, семейство `"plant"`): деталь — `texbake.detail_plant`
  (виды построек вроде `bark`, `wood`, `soil` рисует `detail_build`). Виды `paint(..., mat="leaf"|"leaf_matte"|"banana"|"aloe"|"grass"|
  "petal"|"foliage"|"stem"|"sheath"|"vine"|"palm"|"birch"|"pinebark"|"needle"|"charred"|"moss"|"bloom"|"fruit"|"husk"|"root"|"velvet"|
  "cabbage")`; без `mat=` — по цвету и форме (`guess_plant`: лист `kit.leaf` → `leaf`/`grass`, трубка → `stem`/`bark`, «шар» →
  `foliage`/`fruit`). `kit.leaf` пишет координаты листа (атрибуты `lf0`/`lf1`) — по ним жилки, край и блик. Кроны — «чешуйками»
  (`texbake._scales`, ячейки Вороного `worley`). Клевер (`clover_tuft`, MultiMesh травы) — на цвете вершин. Плоды на грядках
  и деревьях подкрашивает копия их же материала — `Models.tint_mat(mi)` (не `model_mat`: у запечённых нет цвета вершин).
- **Живость моделей:** складки ткани, пряди, шерсть у запечённых моделей рисует `texbake.detail` (по пикселям). Прежние
  `kit.liven` / `kit.liven_fur` (то же по вершинам) остались в `kit.py` для моделей на цвете вершин, `build.py` их больше не зовёт.
  Общие помощники дерева: `kit.bark_trunk`, `wood_cap` (торец с кольцами), `splinters`, `bark_fn`, `smooth_path`; `log()`/`plank()`
  в `models_buildings.py`. `kit.set_parent` пересчитывает матрицы — у свежих пустышек дети больше не «улетают».
- **Сохранение:** версия `SAVE_VERSION` в `game.gd`. Новые флаги для старых сохранений — через миграцию в `load_game`.
  Ячейки: `Game.SLOTS`, `slot_path(n)`, `use_slot(n)`, `slot_info(n)`; ячейка 1 — прежний `save.json`, у тестов свои `save_dev*.json`.

## Команды
Godot должен быть в PATH как `godot`; на Windows — консольная версия `Godot_v4.7.x-stable_win64_console.exe`.

Окно игры для тестов и скриншотов — на втором мониторе и без звука: `--screen 1 --audio-driver Dummy`.
Автотесты и проверка пишут в своё сохранение (`user://save_dev.json`) и не трогают сохранение игрока.
`--autotest ... --walk` — вся глава ногами: перед каждым пунктом задания герой сам идёт к цели по навигационной сетке
с настоящей физикой (заросли рубит, только если инструмент уже можно сделать; лезет и спускается по лианам и стенам,
спрыгивает с высоты, пользуется люком бункера). Медленно: глава — 5–15 минут. Где не дошёл — FAIL «ногами: …».
`--walktest` — проверка ногами, с настоящей физикой: маршруты по острову (форт — через ворота и подвал), ярусы бункера
(герой стоит на полу). Автотест переносит героя напрямую и такие ошибки не видит. `--scan=N` — грубый поиск тупиков.

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
godot --headless --path . -- --autotest --location=eye --chapter=8 --walk
godot --headless --path . -- --walktest --location=fort
godot --headless --path . -- --colcheck --location=storm
godot --headless --path . -- --walktest --location=storm
godot --path . --resolution 1600x900 -- --shot=shot.png --frames=90 --location=fort
```

Скриншот в Forward+ без видеокарты (облако): поставить `mesa-vulkan-drivers` и запускать так:
```bash
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver vulkan --resolution 1600x900 -- --shot=shot.png --frames=60 --nohud --demo
```

Полезные аргументы для `dev_tools`:
- `--time=0..1` — время суток (0.255 рассвет, 0.5 полдень, 0.74 закат, 0.78 сумерки, 0.95 ночь); `--moon=0..1` — фаза луны;
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
- `--quest=old_camp` — текущее задание по id; `--give=stone_axe,machete` — выдать предметы; `--hold=stone_axe` — инструмент в руке;
- `--pose=stone_axe:0.32` — застывшая поза работы (фаза 0..1), `--face=0` — куда смотрит герой (с `--yaw=1.57` — вид сбоку);
- `--fxtest` — все эффекты перед кадром;
- `--climb=N:h` — герой на лиане N на высоте h (0..1); `--slots=load|new|save|pauseload` — список ячеек сохранения;
- `--toolrow --nohud` — все инструменты в ряд; `--sat=35` — сытость; `--worn=machete:0.7` — износ инструмента;
- `--demo --wheel=pen|bed|seeds` — круг действий; `--panel=build|craft|inv` — окно (всё открыто); `--farline=marta` — реплика издалека;
- `--dbgdraw=1|2|5|12` — без света / только свет / нормали / SSAO;
- `--gallery=a,b --gpitch=0.3 --dist= --camy=` — модели в ряд своей камерой; `--growrow=tomato,corn` — грядки и деревья на разных стадиях;
  `--mow=5` — расчистить траву вокруг героя;
- `--bench=600` — замер скорости: после прогрева (`--benchfrom=120`) 600 кадров без вертикальной синхронизации, печать `BENCH …`
  (время кадра, 95-й процентиль, FPS, время на видеокарте, вызовы отрисовки) и выход.

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
