#!/usr/bin/env bash
# Downloads the pinned PDFium-GDE release into addons/pdfium-gde (binaries are not committed).
set -euo pipefail
VERSION="v1.1"
SHA256="5111197f8d6726610348c25dfdcd733a04d1d47458627890552f4de97da63778"
cd "$(dirname "$0")/.."
if [ -f addons/pdfium-gde/.version ] && [ "$(cat addons/pdfium-gde/.version)" = "$VERSION" ]; then
  echo "PDFium-GDE $VERSION already present"; exit 0
fi
tmp="$(mktemp -d)"
curl -sSL -o "$tmp/p.zip" "https://github.com/aliarcanakgun/pdfium-gde/releases/download/$VERSION/pdfium-gde-$VERSION.zip"
echo "$SHA256  $tmp/p.zip" | sha256sum -c -
rm -rf addons/pdfium-gde
unzip -q "$tmp/p.zip" -d "$tmp/x"
mv "$tmp/x/addons/pdfium-gde" addons/pdfium-gde
# The editor and tests load the extension in place, so the PDFium library must sit next to it.
cp addons/pdfium-gde/windows/x86_64/pdfium.dll addons/pdfium-gde/windows/pdfium.dll
cp addons/pdfium-gde/linux/x86_64/libpdfium.so addons/pdfium-gde/linux/libpdfium.so
echo "$VERSION" > addons/pdfium-gde/.version
rm -rf "$tmp"
echo "PDFium-GDE $VERSION installed"
