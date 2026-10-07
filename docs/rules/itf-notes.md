# ITF rules notes — scoring source of truth

Status: **Draft** overall. Denys approved the product decisions ST-04, ST-06, MT-02, EN-04 and BP-01..BP-03 on 2026-10-07; those entries are marked **Approved**. Rule entries stay Draft until Denys spot-checks them against the PDF.

## Source
- **Edition:** ITF *Rules of Tennis* 2026 (English). The © line says 2025, and the PDF was last modified on 2025-12-23. Changes to the rules take effect on 1 January of the following year.
- **URL:** https://www.itftennis.com/media/7221/2026-rules-of-tennis-english.pdf (linked from https://www.itftennis.com/en/about-us/governance/rules-and-regulations/)
- **Retrieved:** 2026-10-06
- The English text prevails over translations. Every entry below is a paraphrase. Read the PDF for the exact wording.

## Entry format
Each entry has a stable ID used in tests (`// ITF: <ID>`). IDs are never renumbered. Retired IDs stay listed and are marked *retired*.

**Origin** values:
- **Rule**: stated by the source.
- **Derived**: follows directly from the stated rules.
- **Not covered**: the source is silent, and the behaviour is our product decision.

The Tests column is filled in by the engine feature.

### Game scoring
| ID | Rule / appendix ref | Origin | Paraphrase | Engine implication | Tests |
| --- | --- | --- | --- | --- | --- |
| GM-01 | Rule 5(a) | Rule | A standard game counts 0 ("Love"), 15, 30, 40, then game. The server's score is called first. | Points map to 0/15/30/40. The display shows "0", never "love" (glossary). Accessibility labels read the server's score first. | |
| GM-02 | Rule 5(a) | Rule | At 3 points each the score is Deuce. Whoever wins the next point has Advantage. Winning the point after that wins the game; losing it goes back to Deuce. The game needs two consecutive points after Deuce. | Advantage format: a game is won with ≥4 points and a 2-point lead. Expose deuce and advantage states. | |
| NA-01 | App. VI — No-Ad scoring | Rule | No-Ad uses the same 0/15/30/40 counting. At 3 points each it is Deuce, and a single deciding point is played. Whoever wins it wins the game. | No-Ad format: at 3–3 the next point wins the game. Expose a "deciding point" state. | |
| NA-02 | App. VI — No-Ad scoring | Rule | On the deciding point the receiver chooses whether to receive in the right or the left half of the court. | The server side for the deciding point is the receiver's choice, not computed from the score. The engine must not claim a fixed deuce/ad side here. UI and spec decide how to show it. | |

### Tie-break game
| ID | Rule / appendix ref | Origin | Paraphrase | Engine implication | Tests |
| --- | --- | --- | --- | --- | --- |
| TB-01 | Rule 5(b) | Rule | Tie-break points count 0, 1, 2, 3… The first to 7 points with a 2-point lead wins the game and the set. Play continues until there is a 2-point margin. | 7-point tie-break: win at ≥7 with a 2-point lead, no upper cap. | |
| TB-02 | Rule 5(b) | Rule | The player due to serve serves the first tie-break point. The opponent serves the next two, and then serve alternates every two points. | Tie-break server for point k (0-based): the first server serves k = 0, then the server changes on k = 1, 3, 5… | |
| TB-03 | Rule 5(b) | Rule | Whoever served first in the tie-break receives in the first game of the next set. | The first server of the next set is the opponent of the tie-break's first server. | |
| TB-04 | Rule 17 | Rule | In a tie-break, serves alternate between court halves, and the first one is from the right half. | Tie-break serving side: point 0 from the right (deuce court), then alternate every point. The side depends on the total points played, not on the server. | |
| TB-05 | Rule 10 | Rule | During a tie-break the players change ends after every six points. | Emit a change-of-ends event when the total tie-break points is a positive multiple of 6. | |
| TB-06 | App. VI — Change of ends | Rule | Approved alternative: in a tie-break, change ends after the first point and then every four points. | Not in MVP scope. Recorded so it is not confused with TB-05. | |

