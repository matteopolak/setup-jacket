#!/usr/bin/env bash
# Downloads, verifies and unpacks the release into $DIR unless the cache already holds it.
set -euo pipefail
REPO=matteopolak/jacket

if [ -f "$DIR/$ROOT/.setup-jacket-complete" ]; then
  echo "Using the cached toolchain in $DIR"
  exit 0
fi

base="https://github.com/$REPO/releases/download/v$VERSION"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
dl() { curl -fsSL --retry 3 --proto '=https' --tlsv1.2 -o "$2" "$1"; }

dl "$base/SHA256SUMS" "$tmp/SHA256SUMS" || { echo "::error::could not download $base/SHA256SUMS (is v$VERSION a release of $REPO?)" >&2; exit 1; }
expected="$(awk -v f="$ARCHIVE" '$2 == f || $2 == "*" f { print $1 }' "$tmp/SHA256SUMS")"
if [ -z "$expected" ]; then
  echo "::error::Jai $VERSION has no $ARCHIVE; it publishes no build for $PLATFORM. Use a later version." >&2
  exit 1
fi
dl "$base/$ARCHIVE" "$tmp/$ARCHIVE" || { echo "::error::could not download $base/$ARCHIVE" >&2; exit 1; }
if command -v sha256sum > /dev/null; then actual="$(sha256sum "$tmp/$ARCHIVE" | awk '{print $1}')"
else actual="$(shasum -a 256 "$tmp/$ARCHIVE" | awk '{print $1}')"; fi
if [ "$(printf '%s' "$actual" | tr A-F a-f)" != "$(printf '%s' "$expected" | tr A-F a-f)" ]; then
  echo "::error::checksum mismatch for $ARCHIVE: expected $expected, got $actual" >&2
  exit 1
fi
echo "Verified SHA-256 $actual"

mkdir -p "$tmp/unpack"
case "$ARCHIVE" in
  *.zip)
    if command -v 7z > /dev/null; then 7z x -y -o"$tmp/unpack" "$tmp/$ARCHIVE" > /dev/null
    else powershell.exe -NoProfile -Command "Expand-Archive -LiteralPath '$(cygpath -w "$tmp/$ARCHIVE")' -DestinationPath '$(cygpath -w "$tmp/unpack")' -Force"; fi ;;
  *) tar -xzf "$tmp/$ARCHIVE" -C "$tmp/unpack" ;;
esac
[ -d "$tmp/unpack/$ROOT/stdlib" ] || { echo "::error::$ARCHIVE does not contain $ROOT/stdlib" >&2; exit 1; }

rm -rf "$DIR"
mkdir -p "$DIR"
mv "$tmp/unpack/$ROOT" "$DIR/$ROOT"
touch "$DIR/$ROOT/.setup-jacket-complete"
echo "Installed Jai $VERSION in $DIR/$ROOT"
