# swimming pools near me

- **Date:** 07-28-2026
- **Status:** DONE
- **Origin used:** 10.789218, 106.773862 (±92 m) — precise Chrome GPS fix, granted by the user
  in-session on 07-28-2026. Reverse-geocodes to the An Phú / Bình Trưng area of Thủ Đức City.
- **Asked for:** "I want to go swimming 6h30 a.m tomorrow, connect my google maps and scan near pool within 5 km — create a table include: name, rates and link to comment on google, open-time, cost — sort near to far"

## Goal

A CSV, openable in Excel, listing every swimming pool within 5 km of the user's location,
sorted nearest-first, with enough information to pick one and leave the house at ~06:00
tomorrow (**Wednesday 07-29-2026**). Each row says whether the pool is actually open at
06:30, what it costs, how it is rated, and links straight to its Google Maps reviews.

> ❓ ASSUMPTION: "tomorrow" = Wednesday 07-29-2026, and 6h30 = 06:30 in the morning
> (early-morning swim). The open-time check is therefore against **Wednesday** hours, not
> weekend hours — several pools in Vietnam differ between the two. Correct me if wrong.

**Out of scope:** booking, calling, or messaging any pool; adding anything to the user's
calendar; route/navigation planning beyond the distance number; pools further than 5 km even
if they are better.

## Workflow

1. **[USER]** Give the origin point for the 5 km radius — a street address, a Google Maps
   pin/URL, or "use my current location in Chrome". Nothing else can start until this is fixed.
2. Open Google Maps in the user's existing Chrome session and search for swimming pools
   around that origin, capped at a 5 km radius.
3. For each result, collect: name, star rating + number of reviews, Google Maps link to its
   reviews, opening hours for Wednesday, and distance from the origin.
4. Determine the entry price for each pool. Google Maps usually does **not** carry ticket
   prices, so this step falls back to the pool's own page / Facebook page / a web search.
   Anything not confirmed is written as `UNKNOWN`, never estimated.
5. Flag each pool `YES` / `NO` / `UNKNOWN` on whether it is open at 06:30 Wednesday.
6. Write the CSV sorted by distance ascending, UTF-8 with BOM.
7. Report the shortlist in chat — the nearest ones that are actually open at 06:30.

> ❓ ASSUMPTION: "connect my google maps" = drive maps.google.com through the Chrome
> browser tools in the session the user is already signed into. I have **no** API access to
> their Google account data (Timeline, saved places, location history), so I cannot read
> their home address or current GPS position — that is why step 1 is on them. Correct me if
> you meant something else by "connect".

> ❓ ASSUMPTION: distance = straight-line ("as the crow flies") radius, which is what Maps
> search returns. Driving distance will be longer. Say so if you want driving distance instead,
> since that changes the sort order.

## Output

| File | What it is | Format |
| --- | --- | --- |
| `req.md` | This contract | Markdown |
| `pools-within-5km.csv` | The full scan: all 16 pools, nearest first | CSV, UTF-8 **with BOM** |
| `pools-shortlist-sorted.csv` | The user's own filtered six, re-sorted nearest-first with a fallback chain | CSV, UTF-8 **with BOM** |

**Follow-up (07-28-2026, after the first delivery):** the user filtered `pools-within-5km.csv`
down to six rows by deleting the rest, leaving them in scrambled `Priority` order. They asked for
the survivors re-sorted nearest-first and made easy to fall back through when one is closed.
`pools-shortlist-sorted.csv` is that list: `Priority` renumbered 1..6 by distance, plus two new
columns — `Phone` (who you can actually ring) and `If_Closed_Go_To` (the next row worth riding to,
with the extra distance it costs). The chain deliberately skips rows whose hours Google does not
confirm, so a fallback never points at a pool that cannot be verified.

Columns: `Choose`, `Priority`, `Name`, `Distance_km`, `Opens_By_0630`, `Open_Time_Wed`,
`Rating`, `Reviews`, `Cost_VND`, `Action`, `Google_Reviews_Link`, `Note`.

- `Opens_By_0630` vocabulary: `YES / NO / UNKNOWN`
- `Action` vocabulary: `GO / BACKUP / CHECK / SKIP`
- `Priority` runs 1..N in distance order (nearest = 1), matching the user's "sort near to far".
  This deliberately overrides the house rule of grouping rows by action first.
- `Note` carries the reasoning: why it is `GO` vs `SKIP`, where the price came from, whether
  hours were confirmed or guessed, membership-vs-single-ticket, lane availability, etc.

## Check-list

- [x] Origin point confirmed by the user before any searching happened — they chose the
      Chrome-GPS route; the fix was taken before the first search ran
- [x] Every listed pool is within 5 km of that origin — furthest is 4.65 km
- [x] Rows sorted by `Distance_km` ascending, `Priority` running 1..N in that same order
- [x] Every row has a Google Maps reviews link that resolves to that specific pool — each link
      is the exact name+coordinate query that was navigated during collection
- [x] Every row has a non-empty `Note`
- [x] No price is invented — unconfirmed prices are `UNKNOWN` (9 of 16 rows)
- [x] `Opens_By_0630` and `Action` use only the vocabularies listed above
- [x] CSV is UTF-8 with BOM — byte-verified as `EF BB BF`. Excel itself was not opened, so
      "renders correctly in Excel" is inferred from the BOM, not observed
- [x] Output files match the Output table above (names, formats, encoding)
- [x] User has reviewed and approved this req.md

## Known limitations

1. **Coverage is not exhaustive.** Google Maps caps each search at 10 results and re-anchors to
   the device's real GPS, so sweeping the viewport around the origin returned the same set every
   time. Coverage was widened by varying the query instead (`hồ bơi`, `bể bơi`, `swimming pool`,
   plus ward names). Pools with no Maps listing, or listed under a name none of those queries hit,
   are missing.
2. **Rows 14 and 15 are one venue.** `Hồ bơi Thảo Điền` and `Hồ bơi An Phú` share the address
   8 Thảo Điền, An Khánh, with conflicting hours between the two listings.
3. **Hours are unknown for 5 rows** because Google carries none. Where a review site supplied
   hours, that claim sits in the `Note` and `Opens_By_0630` stays `UNKNOWN` — third-party hours
   were never promoted to a `YES`/`NO`.
