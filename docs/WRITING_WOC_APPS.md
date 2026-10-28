# Writing WorldOfCake Apps

This is the definitive guide to writing a WorldOfCake (WoC) app: the model, how an app is described (EDN and Layla), what the generators make from that description, how each target presents it, how Rack panels are made (including their text), and how everything is built. Other documents go deeper on one part and are linked where relevant; where they disagree with this guide, this guide wins and they should be corrected.

| Topic | Deeper reference |
| --- | --- |
| Core contracts, threading, native boundary | [`architecture.md`](architecture.md), [`threading.md`](threading.md) |
| Why apps and targets are shaped this way | [`APP_TARGETS.md`](APP_TARGETS.md) |
| Toolchains and exact build commands | [`BUILD_INSTRUCTIONS.md`](BUILD_INSTRUCTIONS.md), [`WINDOWS_DEVELOPMENT.md`](WINDOWS_DEVELOPMENT.md) |
| Rack C++ pitfalls (hxcpp, `process()`, Makefiles) | [`GUIDE_ADAPTING_WOC_TO_VCV_RACK.md`](GUIDE_ADAPTING_WOC_TO_VCV_RACK.md) |

---

## 1. Principles

These decide every question below.

1. **Anything that can be in Haxe is in Haxe.** The model, its rules, its state, its event generation and conversions (e.g. 0..1 to MIDI CC) are Haxe. C++ is for host glue and audio-rate work only.
2. **Metadata decides structure and shape at build time.** What controls exist, how many lanes, colours, labels, ranges and layout come from EDN and Layla, rendered by generators. Code does not hard-code them.
3. **Models work in an abstract space, never in panel geometry.** A model knows lane values 0..1, or a fixed world size declared in `app.edn`; it never imports generated layout classes. Views map between their panel and the model's space.
4. **Panels are MVC views.** They read the model (or its snapshot) and send commands; they hold no musical state of their own.
5. **One look.** Light chrome, the same component styles, red/green/blue for an app's first three voices, across OpenFL, JUCE and Rack.
6. **JUCE follows OpenFL** as closely as possible. Rack differs where Rack's conventions require (sockets, size, no MIDI).
7. **Layla stays static.** No templating or overlays in Layla; variation lives in EDN overlays and in one `.layla` per target that needs it.
8. **Saved state is per target.** A target with a different shape (e.g. 4 lanes rather than 8) loads what fits.

---

## 2. Anatomy of an app

```text
Source/<app>/                    Haxe model (sequencer) and OpenFL views
Source/worldofcake/              shared core: SequencerCore, ISequencer, Event, ControlOutput, UI widgets
bridge/haxe/worldofcake/bridge/  <App>Harness.hx: the model's surface for native hosts
bridge/native/                   <App>ControlRunner.{h,cpp}: control thread, queues, snapshots
apps/<app>/                      the app's description: app.edn + per-target overlays and layouts
derivatives/openfl/              project-<app>.xml (OpenFL desktop build)
derivatives/juce/<plugin>/       JUCE editor and processor, own .hxml
derivatives/vcvrack/<app>/       Rack module: src/, plugin.json, Makefile, generated/<Slug>.svg
generated/<target>/              generated code per target (gitignored build output)
```

Apps not yet migrated keep their description in `layouts/openfl/<app>.{edn,layla}` and `layouts/rack/<app>.{edn,layla}`; the build handles both shapes. New apps always go in `apps/`.

---

## 3. The model (Haxe)

A model is a class extending `worldofcake.SequencerCore`, implementing `ISequencer` and `ISequencerControl`.

