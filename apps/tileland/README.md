# TileLand app definition

`app.edn` owns the model: its fixed 600 × 600 world of 50-unit tiles (`:model`), the cursor
palette (red, green, blue) and the controls. `openfl.edn`/`openfl.layla` own the desktop panel;
`juce.edn` inherits it (there is no TileLand VST yet). `rack.edn`/`rack.layla` own the Rack
panel, with `:generate-views false`: the generator writes the model code, the panel SVG (text
outlined to paths) and the widget positions.

The model never sees a layout: `TileLandSequencer` takes its world and grid from
`TileLandModelGenerated`, and Rack's play area maps onto `metadata::tileland::model`.
Speed control IDs follow each target's order, so they are listed (`SPEED_UIDS`,
`ControlIds::speedUid`), not computed from a base.

Target differences:
- Rack outputs each cursor's X and Y as CV; the patch-bay groups are coloured as the cursors.
- Rack's old Display-rate parameter stays configured for saved patches but has no knob; nothing read it.

Generate before building: `./generate.ps1 -App tileland -Target all`.
