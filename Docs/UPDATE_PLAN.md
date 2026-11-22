# Slingshot For Dinosaurs: update and live-ops plan

The working plan for post-launch updates. Claude (or anyone on the team) should read this before planning an update, then update the **Log** at the bottom after shipping one.

## 1. KPI targets

Check them weekly with `powershell -NoProfile -ExecutionPolicy Bypass -File Tools/AnalyticsReport.ps1 -Days 14`. The report lands in `Docs/Analytics/`.

| Metric | Launch floor | Good | Great | Report column / source |
|---|---|---|---|---|
| D1 retention | 15% | 25% | 35%+ | `D1 ret.` |
| D7 retention | 4% | 8% | 12%+ | `D7 ret.` |
| Playtime per DAU | 15 min | 25 min | 40 min+ | `Playtime/DAU (min)` |
| Avg session | 8 min | 14 min | 20 min+ | `Session (min)` |
| Payer conversion | 1% | 2.5% | 4%+ | `Payer CVR` |
| ARPDAU (R$) | 0.5 | 1.5 | 3+ | `ARPDAU` |
| Onboarding: Joined to FirstCatch | 80% | 90% | 95%+ | Onboarding funnel |
| Onboarding: FirstCatch to FirstUpgrade | 35% | 50% | 65%+ | Onboarding funnel |
| Purchase prompt to success | 15% | 25% | 35%+ | Purchase funnel |

### Decision rules (what to fix first)