- **Time.** The host calls `advanceTime(delta)` with seconds; the model advances its logical time and its world. Movement is per second, never per call.
- **Controls in.** Every interactive control has a generated control ID. The model handles `newValue(uid, value)`, `mouseDown/Dragged/Up(uid, LocalPoint)` (in the control's own space), `textSubmitted(uid, text)`, plus `pause`, `resume`, `reset`.
- **Events out.** Notes and CCs are `worldofcake.Event` values with an `EventType` (`NoteOn`, `ControlChange`, `NoteOff`), queued for the host to schedule.
- **Control outputs.** Continuous values 0..1, declared in EDN `:outputs` and published with `setControlOutput(index, value)`. `SequencerCore` sends a MIDI CC (on the output's channel and CC number) whenever the 7-bit value changes. Hosts also present each output as a VST parameter (JUCE) or 0..10 V CV (Rack).
- **State.** `exportStateJson()` / `importStateJson()` with a `"v"` version. Persist model values, never control IDs or panel pixels. When the shape changes, bump the version and convert old states on import.
- **Abstract space.** Anything spatial is in the model's own coordinates: a TimeSlider lane is 0 (bottom) .. 1 (top) and a click arrives as (travel-time fraction, target); Gbloink's world is 700×500 local units declared in `app.edn`. The model may import its generated *control IDs* and *model data* (e.g. `TimeSliderTracksGenerated`), never a `*LayoutGenerated` or composition class.

Native hosts reach the model only through `<App>Harness` and `<App>ControlRunner`: the runner owns the Haxe object on its control thread; audio and UI threads exchange bounded commands, snapshots and events with it. See `architecture.md` §11 and `threading.md`.

---

## 4. Describing an app: `apps/<app>/`

```text
apps/<app>/
  app.edn          what the app is, for every target
  openfl.edn       OpenFL overlay (desktop geometry, presentation)
  openfl.layla     OpenFL panel layout
  juce.edn         usually {:extends :openfl} plus VST-only differences
  juce.layla       only if the VST needs a different layout
  rack.edn         Rack overlay: model shape, :generate-views false, Rack panel schema
  rack.layla       Rack panel layout (millimetres)
  README.md        what differs between targets, and why
```

### 4.1 `app.edn`

```clojure
{:generator-version 1
 :application {:id "timeslider" :package "timeslider" :generated-package "generated.timeslider"
               :composition-kind :timeslider
               :composition-class "TimeSliderCompositionGenerated"
               :layout-class "TimeSliderLayoutGenerated"}
 :model {:lanes 4}                                   ; model shape; overlays may change it
 :palettes {:lanes ["0xD4473D" "0x2F9A48" "0x3A74D0" ...]}
 :outputs [{:repeat :lanes :id "lane{n}" :label "Lane {n}" :channel 1 :cc :n}]
 :components {"lane{n}track" {:repeat :lanes :kind :timeslider-track :colour [:palette :lanes] ...}
              "reset" {:kind :button :label "Reset"}
              ...}}
```

`app.edn` holds the musical meaning: components with their ranges, defaults, labels, tooltips and choices; outputs; model parameters; sequencer constants. It holds no pixel geometry.

### 4.2 Overlays and merging

A target's effective config is `app.edn` deep-merged with its overlay chain (`:extends` first):

- maps merge key by key (so an overlay can change one property of one component);
- vectors and scalars replace;
- `nil` removes (e.g. Rack's `"lane{n}channel" nil` drops the MIDI channel selectors);
- `:extends :openfl` makes JUCE start from OpenFL's overlay.

### 4.3 Repetition

An entry with `:repeat :lanes` is expanded once per `n = 1 .. (:lanes :model)`, after merging, so overlays address the template key (`"lane{n}track"`). In each copy, `{n}` in any string becomes `n`, the value `:n` becomes the number, and `[:palette :lanes]` becomes the n-th colour of `:palettes :lanes` (cycling). Copies carry `:repeat-index`. Layla is not templated: each target's `.layla` lists its lanes explicitly.

### 4.4 The model's world and constants

Numbers in `:model` and the lists in `:palettes` become model constants on every target: `<App>ModelGenerated.hx` (`WORLD_WIDTH`, `TILE_SIZE`, `PALETTE_CURSORS`, ...) for Haxe and `metadata::<app>::model` (`kWorldWidth`, `kPaletteCursors`, ...) in `<App>ControlMetadataGenerated.h` for C++. A model with a world of its own (Zewp, TileLand) declares its size there and reads it from `<App>ModelGenerated`, never from a layout:

```clojure
:model {:world-width 600 :world-height 600 :tile-size 50}
:palettes {:cursors ["0xD4473D" "0x2F9A48" "0x3A74D0"]}
:components {"playarea" {:kind :play-area :local-width [:model :world-width] :local-height [:model :world-height]} ...}
```

A component value `[:model k]` is replaced by the model's `k`, so the play area's local space is the model's world without repeating the numbers. Each view maps its own rectangle onto that world (OpenFL's `PlayArea`, Rack's `Play` widget via `metadata::<app>::model`).

### 4.5 Model-only targets

`:generate-views false` (Rack) generates only model code for that target: control IDs, control metadata and model data, from the resolved config without a layout. Control IDs are then in *model order*: plain components by ID, then repeated components lane by lane. Control IDs may therefore differ between targets; they never cross targets.

---

## 5. Layla layouts

A `.layla` file is a tree of rows and columns with relative weights:

```text
[ ... ]            column: children stacked top to bottom
< ... >            row: children left to right
id/kind            a leaf: component id (must exist in the EDN) and a Layla kind
(w)                weight, relative to siblings; fractions allowed: (31/4)
%label             names a container so the EDN can configure it (e.g. as a :box)
```

Example (TimeSlider OpenFL, abbreviated):

```text
<
  [lane1label/textinput(28) lane1track/timeslidertrack(454) lane1channel/semanticselect(26) lane1cc/semanticselect(26)]
  ...
  [controls-gap/spacer(10) reset/button pause/toggle](32)
>
```

Rules:

- Every leaf id needs an EDN component; every EDN component must appear in the layout (or be a labelled container). The generator reports both.
- Spacers are components too (`{:kind :spacer}`).
- Geometry comes from the EDN `:geometry`: `:panel-width/:panel-height`, `:outer-padding` or per-side `:padding-*`, `:root-gap`, `:nested-gap`, `:gaps-by-depth`. Rack layouts are in millimetres; desktop layouts in panel units (the window scales them).

---

## 6. Components (desktop targets: OpenFL and JUCE)

| `:kind` | What it is | Common keys |
| --- | --- | --- |
| `:play-area` | the model's interactive world | `:local-width :local-height` (or `:local-min/max-x/y`) |
| `:knob` | rotary value | `:minimum :maximum :default :mapping (:linear/:logarithmic) :colour :label :show-label :tooltip` |
| `:slider` | linear value | `:minimum :maximum :default :vertical :colour` |
| `:semantic-select` | one of a set of choices | `:choices [{:value :label :colour}]` or `:choice-range {:from :to :format}`, `:default-index`, `:presentation "compact"` |
| `:button` | momentary | `:label :icon :colour` |
| `:toggle` | on/off | `:label :icon :default` |
| `:text-input` | text the model keeps | `:label :default :tooltip` |
| `:timeslider-track` | a TimeSlider lane | `:colour :label-control :channel-control :cc-control` |
| `:text` | static panel text | `:text :colour` |
| `:spacer` | empty space | |
| `:box` | (labelled containers only) a card behind a group | `:fill :fill-alpha :border :border-alpha :padding` |

Icons (`:icon` = `:reset :pause :mute :walls :rotate-cw :rotate-ccw :lozenge`) come from one shared set (`laylagen/.../icons.clj`) drawn identically by OpenFL, JUCE and the Rack SVG. `:view-hook` names an OpenFL view method that builds a custom widget for a component (e.g. TimeSlider's `addChannelSelect`).

`:outputs` entries: `{:id :label :channel 1..16 :cc 0..127}`.

---

## 7. What the generator makes

The generator is Clojure (`laylagen/`), vendored as `vendor/layla/worldofcake-laylagen.jar`. For each app and target it writes into `generated/<target>/`:

| File | Language | Used by |
| --- | --- | --- |
| `<App>ControlIdsGenerated.hx` / `.h` | Haxe / C++ | model, harness, hosts: one ID per interactive component |
| `<App>ControlMetadataGenerated.h` | C++ | JUCE and Rack: labels, ranges, choices, colours, outputs (`kControlOutputs`), icons, lanes (`kLanes`) |
| `<App>ModelGenerated.hx` | Haxe | model: `:model` numbers (world size, counts) and `:palettes` |
| model data, e.g. `TimeSliderTracksGenerated.hx` | Haxe | model: lane count, track IDs, colours, constants |
| `<App>LayoutGenerated.hx`, `<App>CompositionGenerated.hx` | Haxe | OpenFL views only: rectangles and widget construction |
| `juce/<app>/LayoutGenerated.h` | C++ | JUCE editor: rectangles, boxes, lane regions |
| `rack/<app>/<App>RackLayoutGenerated.h` | C++ | Rack widget: play area, control centres, socket positions |
| `rack/<app>/<App>RackOutputsGenerated.h` | C++ | Rack: output labels and voltage laws |
| `derivatives/vcvrack/<app>/generated/<Slug>.svg` | SVG | Rack panel artwork |

Everything generated is deterministic; `-Check` verifies without writing. Generated files are never edited by hand.

---

## 8. Views per target

- **OpenFL** (`Source/<app>/`): a View built from the generated composition, drawing from the model; widgets in `Source/worldofcake/ui/` (Chrome, Knob, Button, Toggle, SemanticSelect, TextInput, PanelBox, PanelText, IconPainter).
- **JUCE** (`derivatives/juce/<plugin>/`): the editor positions JUCE components from `LayoutGenerated.h` and labels them from the metadata, styled by `derivatives/juce/common/WocJuceEditorSupport.h` to match OpenFL. It polls snapshots (30 Hz) and sends runner commands. Control outputs become VST parameters (`WocJuceControlOutputs.h`) and MIDI CCs.
- **Rack** (`derivatives/vcvrack/<app>/src/`): panel artwork is the generated SVG; the C++ widget adds Rack params, sockets and the play-area widget at generated positions, draws the play area from the visual snapshot, and maps outputs to voltages. See §9.

---

## 9. Rack panels

### 9.1 Sources

`rack.edn` carries, besides the model overlay (`:model`, `:generate-views false`, removals), Rack's panel schema:

```clojure
:module {:slug "Gbloink" :plugin "WorldOfCake-Gbloink" :panel {:width-mm 243.84 :height-mm 128.5 :fill "#f1efea"}}
:geometry {:panel-width 243.84 :panel-height 128.5 :outer-padding 4.0 :root-gap 2.0 :nested-gap 0.0}
:rack-components {"title"    {:kind :title :text "GLR : Gbloink!" :font-size-mm 3.8}
                  "playarea" {:kind :play-area}
                  "red"      {:kind :box :fill "0xD4473D" :fill-alpha 0.16 :border "0xD4473D" :border-alpha 0.55}
                  "redspeed" {:kind :knob :label "Red speed"}
                  "reset"    {:kind :button :label "Reset" :caption-position :below :font-size-mm 2.1}
                  "speed-heading" {:kind :text :text "Speed" :font-size-mm 2.7}
                  "patchbay" {:kind :patch-bay}
                  ...}
:patch-bay {:title "Outputs" :bounds-mm {...} :columns [...] :groups [{:label "Red ball" :outputs [...]}]}
```

- Panel height is always 128.5 mm (3U); width a multiple of 5.08 mm (1 HP).
- `rack.layla` lays out the panel in millimetres: `title`, `playarea`, control groups, `patchbay`, spacers.
- Sockets: each patch-bay output has `:cpp-id`, `:socket-mm`, `:config-label` and a `:voltage-law` (`:gate-10v-pulse`, `:pitch-1v-oct`, `:velocity-10v`, `:midi7-unipolar-10v`, ...).
- Rack lanes and voices are CV, not MIDI: Rack overlays remove MIDI-only controls (channel/CC selectors).

### 9.2 C++ widget conventions

- Positions come from `<App>RackLayoutGenerated.h` (`kPlayarea`, `k<Control>Center`, `kOutputPositions`); never hard-code millimetres.
- Colours come from the generated metadata (e.g. `kLanes[i].track->colour`).
- `static_assert` that socket counts and lane counts agree with the metadata.
- Text that changes at run time (TimeSlider lane labels, values) is a Rack widget (`ui::TextField`, nanovg) fed from snapshots. Static panel text is never drawn in C++: see §9.3.

### 9.3 Panel text: flattened to SVG paths at build time

**Decision.** All static Rack panel text (titles, headings, control captions, patch-bay headers, group labels) is converted to vector outlines by the generator and written into the panel SVG as `<path>` elements. Rack modules contain no C++ for static text, and the result does not depend on any font installed on the user's machine.

**Why.** Rack renders panels with nanosvg, which draws shapes and ignores `<text>`. Commercial and VCV modules ship text already converted to outlines (Inkscape's *Object to Path*). Our generator does the same conversion automatically, so labels stay in the EDN and the SVG stays the complete panel. Drawing text at run time with nanovg (the interim `:native-labels` approach used by Gbloink) works, but needs a `draw` override per module and keeps part of the artwork outside the SVG.

**Font.** DejaVu Sans, the font Rack itself uses for its UI, so panels match Rack and the look approved for Gbloink. The file is vendored at `vendor/fonts/DejaVuSans.ttf` with its licence (`vendor/fonts/DejaVuSans-LICENSE.txt`, copied from the Rack SDK's `res/fonts/`) and a `.sha256` like the generator JAR. The generator loads that file only; it never asks the system for a font.

**How the generator converts a label.** In `laylagen/src/worldofcake/laylagen/rack_layout_generate.clj` (a `text-path` function in a small `svg_text.clj` namespace):

1. Load the font once: `java.awt.Font/createFont Font/TRUETYPE_FONT` from the vendored file, then `deriveFont` to a **fixed reference size of 1000 units**, with `TextAttribute/KERNING` on and ligatures off. Run with `java.awt.headless=true`.
2. Lay out the text with `Font.layoutGlyphVector` and a `FontRenderContext` with an identity transform, antialiasing on and fractional metrics on. Working at 1000 units keeps outlines free of hinting and pixel rounding; generating directly at 2–4 mm would distort them.
3. Measure: advance width from the glyph vector's logical bounds; cap height from the outline bounds of `"H"` (computed once per font).
4. Place: scale = `font-size-mm / 1000`. Horizontal anchor from the label's `:anchor` (`:middle` by default; `:start` for titles and beside-captions unless the EDN says otherwise; WoC panels give their title `:anchor :middle`, centred between the screws), so `x0 = x - width × scale` × {0, ½, 1}. Vertically, labels are positioned by their visual centre: `baseline = y + capHeight × scale / 2`.
5. Get the outline with `GlyphVector.getOutline`, apply the `AffineTransform` (scale, translate to `x0`, `baseline`), and walk it with a `PathIterator` (no flattening): `SEG_MOVETO` → `M`, `SEG_LINETO` → `L`, `SEG_QUADTO` → `Q`, `SEG_CUBICTO` → `C`, `SEG_CLOSE` → `Z`.
6. Format coordinates with `Locale/ROOT` and **3 decimals** (0.001 mm), so output is byte-identical on every machine.
7. Emit one element per label: `<path id="text-<component-id>" data-text="Red ball" fill="#3a3f48" d="M…Z"/>`, inside `<g id="panel-text">`. `fill-rule` is the default (nonzero), which matches TrueType outlines and nanosvg.
8. If the font lacks a glyph for a character (`Font.canDisplayUpTo`), generation fails with the label and character, rather than drawing a box.

**What becomes path text.** Every label the Rack schema defines: `:title` (`:text`, `:font-size-mm`, `:anchor`), `:text` components, control captions (`:label` with `:caption-position`, default beside, `:below` under the control), patch-bay `:title`, column `:label`s and group `:label`s. Colours: `#3a3f48` by default. Per label, `:text-colour` overrides the colour and `:anchor` (`:start`, `:middle`, `:end`) the alignment. A control with `:show-label false` gets no caption; give a knob a `:text` heading row above it instead (captions beside a knob would sit under it). Buttons and toggles use `:caption-position :below` with `:font-size-mm 2.1`.

**What it replaces.** The generated SVG contains no `<text>` elements. `:native-labels` and the `kPanelLabels` table are retired, and Gbloink's `GbloinkWidget::draw` label loop is deleted. A generator test asserts that no Rack SVG contains `<text`, and that a known label produces the same path data twice.

**Status.** Implemented in the shared Rack generator. Gbloink uses outlined SVG text and no static-text C++ override. Other Rack panels gain outlined text when regenerated with the updated bundled generator. The vendored font and its licence/checksum are required build inputs; installed modules need only the generated SVG.

---

## 10. Building

Every build is **generate, then compile**, and each target compiles against its own generated tree.

```powershell
.\generate.ps1 -App all -Target all          # or -App timeslider -Target rack
.\generate.ps1 -Check                        # verify generated files are current
.\build-headless.ps1 -Target interp          # model tests
.\run-openfl-preview.ps1 -App <app> -BuildOnly
.\derivatives\juce\build-windows.ps1 -Plugin <Plugin> -Target WorldOfCake<Plugin>_All
.\derivatives\vcvrack\build-rack-windows.ps1 -Module <app> -Install
```

`generate.sh` and the Linux scripts mirror these. When changing the generator, use `run-laylagen.ps1 -Task generate|check|test` (runs from Clojure source), then rebuild the JAR with `laylagen/package-worldofcake-laylagen.sh` and update its `.sha256`. Exact toolchains and outputs: [`BUILD_INSTRUCTIONS.md`](BUILD_INSTRUCTIONS.md).

---

## 11. Adding a new app: order of work

1. **Model**: `Source/<app>/<App>Sequencer.hx` on `SequencerCore`, in an abstract space; headless tests in `Source/test/`.
2. **Description**: `apps/<app>/app.edn`, `openfl.edn` + `openfl.layla`; generate; build the OpenFL preview with its View.
3. **Native surface**: `<App>Harness.hx` and `<App>ControlRunner` (snapshots carry what views draw).
4. **VST**: `juce.edn` (`{:extends :openfl}`), editor and processor from generated layout and metadata.
5. **Rack**: `rack.edn` (model overlay, `:generate-views false`, panel schema) + `rack.layla`; module `src/` using generated positions; panel text in EDN, never in C++.
6. **Docs**: `apps/<app>/README.md` (target differences), `OUTPUTS.md` beside the Rack module.

---

## 12. Checklist of rules

- [ ] No model code imports `*LayoutGenerated` or composition classes.
- [ ] No hard-coded control IDs, counts, colours, labels or millimetres in host code; use generated headers.
- [ ] Persisted state stores model values with a version; old versions convert.
- [ ] First three voices are red `0xD4473D`, green `0x2F9A48`, blue `0x3A74D0`.
- [ ] Static Rack text lives in `rack.edn` and reaches the panel as SVG paths.
- [ ] Generated output is never edited; `generate -Check` passes before a build is called done.
