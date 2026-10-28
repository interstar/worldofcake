# Apps, Targets and Per-Target Variation

This document describes how one WorldOfCake app (TimeSlider, Gbloink, …) is defined once and built for several targets (OpenFL, JUCE/VST3, VCV Rack) that are allowed to differ, and the build architecture that follows from it. `BUILD_INSTRUCTIONS.md` describes how to run the builds; this document explains why they have this shape. The practical guide to writing an app is [`WRITING_WOC_APPS.md`](WRITING_WOC_APPS.md).

## 1. Decision

- Each app has one **app definition** (`apps/<app>/app.edn`): what the app *is*, for every target.
- Each target has an **overlay** (`apps/<app>/<target>.edn`) that is deep-merged over the app definition, and a **layout** (`apps/<app>/<target>.layla`).
- Targets may differ in **model shape** (e.g. TimeSlider has 4 lanes in Rack and 8 in the VST), **presentation** and **host specifics**.
- The generator runs once **per app and target** and writes into a **per-target generated tree**. Each target's build compiles against its own tree only.
- JUCE and OpenFL are kept as close as possible: the JUCE overlay `:extends` the OpenFL overlay and normally inherits its layout.
- Layla is unchanged. Overlays, inheritance and repetition belong to the EDN layer and the generator, not to the layout language.
- The price of variation is that **saved state is not portable between targets** whose model shapes differ. A conversion script can be written later if it is ever needed.

## 2. Why

### Where we were

| Source | Drove |
| --- | --- |
| `layouts/openfl/<app>.layla` + `.edn` | the OpenFL panel; the JUCE panel (borrowed); every control ID; the C++ control metadata (also used by Rack for knob ranges); control outputs; TimeSlider's track list |
| `layouts/rack/<app>.layla` + `.edn` | the Rack panel, patch bay and socket labels, in a different EDN schema |

The OpenFL EDN was doing three jobs: describing the app, describing OpenFL's layout, and (by default) describing JUCE's. Everything generated from it went to one shared place (`Source/generated/<app>/`, `bridge/native/worldofcake/generated/`), so every target got the same model shape. "Rack has 4 TimeSlider lanes, the VST has 8" could not be expressed, and any fix would have been a special case. More differences are coming (lane counts, cursor counts, host-only controls, window sizes), so variation needs a general home.

### The enabling fact

The Haxe model is already **compiled separately for every target**: OpenFL builds it, the JUCE wrapper runs its own hxcpp build, and every Rack module runs its own hxcpp build. So each compile can see different generated code. Generated Haxe keeps its package names (`generated.timeslider`); each target build simply puts its own generated directory on the classpath. The same holds for generated C++ headers and include paths. Maintained Haxe and C++ do not change to support a variant.

## 3. Concepts

