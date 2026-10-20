# Credits

Pencils Down only includes assets under CC0, CC-BY or the SIL Open Font License.

## Fonts (SIL Open Font License 1.1)

License texts are in `assets/fonts/OFL-<family>.txt`.

| Font | Use | Source |
|---|---|---|
| Caveat | handwriting | https://fonts.google.com/specimen/Caveat |
| Kalam | handwriting | https://fonts.google.com/specimen/Kalam |
| Patrick Hand | handwriting | https://fonts.google.com/specimen/Patrick+Hand |
| Shadows Into Light | handwriting | https://fonts.google.com/specimen/Shadows+Into+Light |
| Indie Flower | handwriting | https://fonts.google.com/specimen/Indie+Flower |
| Fraunces | UI headings | https://fonts.google.com/specimen/Fraunces |
| Atkinson Hyperlegible | UI body | https://fonts.google.com/specimen/Atkinson+Hyperlegible |
| Noto Sans | fallback glyphs | https://fonts.google.com/noto/specimen/Noto+Sans |
| Noto Sans Math | fallback math symbols | https://fonts.google.com/noto/specimen/Noto+Sans+Math |

## Libraries

| Library | License | Source |
|---|---|---|
| PDFium-GDE | Zlib | https://github.com/aliarcanakgun/pdfium-gde |
| PDFium | Apache-2.0 | https://pdfium.googlesource.com/pdfium/ |
| GUT (Godot Unit Test) | MIT | https://github.com/bitwes/Gut |

## Sounds

| Sound | License | Source |
|---|---|---|
| Start and end bells (placeholder) | CC0 | Synthesized by `tools/make_bells.py` |

## 3D models, textures and lighting (CC0)

Poly Haven assets are downloaded at build time by `tools/fetch_assets.py` (pinned URLs and checksums in `tools/asset_manifest.json`) into `assets/third_party/polyhaven/`, which isn't committed. All are CC0 from https://polyhaven.com.

| Asset | Use |
|---|---|
| School Desk 01, School Chair 01 | student desks and chairs |
| Metal Office Desk, Modern Arm Chair 01 | teacher's desk and chair |
| Drawer Cabinet, Steel Frame Shelves 03, Book Encyclopedia Set 01, Binder Notebook, Clipboard, Stationery Supplies | back-wall storage and desk props |
| Potted Plant 01 | window sill and back corner |
| Fire Alarm | wall fixture |
| Cotton Jersey, Denim Fabric, Knitted Fleece | classmates' clothing detail |
| Plastered Wall 04 | door surface grain |
| Autumn Park (HDRI) | the view outside the windows and sky light |

| Asset | License | Source | Use |
|---|---|---|---|
| Universal Base Characters (Superhero Male/Female, Buns, Long, Simple Parted and Buzzed hair) by Quaternius | CC0 | https://quaternius.itch.io/universal-base-characters | seated classmates (committed in `assets/third_party/quaternius/`, textures downscaled to 1024 px; license in `LICENSE-Quaternius.txt`) |

Generated in code, with no texture asset: the paper fibre (`scenes/packet/paper_page.gdshader`), the cinderblock walls, vinyl floor tiles and acoustic ceiling tiles (`scenes/environments/morning_classroom/*.gdshader`), the digital clock's seven-segment digits and the bulletin-board posters.

## Development tools (not shipped)

| Tool | License | Use |
|---|---|---|
| reportlab, pypdf, Pillow | BSD / BSD / HPND | generating the test-fixture PDFs |
