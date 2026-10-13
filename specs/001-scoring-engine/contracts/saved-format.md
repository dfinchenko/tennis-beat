# Contract: saved match format (formatVersion 1)

The engine owns this format (spec Overview, FR-031, FR-032). The apps store and transfer these bytes as an opaque value. They never build or edit them by hand.

## Envelope

```json
{
  "formatVersion": 1,
  "events": [
    { "type": "setup",
      "format": { "matchLength": "bestOfThree", "setLength": 6,
                  "gameScoring": "advantage", "matchTieBreak": true },
      "firstServer": "me" },
    { "type": "point", "winner": "me", "recordedAt": 813592800.125 },
    { "type": "point", "winner": "opponent", "recordedAt": 813592831.5 },
    { "type": "firstServerCorrected", "firstServer": "opponent" },
    { "type": "matchEndedEarly" }
  ]
}
```

| Key | Type | Values |
| --- | --- | --- |
| `formatVersion` | integer | `1` for this version |
| `events[].type` | string | `setup`, `point`, `matchEndedEarly`, `firstServerCorrected` |
| `format.matchLength` | string | `oneSet`, `bestOfThree` |
| `format.setLength` | integer | `4`, `6`, `8` |
| `format.gameScoring` | string | `advantage`, `noAd` |
| `format.matchTieBreak` | boolean | `true` only with `bestOfThree` |
| `firstServer`, `winner` | string | `me`, `opponent` |
| `recordedAt` | number | `Date.timeIntervalSinceReferenceDate`: seconds since 2001-01-01T00:00:00Z, as a `Double`, round-tripped bit-exactly |

The encoder writes keys in a fixed order (`.sortedKeys`), so equal matches encode to equal bytes. Unknown keys are ignored. An unknown `type` makes the list `.malformed`.

## Restore algorithm

1. Decode `{ formatVersion }` only. If it is missing, not an integer, or < 1 → `.malformed`.
2. If `formatVersion` > `MatchCodec.currentFormatVersion` → `.unsupportedVersion(found:supported:)`. Nothing else is parsed (US3 s14).
3. Apply the migrations `vK → vK+1` in order up to the current version. None exist for v1.
4. Decode the events. A structural failure → `.malformed`. A set length outside {4, 6, 8}, or `matchTieBreak` with `oneSet` → `.invalid(.invalidFormat)`.
5. `Match(events:)` validates the order and the rules → `.invalid(MatchError)` on the first rejected event.

## Versioning rules

- Any change to this layout bumps `formatVersion` and adds a migration from the previous version.
- Each released version has a frozen fixture, `Tests/TennisCoreTests/Fixtures/saved-format/vN.json`, plus a test that restores it and checks its expected state (US3 s13). Fixtures are never edited after release.
