#!/usr/bin/env bash

set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d)
output="$scratch/output"
runtime="$scratch/runtime"
trap 'rm -rf -- "$scratch"' EXIT
mkdir -m 700 "$runtime"
mkdir -m 700 "$scratch/home"
mkdir -p "$scratch/home/.config/omarchy/password-store"
printf 'sentinel\n' >"$scratch/sentinel"
ln -s "$scratch/sentinel" "$scratch/home/.config/omarchy/password-store/config.json"
cp "$repo/Service.qml" "$repo/Config.js" "$repo/BoundedRead.pl" \
  "$repo/AtomicWrite.pl" \
  "$repo/tests/service-state.qml" "$scratch/"

if ! env -u DISPLAY -u WAYLAND_DISPLAY \
    HOME="$scratch/home" XDG_RUNTIME_DIR="$runtime" \
    XDG_CACHE_HOME="$scratch/cache" XDG_STATE_HOME="$scratch/state" \
    QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME= \
    timeout 8 qs --no-color -p "$scratch/service-state.qml" \
    >"$output" 2>&1; then
  sed -n '1,240p' "$output" >&2
  exit 1
fi

if grep -F "service state test failed:" "$output" >&2; then
  exit 1
fi
grep -F "service state transition checks passed" "$output" >/dev/null || {
  sed -n '1,240p' "$output" >&2
  exit 1
}
[[ ! -L $scratch/home/.config/omarchy/password-store/config.json ]]
[[ $(<"$scratch/sentinel") == sentinel ]]
jq -e '
  .primaryVault == "vaultwarden"
  and .vaultUrl == "https://vault.recovered.example"
  and .browser == ""
' "$scratch/home/.config/omarchy/password-store/config.json" >/dev/null
printf 'service state transition checks passed\n'
