# Звуки: откуда взяты и под какой лицензией

Большинство звуков игры синтезировано скриптом `tools/gen_audio.py` (музыка, погода, эффекты) — они наши.
Часть звуков — готовые записи со свободной лицензией.

## Действия — наборы Kenney (CC0, общественное достояние)
Удары топора по дереву (`sfx_chop*`), кирки по камню (`sfx_rock*`), молот кузницы (`sfx_hammer*`),
металл (`sfx_metal*`), лёд (`sfx_ice*`), шаги по траве и снегу (`sfx_step_grass*`, `sfx_step_snow*`), скрип (`sfx_creak*`).
Источник: Kenney Vleugels, [kenney.nl](https://kenney.nl) — наборы «RPG Audio», «Impact Sounds».

Звуки событий — подбор, урожай, посадка, еда, крафт, стройка, монеты, кнопки, окна, задание, находка, полив, шорох
листвы — синтезированы (`tools/gen_audio.py`, раздел «мягкие звуки событий»).
Лицензия: [CC0 1.0](http://creativecommons.org/publicdomain/zero/1.0/). Импорт — `tools/import_sounds.py`.

## Голоса животных — Wikimedia Commons
Нарезаны из записей скриптом `tools/cut_animal_sounds.py` (загрузка — `tools/fetch_animal_sounds.py`).
Записи под лицензиями CC BY и CC BY-SA используются с указанием автора (ниже); изменения — нарезка и выравнивание громкости.

| Файл | Кто | Исходная запись | Автор | Лицензия |
|---|---|---|---|---|
| sfx_cluck0.wav | курица | [Hens leaving coop.ogg](https://commons.wikimedia.org/wiki/File:Hens_leaving_coop.ogg) | alys | Public domain |
| sfx_cluck1.wav | курица | [Hen announcing shes lain an egg.ogg](https://commons.wikimedia.org/wiki/File:Hen_announcing_shes_lain_an_egg.ogg) | alys | Public domain |
| sfx_cluck2.wav | курица | [Hens leaving coop.ogg](https://commons.wikimedia.org/wiki/File:Hens_leaving_coop.ogg) | alys | Public domain |
| sfx_cluck3.wav | курица | [Chickens demanding food.ogg](https://commons.wikimedia.org/wiki/File:Chickens_demanding_food.ogg) | alys | Public domain |
| sfx_honk0.wav | гусь | [Geese Honking (loud).ogg](https://commons.wikimedia.org/wiki/File:Geese_Honking_(loud).ogg) | U.S. Fish and Wildlife Service | Public domain |
| sfx_honk1.wav | гусь | [Geese Honking (loud).ogg](https://commons.wikimedia.org/wiki/File:Geese_Honking_(loud).ogg) | U.S. Fish and Wildlife Service | Public domain |
| sfx_honk2.wav | гусь | [Geese Honking (loud).ogg](https://commons.wikimedia.org/wiki/File:Geese_Honking_(loud).ogg) | U.S. Fish and Wildlife Service | Public domain |
| sfx_baa0.wav | овца | [Sheep bleat.ogg](https://commons.wikimedia.org/wiki/File:Sheep_bleat.ogg) | Eviatar Bach | CC0 |
| sfx_baa1.wav | овца | [Sheep bleating.ogg](https://commons.wikimedia.org/wiki/File:Sheep_bleating.ogg) | earthcalling | Public domain |
| sfx_baa2.wav | овца | [Sheep bleating.ogg](https://commons.wikimedia.org/wiki/File:Sheep_bleating.ogg) | earthcalling | Public domain |
| sfx_bleat0.wav | коза | [Herd of goats bleating.ogg](https://commons.wikimedia.org/wiki/File:Herd_of_goats_bleating.ogg) | stephan | Public domain |
| sfx_bleat1.wav | коза | [Herd of goats bleating.ogg](https://commons.wikimedia.org/wiki/File:Herd_of_goats_bleating.ogg) | stephan | Public domain |
| sfx_bleat2.wav | коза | [Herd of goats bleating.ogg](https://commons.wikimedia.org/wiki/File:Herd_of_goats_bleating.ogg) | stephan | Public domain |
| sfx_oink0.wav | свинья | [Mudchute pig 2.ogg](https://commons.wikimedia.org/wiki/File:Mudchute_pig_2.ogg) | Secretlondon | CC BY-SA 3.0 |
| sfx_oink1.wav | свинья | [Mudchute pig 1.ogg](https://commons.wikimedia.org/wiki/File:Mudchute_pig_1.ogg) | Secretlondon | CC BY-SA 3.0 |
| sfx_oink2.wav | свинья | [Pig grunt - Erdie.ogg](https://commons.wikimedia.org/wiki/File:Pig_grunt_-_Erdie.ogg) | erdie | CC BY 3.0 |
| sfx_oink3.wav | свинья | [Pig grunt - Erdie.ogg](https://commons.wikimedia.org/wiki/File:Pig_grunt_-_Erdie.ogg) | erdie | CC BY 3.0 |
| sfx_penguin0.wav | пингвины | [20091121 Little Penguin calls at St Kilda Breakwater.ogg](https://commons.wikimedia.org/wiki/File:20091121_Little_Penguin_calls_at_St_Kilda_Breakwater.ogg) | Mikeybear | CC BY 3.0 |
| sfx_penguin1.wav | пингвины | [20091121 Little Penguin calls at St Kilda Breakwater.ogg](https://commons.wikimedia.org/wiki/File:20091121_Little_Penguin_calls_at_St_Kilda_Breakwater.ogg) | Mikeybear | CC BY 3.0 |
| sfx_penguin2.wav | пингвины | [20091121 Little Penguin calls at St Kilda Breakwater.ogg](https://commons.wikimedia.org/wiki/File:20091121_Little_Penguin_calls_at_St_Kilda_Breakwater.ogg) | Mikeybear | CC BY 3.0 |
| sfx_snore0.wav | морж | [Walrus sound effect.wav](https://commons.wikimedia.org/wiki/File:Walrus_sound_effect.wav) | Zagzav12 | CC0 |
| sfx_snore1.wav | морж | [Walrus sound effect.wav](https://commons.wikimedia.org/wiki/File:Walrus_sound_effect.wav) | Zagzav12 | CC0 |
