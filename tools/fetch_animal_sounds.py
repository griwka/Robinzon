"""Скачать записи животных с Wikimedia Commons (только свободные лицензии) и записать, откуда и под какой лицензией."""
import json
import os
import sys
import time
import urllib.parse
import urllib.request

OUT = sys.argv[1]
TITLES = sys.argv[2:]
UA = {"User-Agent": "IslandGameDev/1.0 (indie game sound research)"}
os.makedirs(OUT, exist_ok=True)
meta = {}
mp = os.path.join(OUT, "meta.json")
if os.path.exists(mp):
    meta = json.load(open(mp, encoding="utf-8"))
for title in TITLES:
    if title in meta:
        continue
    q = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode({
        "action": "query", "titles": title, "prop": "imageinfo", "iiprop": "url|extmetadata",
        "iiextmetadatafilter": "LicenseShortName|Artist|LicenseUrl", "format": "json"})
    for attempt in range(4):
        try:
            d = json.load(urllib.request.urlopen(urllib.request.Request(q, headers=UA), timeout=30))
            break
        except Exception as e:
            print("retry", title, e)
            time.sleep(5 + attempt * 5)
    page = list(d["query"]["pages"].values())[0]
    ii = page["imageinfo"][0]
    m = ii.get("extmetadata", {})
    lic = m.get("LicenseShortName", {}).get("value", "?")
    artist = m.get("Artist", {}).get("value", "?")
    url = ii["url"]
    fname = "%02d_%s" % (len(meta), os.path.basename(urllib.parse.unquote(url.split("?")[0])))
    time.sleep(6)
    data = None
    for attempt in range(6):
        try:
            data = urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120).read()
            break
        except Exception as e:
            print("wait", title, e)
            time.sleep(30 + attempt * 30)
    if data is None:
        continue
    open(os.path.join(OUT, fname), "wb").write(data)
    meta[title] = {"file": fname, "license": lic, "artist": artist, "page": "https://commons.wikimedia.org/wiki/" + title.replace(" ", "_")}
    print(lic, "|", len(data), "|", fname)
    json.dump(meta, open(mp, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    time.sleep(8)
