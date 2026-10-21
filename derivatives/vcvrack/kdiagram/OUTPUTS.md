# KDiagram — outputs

The Rack socket metadata for this module is `layouts/rack/kdiagram.edn`. It records output IDs, labels, voltage laws, and patch-bay geometry for checker/generator use.


**44 HP** panel: **four** jacks per cursor row (red / green / blue), left → right:

| Jack | Signal |
|------|--------|
| **G** | **Gate** — short pulse when that cursor **arrives** at a node (same as the core’s note event). |
| **Y** | **CV** — continuous **vertical** position; local **−1…1** mapped to **0…10 V** (`(y+1)*5`). |
| **X** | **CV** — continuous **horizontal** position; same mapping. |
| **N** | **Pitch CV** — whenever **G** fires, this output takes the note pitch explicitly calculated by the Haxe sequencer and holds it as **1 V/oct** until the next arrival on that cursor. |

The Haxe sequencer exposes both **cursor position** and **per-arrival note events**. Continuous X/Y match the CC logic in `advanceTime`; note CV uses `NoteCalculator`, mapping the normalized KDiagram play-area height onto the shared WoC note range and selected scale.
