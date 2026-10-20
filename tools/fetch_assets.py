"""Downloads the pinned CC0 art (tools/asset_manifest.json) into assets/third_party/polyhaven.

The files are not committed because of their size. Each download is checked against its md5;
files already present with the right hash are skipped.
"""
import hashlib
import json
import pathlib
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEST = ROOT / "assets" / "third_party" / "polyhaven"


def md5(p: pathlib.Path) -> str:
    return hashlib.md5(p.read_bytes()).hexdigest()


def main() -> int:
    manifest = json.loads((ROOT / "tools" / "asset_manifest.json").read_text())
    fetched = 0
    for f in manifest["files"]:
        out = DEST / f["dest"]
        if out.exists() and md5(out) == f["md5"]:
            continue
        out.parent.mkdir(parents=True, exist_ok=True)
        req = urllib.request.Request(f["url"], headers={"User-Agent": "pencils-down-build"})
        with urllib.request.urlopen(req) as r:
            data = r.read()
        if hashlib.md5(data).hexdigest() != f["md5"]:
            print(f"checksum mismatch: {f['url']}", file=sys.stderr)
            return 1
        out.write_bytes(data)
        fetched += 1
    print(f"assets ready ({fetched} downloaded, {len(manifest['files']) - fetched} already present)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
