#!/usr/bin/env bash
# Works out the version, platform and archive name; writes them to $GITHUB_OUTPUT.
set -euo pipefail
REPO=matteopolak/jacket

case "${RUNNER_OS:-}/${RUNNER_ARCH:-}" in
  Linux/X64) platform=linux-x64 ;;
  Linux/ARM64) platform=linux-arm64 ;;
  macOS/ARM64) platform=macos-arm64 ;;
  macOS/X64) platform=macos-x64 ;;
  Windows/X64) platform=windows-x64 ;;
  Windows/ARM64) platform=windows-arm64 ;;
  *) echo "::error::setup-jacket does not support ${RUNNER_OS:-unknown}/${RUNNER_ARCH:-unknown}. Supported: Linux x64/arm64, macOS arm64/x64, Windows x64/arm64." >&2; exit 1 ;;
esac

version="${INPUT_VERSION:-latest}"
version="${version#v}"
if [ -z "$version" ] || [ "$version" = latest ]; then
  tag=""
  if body="$(curl -fsSL --retry 3 -H "Authorization: Bearer ${GH_TOKEN:-}" -H 'Accept: application/vnd.github+json' \
      "https://api.github.com/repos/$REPO/releases/latest" 2> /dev/null)"; then
    tag="$(printf '%s' "$body" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
  fi
  if [ -z "$tag" ]; then # API unavailable or rate limited: the redirect needs no quota
    url="$(curl -fsSL --retry 3 -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest")"
    tag="${url##*/}"
  fi
  version="${tag#v}"
fi
case "$version" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "::error::version '$version' is not 'latest' or a version like 0.18.0" >&2; exit 1 ;;
esac
case "$version" in *[!0-9A-Za-z.+-]*) echo "::error::invalid version '$version'" >&2; exit 1 ;; esac

ext=tar.gz
case "$platform" in windows-*) ext=zip ;; esac
temp="${RUNNER_TOOL_CACHE:-${RUNNER_TEMP:-/tmp}}"
{
  echo "version=$version"
  echo "platform=$platform"
  echo "root=jacket-$platform"
  echo "archive=jacket-$platform.$ext"
  echo "dir=$temp/setup-jacket/$version/$platform"
} >> "$GITHUB_OUTPUT"
echo "Resolved Jacket $version for $platform"
