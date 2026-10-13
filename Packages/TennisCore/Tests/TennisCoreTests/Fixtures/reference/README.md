# Reference matches (SC-005)

Each `*.json` file here is one match whose stats were counted **by hand**, never by a script or the app. `ReferenceMatchTests` replays every file except the template and compares the engine's stats with the hand count.

## Fields
- `origin`: `"agent-built"` or `"hand-scored (Denys)"`. Agent-built files have a `<name>.counting.md` table with the count, game by game.
- `format`: `matchLength` (`oneSet` or `bestOfThree`), `setLength` (4, 6 or 8), `gameScoring` (`advantage` or `noAd`), `matchTieBreak` (`true` only with `bestOfThree`).
- `firstServer`: `me` or `opponent`.
- `sets`: one entry per set, in play order. `games` holds one string per game: `M` = I won the point, `O` = the opponent won it. A tie-break, or the match tie-break, is one string.
- `expectedStats`: for each player, pairs `[won, of]`:
  - `pointsWonOnServe`, `pointsWonOnReturn`: every point, tie-break points included;
  - `serviceGamesHeld`: completed standard games served (tie-breaks excluded);
  - `breakPointsConverted`: as the receiver, converted / opportunities;
  - `breakPointsSaved`: as the server, saved / faced. A break point is a standard-game point the receiver wins the game with if they win it (30–40, 15–40, 0–40, the receiver's advantage, the No-Ad deciding point). Tie-break points are never break points.

Because each game is its own string, the test also checks that every game ends exactly at the last point of its string, so a miscounted game shows up as a boundary error, not only as a wrong total.

## Hand-scored match (T050, Denys)
Copy `hand-scored-denys.template.json` to `hand-scored-denys.json`, fill it in after a real match, count the stats by hand (not with the app), and remove nothing else. Until that file exists, the hand-scored SC-005 test is skipped and SC-005 is not claimed.
