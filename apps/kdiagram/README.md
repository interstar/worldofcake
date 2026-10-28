# KDiagram app definition

`app.edn` owns shared controls and outputs. `openfl.edn` owns presentation;
`juce.edn` inherits it, with a wider 900-unit desktop panel and a VST-specific
`juce.layla` placing Terminus in the five-button bottom row as a lozenge icon. Rack owns its physical panel in `rack.edn` and
`rack.layla`, with `:generate-views false` for model-only Haxe generation.

Generate before building: `./generate.ps1 -App kdiagram -Target all`.
The bundled JAR supports this migration; use `-Check` to verify generated files.

Node score symbols are: circle=0, triangle=1, square=2, terminus=3.
Ordinary shapes are chosen randomly; one designated terminus is drawn as a
flattened diamond, even when disabled. Types persist through native snapshots
and patch state (v3). Older patches promote their first sink, or node 0 if none.
On arrival, circles continue immediately and use the Note length control.
Triangles wait 2-4 seconds; squares wait 4-8 seconds. A fresh random duration
is chosen on each arrival. Triangle notes last 0.5-1 second; square notes last
1-2 seconds, chosen independently of the wait.
Remaining wait time is saved per cursor; pause freezes it, and mute leaves
the timing running. Initial placement and clicking a node start travel directly.

New networks use best-candidate placement: each node after the first selects
the most separated of 100 uniform-area disk samples, within 92% of the circle
radius. Existing patches retain their saved positions; Reset generates a new
network with the wider spacing.

Terminus defaults to on: the diamond has no exits. Off adds exactly one exit
to node 0 (or node 1 when the diamond is node 0) and resumes stranded cursors.
Toggling never redesignates the diamond or changes other connections. The
diamond has no residence time and uses the circle note length. The model owns
and saves this setting; Reset generates a new network respecting the setting.

OpenFL, JUCE and Rack draw the network as dark ink on warm paper, retaining
small colored performers for voice identification. No textures or history
buffers are needed for this appearance.

## Rack panel

The 44 HP panel follows the desktop reading order: paper score on the left,
red/green/blue speed cards and a shared control card beside it, then outputs.
All control centres, the play-area rectangle and socket positions come from
`rack.layla` / `rack.edn` and the generated Rack layout header. Static text is
outlined into the generated SVG with the vendored DejaVu Sans font.

The Rack target has no MIDI-channel or Display rate widget. Model channels
remain internal event routing (including restored patches). The former Rack
parameter indices are reserved so existing patches keep their parameter IDs.
The old hand-authored `res/KDiagram.svg` is removed and title injection is
explicitly disabled; only `generated/KDiagram.svg` is packaged as panel artwork.

Rotation buttons and keyboard shortcuts use the same Haxe commands: left is
anticlockwise in the Y-up model, right is clockwise. Native adapters forward
those commands rather than maintaining their own angles or rotation signs.