| Term | Meaning |
| --- | --- |
| **App** | One sequencer: `gbloink`, `goldenpond`, `kdiagram`, `tileland`, `timeslider`, `zewp`. |
| **Target** | A host family the app is built for: `openfl`, `juce`, `rack`. (The headless test build uses the `openfl` target's generated code.) |
| **App definition** | `app.edn`: control semantics (kind, range, mapping, unit, default, label, tooltip), choices, control outputs, and model parameters with defaults. |
| **Overlay** | `<target>.edn`: what this target changes or adds. |
| **Layout** | `<target>.layla`: the target's spatial arrangement, in plain Layla. |
| **Resolved config** | App definition + overlay chain, deep-merged and with repetition expanded. This is what the generator renders. |

What a target may vary:

- **Model shape**: `:model` parameters such as `:lanes` or `:cursors`, and therefore which repeated controls and outputs exist.
- **Presentation**: colours, `:show-label`, icons, boxes, padding, presentation styles, window/panel size.
- **Host specifics**: Rack's patch bay, sockets and voltage laws; which outputs become VST parameters; transport policy.

## 4. Source layout

```text
apps/
  timeslider/
    app.edn          ; what TimeSlider is, for every target
    openfl.edn       ; OpenFL overlay
    openfl.layla
    juce.edn         ; {:extends :openfl ...}
    juce.layla       ; optional: inherited from openfl when absent
    rack.edn         ; Rack overlay (patch bay, CV sockets, :model {:lanes 4})
    rack.layla
  gbloink/
    ...
```

`layouts/openfl/` and `layouts/rack/` are replaced by `apps/`. Rack's former EDN schema (`:rack-components`, `:patch-bay`, `:module`) becomes ordinary keys of `rack.edn`.

### App definition (sketch)

```clojure
{:generator-version 2
 :app {:id "timeslider" :package "timeslider"}
 :model {:lanes 4                       ; default; overlays may change it
         :minimum-travel-time 120.0
         :maximum-travel-time 0.5}
 :outputs [{:repeat :lanes :id "lane{n}" :label "Lane {n}" :channel 1 :cc :n}]
 :components
 {"lane{n}track" {:repeat :lanes :kind :timeslider-track :colour [:palette :lanes]
                  :channel-control "lane{n}channel" :cc-control "lane{n}cc" :label-control "lane{n}label"}
  "lane{n}channel" {:repeat :lanes :kind :semantic-select :choice-range {:from 1 :to 16 :format "Ch %d"} ...}
  "reset" {:kind :button :label "Reset" :icon :reset}
  ...}
 :palettes {:lanes ["0x55B7D9" "0xE56B6F" "0x76B947" "0xC58BE8"]}}
```

### Overlay (sketch)

```clojure
;; apps/timeslider/openfl.edn
{:model {:lanes 8}
 :geometry {:panel-width 1200.0 :panel-height 600.0 :outer-padding 6.0 ...}
 :components {"lane{n}label" {:view-hook "addLabelInput"} ...}}

;; apps/timeslider/juce.edn: the VST is the OpenFL panel
{:extends :openfl}

;; apps/timeslider/rack.edn
{:model {:lanes 4}
 :module {:slug "TimeSlider" :plugin "WorldOfCake-TimeSlider" :panel {:width-mm ... :height-mm ...}}
 :patch-bay {...}}
```

### Merge rules

1. Resolve `:extends` first: a target's effective overlay is its parent's effective overlay with its own overlay merged on top. Chains are allowed; cycles are an error.
2. Merge the effective overlay over `app.edn`.
3. Maps merge recursively, key by key. Vectors and scalars from the overlay **replace** the app's value. `:components` merges per component ID, so an overlay can change one property of one control.
4. A component or key whose overlay value is `nil` is **removed** (e.g. a host that cannot offer a text input).
5. `:layout` resolution: `<target>.layla` if present, otherwise the `:extends` parent's layout.

### Repetition

A model parameter such as `:lanes` decides how many copies of a group of controls and outputs exist, so the EDN needs templates:

- An entry with `:repeat :lanes` is expanded once per lane, `n = 1 .. (:lanes :model)`.
- `{n}` in a string (an ID, a label, a control reference) becomes the lane number. `:n` as a value becomes the number itself (e.g. `:cc :n`).
- `[:palette :lanes]` takes the n-th colour from `:palettes :lanes`, cycling.

**Layouts are not templated.** Layla is unchanged, so each target's `.layla` lists its lanes explicitly. That is fine for fixed counts (4 or 8). If explicit layouts become burdensome, a repetition form for Layla can be considered separately; Layla's other consumer (the Canva app in `patterning/canvatest/alchemy_forms`) would then need checking.

Validation runs on the resolved config: every layout leaf and container label must have a component entry (as today), every repeated reference must resolve, and the layout must contain exactly the expanded IDs.

## 5. Generated outputs

The generator is invoked per app and target and writes only under that target's tree:

```text
generated/
  openfl/
    haxe/generated/<app>/...            ; layout, composition, control IDs, tracks (Haxe)
    native/worldofcake/generated/<app>/... ; control IDs and metadata (C++), used by headless native tests
  juce/
    haxe/generated/<app>/...
    native/worldofcake/generated/<app>/...  ; control IDs, metadata, LayoutGenerated.h
  rack/
    haxe/generated/<app>/...
    native/worldofcake/generated/<app>/...  ; control IDs, metadata, RackLayoutGenerated.h, RackOutputsGenerated.h
derivatives/vcvrack/<module>/generated/<Slug>.svg   ; Rack panel SVG (where Rack's asset loader expects it)
```

`generated/` is gitignored build output. `Source/generated/` and `bridge/native/worldofcake/generated/` are retired.

**Models work in an abstract space; layouts are for views only.** A model never reads generated panel geometry (no `*LayoutGenerated` import in model code). A TimeSlider lane is a value from 0 (bottom) to 1 (top), and a click arrives in the lane's own space: x is the travel-time fraction, y the target. Each view decides where lanes go: OpenFL from the composition's `TRACK_RECTS`, JUCE from `kLaneRegions` in `LayoutGenerated.h`, Rack by spreading its lanes across its play area. The model's own data (lane count, track/channel/CC/label control IDs, colours, travel times) is generated without a layout as `TimeSliderTracksGenerated` (Haxe) and `kLanes`/`kLaneCount` (C++ metadata).

**`:generate-views false`.** A target that draws its panel with a separate generator (Rack: `rack.layla` in Rack's schema) still needs the app's model code: control IDs, control metadata and model data. With `:generate-views false` in its overlay, the generator renders only that, from the resolved config alone, with control IDs in *model order*: plain components by ID, then repeated components lane by lane. No view classes are generated for that tree. Apps not yet migrated generate every tree's app code from their OpenFL pair.

Package and namespace names are identical in every tree (`generated.timeslider`, `worldofcake::metadata::timeslider`), so maintained code is written once; which tree it sees is decided by the build.

## 6. Build architecture

Every build has the same two stages:

1. **Generate**: render each app's resolved config for the target into `generated/<target>/`. Uses the vendored generator JAR (no Clojure checkout needed), or the generator source during generator development. Generation is deterministic; `-Check` verifies the tree is up to date without writing.
2. **Compile**: the target's normal build, with its own generated tree on the Haxe classpath and C++ include path.

| Target | Haxe classpath | C++ include path | Driven by |
| --- | --- | --- | --- |
| OpenFL | `Source`, `generated/openfl/haxe` | — | `run-openfl-preview.ps1` (`derivatives/openfl/project-<app>.xml`) |
| Headless tests | `Source`, `generated/openfl/haxe` | `generated/openfl/native` (native tests) | `build-headless.ps1` |
| JUCE/VST3 | `Source`, `bridge/haxe`, `generated/juce/haxe` | `bridge/native`, `generated/juce/native` | `derivatives/juce/build-windows.ps1` (each plugin has its own `.hxml` under `derivatives/juce/<plugin>/haxe/`) |
| VCV Rack | `Source`, `bridge/haxe`, `generated/rack/haxe` | `bridge/native`, `generated/rack/native` | `derivatives/vcvrack/build-rack-windows.ps1`, `build_module.sh` |

The JUCE build no longer borrows the Rack module's `.hxml`: it has its own, so the VST compiles against the JUCE tree.

A single generation entry point covers every combination:

```powershell
.\generate.ps1 -App all -Target all          # generate everything
.\generate.ps1 -App timeslider -Target juce  # one app, one target
.\generate.ps1 -Check                        # verify, write nothing
```

```bash
./generate.sh all all
./generate.sh timeslider juce
./generate.sh --check
```

Under the hood each call is `java -jar vendor/layla/worldofcake-laylagen.jar --app apps/<app> --target <target> --output generated/<target>` (plus `--panel-output derivatives/vcvrack/<module>` for Rack). `run-laylagen.ps1` keeps its role for generator development: the same arguments, run from the Clojure source, plus `-Task test`.

## 7. Consequences

- **State is target-specific.** An 8-lane VST patch loaded into a 4-lane build keeps lanes 1–4. TimeSlider already persists lanes by index, not by control ID, so this degrades gracefully.
- **Control IDs may differ per target.** They never cross targets (only persisted state does, and it does not use them).
- **Shared semantics stay shared.** Ranges, labels, tooltips, choices and output definitions live in `app.edn` once; a target changes them only by saying so in its overlay.
- **JUCE ≈ OpenFL by construction.** A JUCE difference is an explicit line in `juce.edn`.
- **More build directories.** Each target build must put its own generated tree on its paths; mixing trees is a build error to avoid. The build scripts own these paths so that day-to-day use is unchanged: generate, then build.
- **The vendored JAR changes** whenever the generator does (it now resolves overlays and repetition). Rebuild it with `laylagen/package-worldofcake-laylagen.sh` and commit it with its checksum.

## 8. Migration

TimeSlider is the pilot. Phases:

1. **Overlays** (done): `apps/<app>/` sources, deep merge and `:extends`, generator `--app/--target`; TimeSlider migrated with identical output.
2. **Per-target trees** (done): `generated/<target>/` outputs for every app; OpenFL, headless, JUCE (own `.hxml` per plugin) and Rack builds use their own tree; the shared generated directories are retired.
3. **Repetition** (done): `:repeat`, `{n}`, palettes; TimeSlider's model moves to an abstract 0..1 lane space and becomes 4 lanes in Rack and 8 in the VST (and OpenFL, which the VST follows). State v5 stores lane values; older pixel states convert on load.
4. **Remaining apps**: Gbloink now uses `apps/gbloink/`, including its JUCE-only Visual effects toggle and Rack schema. TileLand and Zewp now use `apps/tileland/` and `apps/zewp/`: each has a fixed world declared in `app.edn` (`:model {:world-width .. :world-height ..}`, generated as `<App>ModelGenerated` and `metadata::<app>::model`) rather than taking its size from the panel, and its Rack panel (controls, sockets, outlined text) is generated. Move Goldenpond and K-Diagram to `apps/` and retire the remaining `layouts/` sources.
5. **Check**: the build fails if model code imports a `*LayoutGenerated` class.

Until phase 4 completes, `generate.ps1`/`generate.sh` handle migrated apps from `apps/` and not-yet-migrated apps from `layouts/`, so the build commands in `BUILD_INSTRUCTIONS.md` are the same for every app throughout.

## 9. Open questions

- When the VST needs something OpenFL cannot offer (or vice versa), does that go in `juce.edn` as an exception, or should both inherit from a shared `desktop` overlay?
- Should Rack's hand-placed C++ widgets (e.g. K-Diagram's knobs) move to generated Rack layouts as part of phase 4, or separately?
- Is a state conversion script (e.g. 8-lane VST → 4-lane Rack) worth providing, and if so, which direction?
