# World of Cake panel editor

For launch instructions and a walkthrough, see [How to use the editor](HOW-TO-USE.md).

A local browser editor for the canonical `layouts/openfl/*.layla` and companion
EDN files. It renders static panels with Canvas 2D, without Haxe or OpenFL in
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

Requires Java 17+, the Clojure CLI, and the canonical Layla checkout. The default
checkout is `G:\PRODUCTION\MAIN_PROJECTS\language_oriented\langdev\layla`;
override with `-LaylaRoot <path>`. The launcher uses that checkout's `.cljc`
parser for both JVM and browser builds. The bundled WoC generator JAR provides
Instaparse and the production geometry reference for tests. ClojureScript
1.11.132 and its compiler dependencies are resolved through the user's Maven
cache; an initial download may be required. No Node server is needed.

For other platforms, from this directory, add the canonical Layla `src` directory
to the classpath using a CLI alias with `:extra-paths`, then run `clojure -M:build`
and `clojure -M:serve`. Without that extra path, the parser bundled in WoC's JAR
is used.

## Workflow

Select an app and edit its Layla or EDN tab. Preview updates after a short pause.
Save pair (Ctrl/Cmd+S) explicitly writes both canonical source files. Nothing is
written while typing. Invalid edits disable Save, show diagnostics and an orange
outline, and retain the last valid preview. Switching panels or reloading prompts
before discarding unsaved edits; leaving the page triggers the browser warning.

The server detects external changes to either file and refuses to overwrite them.
If a save conflict occurs, copy your edits before reloading, then reapply them.
Saves validate both sources first and restore the previous pair if an ordinary
write fails. The two filesystem writes are not a crash-atomic transaction.

Fit displays the design within the preview pane without reflow; 100% uses one CSS
pixel per design unit. Higher-density screens use a matching canvas backing
resolution. Bounds displays the layout rectangles for checking geometry. Panel
widgets are static and display EDN defaults; they do not run the sequencer.

## Fidelity and maintenance

`model.cljc` mirrors production `calculate-geometry`: relative weights, outer and
container padding, depth-specific gaps, and named containers. Regression tests
compare every node against the bundled generator for all six current panels.
The generator source is intentionally ignored/owner-maintained in this repo, so
the editor does not modify it or depend on its untracked working copy. If geometry
rules change upstream, update this module and the parity tests together.

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

## Checks

From this directory:

```powershell
.\run.ps1 -Test
```

Tests cover geometry parity, invalid edits, save roundtrip, UTF-8, and disk conflict
detection. Save tests use a temporary repository and do not edit real layouts.

The JVM server binds only to `127.0.0.1`, serves editor assets, and exposes an app
allowlist for file operations. Save requests require a same-origin editor header;
this is intended for local use, not deployment on a shared/public host.