1. **Joined to FirstCatch under 80%:** FTUE problem. Check the GuideController arrow, the launch button size on phones, and load time (`[WorldBuilder] assets ready in` should be under 3 s).
2. **D1 under 15% but onboarding fine:** the first-session goal is unclear. Tune the NextGoal bar, the early biome distances (`DinoConfig` MinMeters) and the first shop prices (`ShopConfig`).
3. **D7 low, D1 fine:** not enough to come back for. Ship content (new species or biome), a new quest pool, or a weekend event.
4. **Playtime low:** players stall in a biome. Check the `BiomesReached` progression events, then lower the next biome's distance or raise training gains.
5. **Payer CVR low, purchase funnel fine:** offers aren't seen. Check `OfferOpened` / `ProductViewed` counts, try the starter pack earlier, and change the badge timing.
6. **Purchase prompt-to-success low:** price or value problem. Try one change at a time (price, or what's in it), and keep it for at least 3 days.
7. **Ad campaign D1 below organic D1:** the ad creative mis-sells the game. Change the thumbnail or creative before raising spend.

Change **one lever per area per week** so its effect can be read in the data.

## 2. Weekly rhythm

| Day | What |
|---|---|
| Monday | Run the analytics report, compare against targets, pick the week's focus with the decision rules. |
| Tue to Wed | Build the update (one headline feature + balance changes). Playtest in Studio and check the console. |
| Thursday | Publish. Update the game description's "UPDATE" line, post in the group shout and Discord, and add a new code (`RetentionConfig.Codes`). |
| Saturday | **Admin Abuse hour** (same time every week, announce on Thursday): admin panel for server luck x5, 2 Meteor Storms, a Rare Spawn. |
| Sunday | Read weekend data: event joins, peak CCU, revenue. |

## 3. Limited dino calendar

These rotate automatically (`MonetizationConfig.ExclusiveRotation`, 14-day windows). Announce each new one in the update notes and the group shout. Players who've opted in can be sent a notification once a "NewExclusive" message exists (see section 6).

| Window (UTC) | Limited dino |
|---|---|
| now to 2026-12-07 | Celestial Raptor (Huge Cosmic Velociraptor) |
| 2026-12-07 to 2026-12-21 | Magma King Rex (Huge Magma T-Rex) |
| 2026-12-21 to 2027-01-04 | Frost Brachio (Big Frost Brachiosaurus): Christmas window |
| 2027-01-04 to 2027-01-18 | Toxic Spino (Huge Toxic Spinosaurus) |
| 2027-01-18 to 2027-02-01 | Golden Trike (Colossal Golden Triceratops) |
| then repeats | Add new entries to `List` to extend; never reorder past entries, or owned dinos shift windows. |

## 4. Roadmap (first 8 weeks)

Each week has one headline feature. Pick content according to what the data says (section 1).

| Week | Headline | Also |
|---|---|---|
| 1 (launch) | Launch + LAUNCH code | Watch the funnels daily. Hotfix only. |
| 2 | **Biome 6: Crystal Caves** (3 species, new mutation "Crystal") | Rebalance the biome 3 to 4 gap if playtime stalls. |
| 3 | **Dino evolutions**: merge 3 of a kind into the next size | New daily quest types (Evolve, Merge). |
| 4 | **Christmas event**: snow skybox, Frost Brachio limited, Gingerbread bait | Gift-pass promo banner ("Gift a pass this Christmas"). |
| 5 | **Trading** (only if D7 is at least 8%; otherwise a retention feature) | Trade-safe item audit. |
| 6 | **Biome 7: Sky Islands** | New slingshot and bait tier. |
| 7 | **Clans / park visits**: visit friends' parks, like a park | Friend luck boost raised to +15% if invites are low. |
| 8 | **Season 1 pass** (free + premium track, 30 days) | Review all prices against 6 weeks of data. |

## 5. Ads and acquisition

* **Sponsored ads (Roblox Ads Manager):** start at $10–20 a day once D1 is at least 20% organically. The report pulls `SponsoredAdsSpendUsd` and `SponsoredAdsClicks` by campaign, and D1 by `AcquisitionSource`. Scale a campaign only if its D1 is within 80% of organic D1.
* **External links (TikTok, YouTube, Discord):** always use a launchData tag so joins are attributed in our own events:
  `https://www.roblox.com/games/start?placeId=112349951625680&launchData=src%3Atiktok%3Acampaign1`
  The format is `src:<source>:<campaign>`. The report shows avg session minutes per source (`SessionEnd`, CustomField1).
* **Thumbnails:** test 2 at a time with the Roblox thumbnail test. The report can add `ThumbnailQualifiedPTR`. Keep the winning style: chrome/pink logo top-left, cheering avatars, a giant mutated dino.
* **Group:** "Blue Chip Games" (144483796) owns the game. Members get +10% income, and there's one auto join prompt after 15 launches. Use the group shout for every update.

## 6. Pending setup (do when unblocked)

- [ ] **Badges:** add the API key permission `legacy-badges` (create/manage) for this universe, then run `bash Assets/Blender/scripts/create_badges.sh` and paste the ids into `Config/BadgeConfig.luau`. Free quota only, so it may take a few days.
- [ ] **NewExclusive notification:** create the string in Creator Dashboard > Engagement > Notifications ("A new limited dino just arrived: {dino}!"), put the id in `Config/NotificationConfig.luau`, and add a send when the rotation changes (needs a scheduled sender; Roblox servers can only notify on events).
- [ ] **Maturity questionnaire:** complete it so the rating can be All Ages / 9+.
- [ ] **Analytics alerts:** once the game has live traffic (Roblox enrols it in performance monitoring), add `universe.analytics.alert:write` to the key and run `bash Tools/create_alerts.sh`.
- [ ] **Auto-translation:** turn it on in Creator Dashboard > Localization.

## 7. Update checklist (every release)

1. Change only what the plan says. Note config changes in `Docs/DECISIONS.md`.
2. Studio playtest: no new console errors, phone-size screenshot of any new UI.
3. New analytics events added to `Config/AnalyticsConfig.luau` (unknown names are dropped with a warning).
4. New products: create them with the API and add them to `MonetizationConfig`, never with a 0 id in live servers.
5. Commit and push, publish, update the description, shout, and add a code.
6. Next Monday: run the report and write the result in the Log below.

## 8. Log

| Date | Update | Result after 1 week |
|---|---|---|
| 2026-11-22 | Pre-launch: gifting, limited rotation, notifications, badges (pending ids), friend invites + luck, group perk, music, favourite prompt, session analytics | (launch pending) |
