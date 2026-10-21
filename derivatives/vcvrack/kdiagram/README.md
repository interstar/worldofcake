# World of Cake — KDiagram (VCV Rack 2)

Linux-first Rack module wrapping `kdiagram.KDiagramSequencer` from `Source/kdiagram/`.

## Build

```bash
export RACK_DIR=/absolute/path/to/Rack-SDK
make
```

`make install` copies into `~/.local/share/Rack2/plugins/WorldOfCake-KDiagram/` (Rack 2 Linux). Panel is **44 HP**; see `OUTPUTS.md` for the four jacks per cursor.

## Controls

- **Play area:** click a node to jump the **active** cursor (see switch) and resume walking the graph (same local space as OpenFL: about **−1…1**).
- **SPD (×3):** cursor travel speed (`0.1`…`8`, same as OpenFL sliders).
- **CH:** MIDI base channel **1…14** (cursors use `base`, `base+1`, `base+2`).
- **1 / 2 / 3 switch:** which cursor receives play-area clicks.
- **SIM / RST / RUN-Pause:** physics cadence and `ISequencer` transport; reset rebuilds the random network.
- **⟲ / ⟳:** rotate graph and cursors (same step as `[` / `]` in the desktop app).

## Haxe

`haxe/kdiagram.hxml` compiles `worldofcake.bridge.KDiagramHarness` with `-cp ../../../Source` and `-cp ../../../bridge/haxe`.
