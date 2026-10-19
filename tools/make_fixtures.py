"""Generates the PDF fixtures used by the GUT tests (tests/fixtures/).

Run: python -m pip install -r tools/requirements.txt && python tools/make_fixtures.py
Coordinates written to the .json sidecars are PDF points, origin top-left, y down.
"""
import io
import json
import random
import shutil
from pathlib import Path

from PIL import Image, ImageDraw
from pypdf import PdfReader, PdfWriter
from reportlab.lib.pagesizes import A4, letter, landscape
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas

OUT = Path(__file__).resolve().parent.parent / "tests" / "fixtures"
LETTER_W, LETTER_H = letter
BUBBLE_R = 7.0  # 14 pt diameter


def make_mc_letter(path: Path) -> dict:
    c = canvas.Canvas(str(path), pagesize=letter)
    c.setTitle("Fixture Test")
    bubbles = []
    for page in range(2):
        c.setFont("Helvetica-Bold", 14)
        c.drawString(72, LETTER_H - 50, f"Fixture Test - page {page + 1}")
        for q in range(10):
            top = 80 + q * 66
            n = page * 10 + q + 1
            c.setFont("Helvetica", 11)
            c.drawString(72, LETTER_H - top - 11, f"{n}. Which of the following is correct for item {n}?")
            for j, letter_ch in enumerate("ABCD"):
                cx = 100 + j * 50
                cy_top = top + 30
                c.circle(cx, LETTER_H - cy_top, BUBBLE_R, stroke=1, fill=0)
                c.setFont("Helvetica", 8)
                c.drawCentredString(cx, LETTER_H - cy_top - 2.8, letter_ch)
                bubbles.append({"page": page, "question": n, "choice": letter_ch, "center": [cx, cy_top], "r": BUBBLE_R})
        c.showPage()
    c.save()
    return {"bubbles": bubbles}


def make_mixed_sizes(path: Path) -> None:
    c = canvas.Canvas(str(path))
    for size in (A4, letter, landscape(letter)):
        c.setPageSize(size)
        w, h = size
        c.setLineWidth(1)
        c.rect(36, 36, w - 72, h - 72, stroke=1, fill=0)
        c.setFont("Helvetica", 12)
        c.drawString(60, h - 70, f"Page size {w:.2f} x {h:.2f}")
        c.showPage()
    c.save()


def make_scanned(path: Path) -> dict:
    rnd = random.Random(4)
    scale = 2  # 144 DPI image
    w, h = int(LETTER_W * scale), int(LETTER_H * scale)
    img = Image.new("L", (w, h), 245)
    px = img.load()
    for _ in range(w * h // 40):
        x, y = rnd.randrange(w), rnd.randrange(h)
        px[x, y] = rnd.randint(200, 240)
    d = ImageDraw.Draw(img)
    circles = []
    for j in range(4):
        cx, cy = 120 + j * 50, 200
        r = 8
        d.ellipse([(cx - r) * scale, (cy - r) * scale, (cx + r) * scale, (cy + r) * scale], outline=40, width=3)
        circles.append({"center": [cx, cy], "r": r})
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)
    c = canvas.Canvas(str(path), pagesize=letter)
    c.drawImage(ImageReader(buf), 0, 0, width=LETTER_W, height=LETTER_H)
    c.showPage()
    c.save()
    return {"circles": circles}


def make_big(path: Path, pages: int = 120) -> None:
    c = canvas.Canvas(str(path), pagesize=letter)
    for i in range(pages):
        c.setFont("Helvetica", 24)
        c.drawString(72, LETTER_H - 100, f"Page {i + 1}")
        c.showPage()
    c.save()


def make_encrypted(src: Path, path: Path) -> None:
    w = PdfWriter(clone_from=PdfReader(str(src)))
    w.encrypt(user_password="x", owner_password="owner-x")
    with open(path, "wb") as f:
        w.write(f)


def make_rotated(src: Path, path: Path) -> None:
    """Pages carrying /Rotate 90, 270 and 180 (common on scanned exams)."""
    w = PdfWriter()
    for i, angle in ((0, 90), (1, 270), (0, 180)):
        page = PdfReader(str(src)).pages[i]
        page.rotate(angle)
        w.add_page(page)
    with open(path, "wb") as f:
        w.write(f)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    mc = OUT / "mc_letter.pdf"
    (OUT / "mc_letter.json").write_text(json.dumps(make_mc_letter(mc), indent=1))
    make_mixed_sizes(OUT / "mixed_sizes.pdf")
    (OUT / "scanned.json").write_text(json.dumps(make_scanned(OUT / "scanned.pdf"), indent=1))
    make_big(OUT / "big_120.pdf")
    make_encrypted(mc, OUT / "encrypted.pdf")
    make_rotated(mc, OUT / "rotated.pdf")
    (OUT / "corrupt.pdf").write_bytes(mc.read_bytes()[:1000])
    uni = OUT / "unicode" / "Zoë Документы"
    uni.mkdir(parents=True, exist_ok=True)
    shutil.copy(mc, uni / "mc.pdf")
    print("fixtures written to", OUT)


if __name__ == "__main__":
    main()
