# World of Cake panel editor

For launch instructions and a walkthrough, see [How to use the editor](HOW-TO-USE.md).

A local browser editor for World of Cake app definitions and OpenFL panels.
It detects `apps/<app>/app.edn` and uses the migrated sources when present;
otherwise it reads the legacy `layouts/openfl/<app>.layla` and `.edn` pair. It renders static panels with Canvas 2D, without Haxe or OpenFL in
the preview pipeline. Rack panels are outside v1.

## Run on Windows

From the WoC repository root:

```powershell
.\panel-editor\run.ps1
```

Open <http://127.0.0.1:8765>. The first launch compiles ClojureScript. Stop the
server with Ctrl+C. Subsequent launches can use `-SkipBuild`; after changing
editor code, omit that flag to rebuild. `-BuildOnly` compiles without serving.
`-Port 8766` selects another port.

Requires Java 17+ and the Clojure CLI. The bundled WoC generator JAR
(`vendor/layla/worldofcake-laylagen.jar`) provides the Layla `.cljc` parser for
both JVM and browser builds, the target resolver, Instaparse, and the production
geometry reference for tests. ClojureScript 1.11.132 and its compiler
dependencies are resolved through the user's Maven cache; an initial download may
be required. No Node server is needed. `-ExtraSource <dir>,...` puts source
directories ahead of the JAR on the classpath; normal use does not need it.

For other platforms, from this directory, run `clojure -M:build` and
`clojure -M:serve`.

## Workflow

Select an app. Source tabs follow the app's migration status:

- Migrated (`apps/<app>/app.edn` exists): **Layla** edits `openfl.layla`,
  **OpenFL EDN** edits `openfl.edn`, and **App EDN** edits `app.edn`.
  Geometry/presentation normally belong in OpenFL EDN; shared labels, ranges,
  defaults, choices, outputs and model semantics belong in App EDN. Shared edits
  can affect JUCE/VST and Rack too. The filename identifies the actual file.
- Legacy: **Layla** and **EDN** retain the existing `layouts/openfl/` workflow.

Migrated previews are resolved by the build's actual
`worldofcake.laylagen.targets/resolve-target`. Draft sources are staged in a
short-lived temporary directory along with the app's other overlays. The server
resolves inheritance, deep merges, deletions and future resolver expansions there;
the browser uses the resolved config and the real Layla CLJS parser to draw.
There is no second implementation of target merge rules. Previewing never writes
real sources. The source text is saved verbatim, not flattened into merged EDN.

**Save sources** (or **Save pair** for legacy apps), Ctrl/Cmd+S, explicitly writes
changed source files after the merged result validates. Nothing is written while
typing. Migrated saves never touch `layouts/`, even if obsolete copies exist.
Revisions cover every editable file plus the migrated app's overlay/layout
snapshot, detecting inherited dependency changes and migration during editing.
Copy edits before Reload if a conflict occurs. Ordinary write failures trigger
restoration of the old source set; this is not a crash-atomic transaction.

Invalid edits disable Save, show diagnostics and an orange outline, and retain
the last valid preview. Preview requests are debounced, and stale responses are
ignored. Switching panels or reloading prompts before discarding unsaved edits;
leaving the page triggers the browser warning.

Fit scales the design without reflow; 100% uses one CSS pixel per design unit.
Bounds shows layout rectangles. Widgets display EDN defaults, not live model state.

## Generator dependency

The editor uses the target resolver in the bundled JAR
(`worldofcake.laylagen.targets`); it does not copy, fork or modify it. The JAR
changes only with the generator, never through the editor.

## Fidelity and maintenance

`model.cljc` mirrors production `calculate-geometry`: relative weights, outer and
container padding, depth-specific gaps, and named containers. Regression tests
compare every node against the bundled generator for all six current panels.
If the generator's geometry rules change, update this module and the parity tests
together.

`render.cljs` translates the drawing rules in `Source/worldofcake/ui/`: Chrome,
Knob, PanelBox, PanelText, PanelTitle, SemanticSelect, Button/Toggle, Slider, and
TextInput. Vector icons use the same 16×16 operation lists as laylagen. The panel
background matches the OpenFL project files (`0xF1EFEA`). Browser font metrics
and antialiasing can differ from native OpenFL. Text uses Arial as a browser
approximation of OpenFL `_sans`, including clipping rather than auto-shrinking.
Custom play areas are black; TimeSlider lanes use their dark static background.
Status fields are empty. No screenshot assets are required for v1.

The editor is a WoC development tool, not a generic Layla playground. It supports
the same fixed-layout horizontal/vertical/responsive placement as the OpenFL
generator. Grids and pages are rejected with diagnostics. The EDN component map
is authoritative for widget kinds; Layla hints remain language-level hints.

Semantic selects also accept WoC's `:choice-range` EDN shorthand, for example
`{:from 1 :to 16 :format "Ch %d"}`. The editor expands it to explicit choices
before validation and drawing, matching the production generator. This is WoC
metadata processing rather than an extension or fork of the Layla language.

## Checks

From this directory:

```powershell
.\run.ps1 -Test
```

Tests cover resolved geometry parity, legacy and migrated save roundtrips, UTF-8,
inheritance/deletion/vector replacement, and conflicts across all edited sources
and inherited dependencies. Save tests use a temporary repository and do not edit real layouts.

The JVM server binds only to `127.0.0.1`, serves editor assets, and exposes an app
allowlist for file operations. Save requests require a same-origin editor header;
this is intended for local use, not deployment on a shared/public host.