### Set scoring
| ID | Rule / appendix ref | Origin | Paraphrase | Engine implication | Tests |
| --- | --- | --- | --- | --- | --- |
| ST-01 | Rule 6 | Rule | Two main set methods exist, Advantage set and Tie-break set, and the method is announced in advance. With tie-break sets, it must also be announced whether the final set is a tie-break set or an advantage set. | Set method is part of the match setup and is fixed for the match. | |
| ST-02 | Rule 6(a) | Rule | Advantage set: the first to 6 games with a 2-game lead wins. There is no tie-break, and the set continues until the margin is reached. | Advantage-set mode: win at ≥6 games with a 2-game lead, no cap. MVP setup always uses tie-break sets, so this is for reference only. | |
| ST-03 | Rule 6(b) | Rule | Tie-break set: the first to 6 games with a 2-game lead wins. At 6 games all a tie-break game is played. | For a 6-game set: win at 6–≤4 or 7–5, and play a tie-break at 6–6. A tie-break win makes the set 7–6. | |
| ST-04 | App. VI — Short sets (1) | Rule | Short set: the first to 4 games with a 2-game lead wins, and a tie-break is played at 4 games all. The sanctioning body may instead put the tie-break at 3 games all. | For a 4-game set: win at 4–≤2 or 5–3, and play a tie-break at 4–4. MVP uses 4–4. The 3–3 tie-break variant comes with Fast4 in v1.1. **Approved** (Denys, 2026-10-07). | |
| ST-05 | App. VI — Short set tie-break (2) | Rule | With short sets only, a 5-point short-set tie-break may be used: first to 5, with a deciding point at 4 all. The sanctioning body decides the serving order. Ends change once, after the first four points. | Not in MVP scope. MVP short sets use the standard 7-point tie-break (TB-01). | |
| ST-06 | — (not in source) | Not covered | The source does not define an 8-game set ("pro set"). Rule 27(g) mentions playing to 8 games all and then a tie-break, but only to correct an error. It does not define a format. | Our decision for an 8-game set: first to 8 with a 2-game lead, and a 7-point tie-break at 8–8, so the set ends 9–8. **Approved** (Denys, 2026-10-07). | |
| ST-07 | Rule 6(b), App. VI (1) | Derived | Generalisation used by the app: for a set length of N games (4, 6 or 8), the set is won at N games with a 2-game lead, and at N–N a tie-break decides the set, which ends N+1–N. | Exact for N = 6 (Rule 6(b)) and N = 4 (App. VI). For N = 8 it rests on ST-06. | |

### Match scoring
| ID | Rule / appendix ref | Origin | Paraphrase | Engine implication | Tests |
| --- | --- | --- | --- | --- | --- |
| MT-01 | Rule 7 | Rule | A match is best of 3 sets (2 needed) or best of 5 (3 needed). | Best of 3 is in MVP. Best of 5 is roadmap v1.1. | |
| MT-02 | — (not in source) | Not covered | The source does not describe a one-set match. | Our decision: the first player to win one set wins the match. The "match tie-break instead of the deciding set" option (MT-03) applies only to best of 3; setup hides it for 1-set matches. **Approved** (Denys, 2026-10-07). | |
| MT-03 | App. VI — Match tie-break (10 points) (4) | Rule | At one set all (or two sets all in best of 5), a single tie-break can replace the deciding set. The first to 10 points with a 2-point lead wins it and the match. | Optional match tie-break: at 1–1 in sets, the deciding "set" is a tie-break to 10 with a 2-point lead. It is recorded as a set won 1–0 (see MT-05). | |
| MT-04 | App. VI — Note on match tie-break | Rule | When a match tie-break replaces the final set, the original order of service continues. | The first server of the match tie-break is the player due to serve the next game. Within it, serving follows TB-02 and TB-04. | |
| MT-05 | — (not in source) | Not covered | The source does not say how a match tie-break appears in the score line. Common practice writes it as a set, e.g. "1–0 (10–7)". | Our decision: store it as a set with a flag and its points. Display rules go in the spec. | |
| MT-06 | App. VI — Match tie-break (7 points) (3) | Rule | Alternative: a 7-point match tie-break. | Not in MVP scope. | |
| MT-07 | App. VI — Final set tie-break (10 points) (5) | Rule | Alternative: in the final set, at 6 games all, play a 10-point tie-break. | Not in MVP scope. | |

