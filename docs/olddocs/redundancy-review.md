# World of Cake Redundancy Plan — Independent Review

Date: 2026-08-31

This document reviews implementation progress against `redundancy.md`. It is a read-only audit: no code was changed during this review.

Verification performed on Linux:

- All five headless test hxml targets (`test-*-headless.hxml`) — **passed**
- `./derivatives/vcvrack/build_all.sh` — **passed** (plugins up to date)

---

## Executive summary

| Phase | Topic | Status |
|-------|--------|--------|
| 1 | Rack timing policy | **Done** |
| 1a | Native coordinates in bridge | **Done** |
| 2 | Delete legacy Rack facades | **Mostly done** (HarnessApi remains) |
| 3 | Persistence normalization | **Partial** (runner yes; Rack param sync mostly no) |
| 4 | Rack common helpers | **Done** |
| 5 | Makefile include | **Done on Linux** (Windows unverified) |
| 6 | ControlRunnerBase | **Done** (all five runners) |
| 7 | Haxe SequencerCore | **Done** — see detailed review below |
| 8 | OpenFL bases | **Not started** |

The Rack robustness track (Phases 1–6) is largely complete on Linux. Phase 7 successfully extracted shared Haxe lifecycle mechanics without over-abstracting app semantics. The largest remaining gaps are Rack post-import param mirroring (Phase 3), HarnessApi/doc cleanup (Phase 2), and OpenFL shell duplication (Phase 8).

---

## Phase 7: Haxe Sequencer Core — detailed review

### Verdict

**Phase 7 is complete and well scoped.** The implementation matches the plan’s intent: consolidate transport, time, event queue, and dirty-flag mechanics; keep musical behaviour, JSON schemas, and output semantics per app.

`redundancy.md` marks Phase 7 complete; this review confirms that claim against the source.

### What was added

`Source/worldofcake/SequencerCore.hx` (72 lines) owns:

| Mechanism | Implementation |
|-----------|------------------|
| State fields | `currentTime`, `events`, `paused`, `dirty` (public) |
| Transport | `pause()`, `resume()` |
| Time step | `advanceTime(delta)` with paused / non-finite / non-positive guard |
| Model hook | `advanceModel(delta):Bool` — default `false`; subclasses override |
| Dirty policy | Sets `dirty = true` only when `advanceModel` returns `true` |
| Event queue | `hasEventBefore`, `getNextEvent` |
| Host queries | `getLogicalTime()`, `isPaused()`, `consumeDirty()` |
| Reset helper | `resetTransport(unpause=true)` — clears time/events, optional unpause, sets dirty |
| Utility | `clearEvents()` |

Design note: `ISequencer.reset()` remains **app-defined**. Apps implement `reset()` by calling `resetTransport()` then rebuilding domain state (grid, balls, sliders, network, etc.). That split is correct — `reset()` meaning differs per app beyond transport reset.

### Migration coverage

All five sequencers now extend `SequencerCore`:

| App class | `advanceModel` behaviour | Notes |
|-----------|-------------------------|-------|
| `TimeSliderSequencer` | Moves sliders; returns `true` only if a slider actually changed | Best use of the dirty hook |
| `Gbloink` | Moves balls; always returns `true` | Also sets `dirty` directly in `moveBall` |
| `ZewpSequencer` | Sub-steps physics at 1 ms inside each host delta; always returns `true` | Preserves discrete collision/turn decisions |
| `KDiagramSequencer` | Graph cursor motion + note events; always returns `true` | Events pushed during model advance |
| `TileLandSequencer` | Cursor motion + CC events; always returns `true` | Events pushed during model advance |

All five use the shared constructor pattern `super(true)` (or equivalent) and call `resetTransport()` from their `reset()` implementations.

### What correctly stayed app-specific

Per the plan’s “questionable shared scope” list, these remain local — as they should:

- Manual JSON export/import and schema versioning in each app
- Mouse/control routing and UID dispatch
- Note vs CC event generation strategy
- Gbloink’s `setPaused` / scale / edge-notes semantics
- TileLand `visualVersion` tracking
- Zewp `discardPendingEvents()` for Rack snapshot mode
- KDiagram graph/network logic

### Intentional deviations (known, acceptable)

**1. Gbloink pause/dirty semantics**

Gbloink overrides `pause()` / `resume()` to call `setPaused()`, which sets `dirty = true` on toggle. It also exposes `needsRedraw()` which reads `dirty` **without consuming** it, unlike other apps that use `consumeDirty()` in their views. This predates Phase 7 and was deliberately preserved. Gbloink may over-redraw while running; behaviour is unchanged from before the migration.

**2. Gbloink direct dirty writes**

`moveBall` sets `dirty = true` directly in addition to `advanceModel` returning `true`. Redundant but harmless.

**3. Event generation split unchanged**

- **Push model** (events in `advanceModel`): Gbloink, TileLand, KDiagram
- **Pull model** (`generateEvents()` from `*View.redraw`): TimeSlider, Zewp (and KDiagram has a stub `generateEvents` for OpenFL compatibility)

Phase 7 did not attempt to unify this. Rack/headless paths that never redraw still depend on the push model or snapshot-based output for pull-model apps. This is a pre-existing architectural split, not a Phase 7 regression.

