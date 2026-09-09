#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
output=${1:?absolute empty output directory is required}
python3 "$root/.github/rpg-runtime/candidate_descriptor.py" prepare "$output"
mkdir -p "$root/.retrom-build"
work=$(mktemp -d "$root/.retrom-build/retrom-81-web.XXXXXX")
trap 'rm -rf "$work"' EXIT INT TERM
mkdir -p "$work/raw" "$work/build"
make -C "$root" -f Makefile.libretro platform=unix -j4 > "$work/native-build.log" 2>&1
python3 "$root/.github/rpg-runtime/test-controller-load.py" "$root/81_libretro.so"
python3 "$root/.github/rpg-runtime/test-controller-load.py" "$root/81_libretro.so" --no-bitmasks
source_digest=$(python3 "$root/.github/rpg-runtime/candidate_descriptor.py" digest "$output")
python3 "$root/.github/rpg-runtime/candidate_descriptor.py" paths "$output" > "$work/source-files"
tar -C "$root" --null --verbatim-files-from -T "$work/source-files" -cf "$work/source.tar"

export RETROM_HOST_UID="$(id -u)"
export RETROM_HOST_GID="$(id -g)"
if ! docker run --rm --platform linux/amd64 --hostname retrom-81 \
  --env RETROM_HOST_UID --env RETROM_HOST_GID \
  --volume "$work/source.tar:/source.tar:ro" \
  --volume "$root/.github/rpg-runtime:/recipe:ro" \
  --volume "$work/build:/work" \
  --volume "$work/raw:/output" \
  emscripten/emsdk@sha256:af45409f3199d88db4b1b03af0098532c8fb33a375ac257463eeb0a622870d06 \
  /recipe/build-emulatorjs-core.sh 81 \
  >"$work/build.log" 2>&1; then
  tail -200 "$work/build.log" >&2
  exit 1
fi

test "$source_digest" = "$(python3 "$root/.github/rpg-runtime/candidate_descriptor.py" digest "$output")"
stage="$work/stage"
mkdir -p "$stage"
install -m 0644 "$work/raw/81_libretro.js" "$stage/"
install -m 0644 "$work/raw/81_libretro.wasm" "$stage/"
install -m 0644 "$root/LICENSE" "$stage/license.txt"
printf '%s\n' '{"minimumEJSVersion":"4.2.2","version":"2.0.2"}' > "$stage/build.json"
printf '%s\n' '{"name":"81","extensions":["p","tzx","t81"],"makeoptions":{"buildpath":"./","makescript":"Makefile.libretro","arguments":[]},"options":{},"save":false,"license":"LICENSE","repo":"https://github.com/retrom-project/81-libretro"}' > "$stage/core.json"

(cd "$stage" && 7z a -mtm=off -mta=off -mtc=off -bd -bso0 -bsp0 -t7z "$output/81-wasm.data" \
  81_libretro.js 81_libretro.wasm build.json core.json license.txt)
install -m 0644 "$root/LICENSE" "$output/LICENSE"

gzip -n -c "$work/source.tar" > "$output/source.tar.gz"
