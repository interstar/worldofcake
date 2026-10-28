# Zewp app definition

`app.edn` owns the model: its fixed 600 × 560 world (`:model`), the zewp colour palette
(red, green, blue first) and the controls. `openfl.edn`/`openfl.layla` own the desktop panel;
`juce.edn` inherits it (there is no Zewp VST yet). `rack.edn`/`rack.layla` own the Rack panel,
with `:generate-views false`: the generator writes the model code, the panel SVG (text outlined
to paths) and the widget positions.

The model never sees a layout: `ZewpSequencer` takes its world from `ZewpModelGenerated`, and
Rack's play area maps onto `metadata::zewp::model::kWorldWidth/kWorldHeight`.

Target differences:
- Rack outputs six zewps as X, Y and an in-front gate; each patch-bay group is coloured as its zewp.
- Rack's Speed knob keeps its original 1/3 .. 1.5 range so saved patches load unchanged.

Generate before building: `./generate.ps1 -App zewp -Target all`.