### Service and ends
| ID | Rule / appendix ref | Origin | Paraphrase | Engine implication | Tests |
| --- | --- | --- | --- | --- | --- |
| SV-01 | Rule 9 | Rule | A toss decides the choice of ends and of serving or receiving. The winner picks one of those, or makes the opponent choose. | Setup captures the first server (me, opponent or coin toss). The app's coin toss stands in for the real one. | |
| SV-02 | Rule 14 | Rule | After every standard game, the server and receiver swap. | The server alternates after each completed standard game, across set boundaries too (but see TB-03 after a tie-break). | |
| SV-03 | Rule 17 | Rule | In a standard game, the server alternates court halves and starts from the right half in every game. | Serving side in a standard game: right (deuce court) when total points in the game is even, left (ad court) when odd. Exception: the No-Ad deciding point (NA-02). | |
| SV-04 | Rule 5(b) + Rule 14 | Derived | A tie-break counts as one game for the order of service: the next set starts with TB-03, not with a plain alternation from the tie-break's last server. | After a tie-break set, apply TB-03 instead of SV-02. | |
| EN-01 | Rule 10 | Rule | Players change ends after the 1st, 3rd and every later odd game of each set. | Emit a change-of-ends event when the games played in the current set is odd. | |
| EN-02 | Rule 10 | Rule | Players also change ends at the end of a set, unless that set had an even total of games. Then they change after the first game of the next set. | At the end of a set, change ends if the set's total games is odd. If it is even, the change comes after game 1 of the next set, which EN-01 already covers. | |
| EN-03 | Rule 10 + Rule 5(b) | Derived | A tie-break set ends with an odd total (e.g. 7–6 = 13 games), so the players change ends between sets. | Follows from EN-02. Test it explicitly. | |
| EN-04 | — (not in source) | Not covered | The source does not say whether ends change before a match tie-break that replaces the final set. | Our decision: apply EN-02 with the match tie-break counted as the first "game" of the new set. Within it, change every 6 points (TB-05). A set won in a tie-break has 2N+1 games for set length N (e.g. 7–6 = 13, 5–4 = 9, 9–8 = 17), which is always odd, so ends change after it, before the match tie-break (EN-03); the engine spec must include this as an explicit test case. **Approved** (Denys, 2026-10-07). | |

### Correcting errors (reference)
| ID | Rule / appendix ref | Origin | Paraphrase | Engine implication | Tests |
| --- | --- | --- | --- | --- | --- |
| CE-01 | Rule 27 | Rule | When an error is discovered, all points already played stand. Order-of-service mistakes are fixed according to set conditions. | The app uses undo (dropping events) instead of officiating corrections. Rule 27 is not modelled in MVP, and the spec must say so. | |

### Derived concepts
| ID | Rule / appendix ref | Origin | Paraphrase | Engine implication | Tests |
| --- | --- | --- | --- | --- | --- |
| BP-01 | — (not in source) | Not covered | The Rules of Tennis do not define "break point". | Our definition, derived from GM-01, GM-02 and NA-01: in a standard (non-tie-break) game, a point where the receiver wins the game if they win it. Examples: 30–40, 0–40, 15–40, the receiver's advantage, and the No-Ad deciding point (which counts as a break point for the receiver). **Approved** (Denys, 2026-10-07). | |
| BP-02 | — (not in source) | Not covered | The source does not define "converted" and "saved" break points. | Converted: the receiver wins a break point. Saved: the server wins a break point. Points inside a tie-break are never break points. **Approved** (Denys, 2026-10-07). | |
| BP-03 | — (not in source) | Not covered | The source does not define a "service game held". | Held: the server wins a standard game they served. Tie-breaks are excluded. **Approved** (Denys, 2026-10-07). | |

## Assessment levels (used by the reviewer)
- **Full**: the spec matches the rule.
- **Partial**: the spec matches, with a gap to resolve.
- **Not covered**: the source is silent; the decision is ours and must be labeled as such.
- **Conflict**: the spec contradicts the rule; work stops until Denys decides.
