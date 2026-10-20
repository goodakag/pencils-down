"""Builds tools/asset_manifest.json from the Poly Haven API (all assets CC0).

Run only when changing the asset list; the manifest pins every file's URL and md5, and
tools/fetch_assets.py downloads exactly those files.
"""
import json
import pathlib
import urllib.request

MODELS = [
    "SchoolDesk_01", "SchoolChair_01", "metal_office_desk", "modern_arm_chair_01",
    "potted_plant_01", "book_encyclopedia_set_01", "binder_notebook", "stationery_supplies",
    "fire_alarm", "steel_frame_shelves_03", "clipboard",
    "drawer_cabinet",
]
TEXTURES = [
    "cotton_jersey", "denim_fabric", "knitted_fleece", "plastered_wall_04",
]
TEXTURE_MAPS = {"Diffuse": "diff", "nor_gl": "nor_gl", "arm": "arm", "Rough": "rough"}
HDRIS = {"autumn_park": "2k"}
RES = "1k"


def api(path: str) -> dict:
    req = urllib.request.Request("https://api.polyhaven.com/" + path, headers={"User-Agent": "pencils-down-build"})
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def main() -> None:
    files = []
    for m in MODELS:
        g = api("files/" + m)["gltf"][RES]["gltf"]
        base = f"models/{m}/"
        files.append({"dest": base + f"{m}.gltf", "url": g["url"], "md5": g["md5"]})
        for rel, f in g["include"].items():
            files.append({"dest": base + rel, "url": f["url"], "md5": f["md5"]})
    for t in TEXTURES:
        d = api("files/" + t)
        for key, short in TEXTURE_MAPS.items():
            if key in d and RES in d[key]:
                f = d[key][RES]["jpg"]
                files.append({"dest": f"textures/{t}/{t}_{short}.jpg", "url": f["url"], "md5": f["md5"]})
    for h, res in HDRIS.items():
        f = api("files/" + h)["hdri"][res]["hdr"]
        files.append({"dest": f"hdri/{h}.hdr", "url": f["url"], "md5": f["md5"]})
    out = pathlib.Path(__file__).with_name("asset_manifest.json")
    out.write_text(json.dumps({"source": "Poly Haven (CC0)", "files": files}, indent=1))
    print(f"{len(files)} files -> {out}")


if __name__ == "__main__":
    main()