**4. JSON import does not use `resetTransport`**

Import paths still manually assign `currentTime`, `paused`, and often `events = []`. Could be refactored later to call shared helpers, but out of Phase 7 scope.

### What Phase 7 did not address (expected next work)

| Remaining duplication | Suggested phase |
|----------------------|-----------------|
| Five `*Main.hx` timer/event-drain shells | Phase 8 |
| Four `*World.hx` mouse routers | Phase 8 |
| Per-app JSON envelope boilerplate (`"v"`, `"kind"`, guards) | Future Haxe helper or Layla metadata |
| `*Harness.hx` null-guard wrappers | Phase 2 / bridge cleanup |
| `ISequencer` missing `getLogicalTime`, `consumeDirty`, `isPaused` | Optional interface extension |
| Public `events` field for harness peek/pop | Bridge concern, not sequencer core |

### Code quality assessment

**Strengths**

- Small, readable base class with a single extension point (`advanceModel`)
- TimeSlider demonstrates that the `Bool` return value is useful for dirty suppression
- Zewp’s sub-step comment documents why coarse deltas would break physics
- No change to the portable Haxe API surface hosts already depend on
- hxcpp builds pick up `SequencerCore` cleanly (visible in generated `native/include/worldofcake/SequencerCore.h`)

**Minor observations**

- `SequencerCore` fields are public; subclasses and harnesses mutate them freely. Matches prior style but differs from a stricter encapsulation approach.
- `clearEvents()` exists but Zewp still uses `events = []` in `discardPendingEvents()`.
- The plan suggested piloting on one app first; all five were migrated in one pass. Headless tests and Rack builds passing suggest the batch migration was successful.

### Phase 7 verification results (this review)

```
hxml/tests/test-gbloink-headless.hxml     — All Gbloink headless tests passed
hxml/tests/test-kdiagram-headless.hxml    — All K-Diag headless tests passed
hxml/tests/test-tileland-headless.hxml    — All TileLand headless tests passed
hxml/tests/test-timeslider-headless.hxml  — All TimeSlider headless tests passed
hxml/tests/test-zewp-headless.hxml        — All Zewp headless tests passed
./derivatives/vcvrack/build_all.sh — all five modules built
```

### Phase 7 conclusion

Accept Phase 7 as **complete**. The abstraction fits the apps that were migrated, tests pass, and native builds succeed. Do not broaden `SequencerCore` further until Phase 8 (OpenFL) or a JSON-envelope helper proves a concrete need.

Recommended `redundancy.md` tweak: note that Gbloink dirty/view semantics and the push/pull event split remain open follow-ups, not blockers for closing Phase 7.

---

## Other phases — brief status (unchanged from prior review unless noted)

### Phase 1 / 1a — Done

- `WocRackTiming.hpp` used by all five Rack modules
- Coordinates in `bridge/native/WorldOfCakeBridgeTypes.h`; top-level `Cpp/` removed

### Phase 2 — Mostly done

- `*RackApi.hx` deleted; hxml compiles `*Harness`
- `*HarnessApi.hx` (TileLand, KDiagram, TimeSlider) still used by `WorldOfCakeHarnessExports` / `gbloink-bridge.hxml`
- Several docs still describe the obsolete mutex/direct-Haxe model

### Phase 3 — Partial

- `StatePersistence` + `WocRackStateJson.hpp` shared across modules
- Runner-side post-import snapshot refresh: **yes**
- Rack `dataFromJson` param mirroring after load: **only Gbloink** (pause, scale, edge notes)

### Phase 4 — Done

- `WocRackVoltage.hpp`, `WocRackTransport.hpp`, per-module transport ID maps

### Phase 5 — Done on Linux

- `derivatives/vcvrack/common/plugin.mk`; Windows verification still outstanding

### Phase 6 — Done (plan doc was stale)

All five `*ControlRunner` classes inherit `ControlRunnerBase`. `pump()` bodies remain app-specific copy-paste; deeper pump templating was intentionally deferred.

### Phase 8 — Not started

No `ComponentWorldBase` or `SequencerAppMain`. Five `*Main.hx` and four `*World.hx` still duplicate OpenFL host wiring.

---

## Other redundancies still worth tracking

1. **Dead `SIM_RATE_PARAM` knobs** on TileLand, TimeSlider, KDiagram (Gbloink uses the slot as “Overall speed”)
2. **Five identical `plugin.cpp` boot patterns** — candidate for shared header
3. **TileLand trefoil drawing** duplicated in Haxe view and Rack NanoVG
4. **Harness + HarnessApi** dual bridge layer
5. **Compressed one-liner C++** in non-Gbloink Rack modules — maintainability drag, not functional duplication

---

## Suggested next steps

1. Close Phase 7 in `redundancy.md` with the caveats above
2. Phase 3 follow-up: Rack post-import param sync for all modules
3. Phase 8: `ComponentWorldBase` pilot (TileLand or KDiagram — nearly identical worlds)
4. Phase 2 cleanup: retire HarnessApi or document it as headless-link-only
5. Windows build verification for Phases 5–7
