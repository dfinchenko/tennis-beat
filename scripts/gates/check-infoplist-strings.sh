#!/usr/bin/env bash
# Gate: InfoPlist.xcstrings is the single source of truth for Info.plist permission texts.
# Info.plist needs an English value at build time (INFOPLIST_KEY_* build settings); this gate
# fails if any of those values differs from the EN source string in the target's catalog,
# or if a catalog key lacks a PL or UK translation.
# Usage: scripts/gates/check-infoplist-strings.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
python3 - <<'PY'
import json, re, sys
pbx = open("TennisBeat/TennisBeat.xcodeproj/project.pbxproj", encoding="utf-8").read()
targets = {
    "TennisBeat/TennisBeat/InfoPlist.xcstrings": "TennisBeat/TennisBeat.entitlements",
    "TennisBeat/TennisBeat Watch App/InfoPlist.xcstrings": "TennisBeat Watch App/TennisBeat Watch App.entitlements",
}
# Split the pbxproj into build-configuration blocks and attribute each to a target by its entitlements path.
blocks = re.findall(r"isa = XCBuildConfiguration;.*?name = \w+;", pbx, re.S)
fail = False
for catalog, marker in targets.items():
    strings = json.load(open(catalog, encoding="utf-8"))["strings"]
    configs = [b for b in blocks if marker in b]
    if not configs:
        print(f"GATE FAIL: no build configurations found for {catalog}", file=sys.stderr); fail = True
    for key, entry in strings.items():
        locs = entry.get("localizations", {})
        for lang in ("en", "pl", "uk"):
            if not locs.get(lang, {}).get("stringUnit", {}).get("value"):
                print(f"GATE FAIL: {catalog}: {key} has no {lang} value", file=sys.stderr); fail = True
        en = locs.get("en", {}).get("stringUnit", {}).get("value")
        for b in configs:
            m = re.search(rf'INFOPLIST_KEY_{key} = (".*?(?<!\\)"|[^;]*);', b)
            got = None if not m else m.group(1).strip('"').replace('\\"', '"')
            if got != en:
                print(f"GATE FAIL: INFOPLIST_KEY_{key} in {marker} config is {got!r}, catalog EN is {en!r}", file=sys.stderr); fail = True
sys.exit(1 if fail else 0)
PY
echo "GATE PASS: Info.plist strings match InfoPlist.xcstrings"
