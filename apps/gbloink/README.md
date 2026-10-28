# Gbloink targets

`app.edn` defines the shared musical controls and the 700x500 playfield's local
dimensions. `openfl.edn` adds desktop presentation. `juce.edn` inherits it and adds
the editor-local Visual effects toggle; `juce.layla` reserves its control-panel
space. `rack.edn` generates model/control metadata without OpenFL views, plus
Rack's panel and sockets from `rack.layla`.

Generate explicitly before compiling:

```powershell
.\generate.ps1 -App gbloink -Target all
.\generate.ps1 -App gbloink -Target all -Check
```

Each target compiles its Haxe control IDs and native metadata from the same
`generated/<target>/` tree. Numeric IDs can differ between targets; persisted
Gbloink state stores model values rather than control IDs.

GPU trail history, ripples and block flashes remain renderer-owned. Their shared
decay shader is maintained at `Source/worldofcake/visuals/TrailDecay.glsl.inc`;
it is embedded at build time and needs no runtime asset installation. Collision
cues travel in the native visual snapshot. Resizing changes the panel mapping,
not the model's local dimensions or the effects' logical coordinate system.

The VST's single Visual effects toggle is presentation state, not a musical
command or an audio parameter. It keeps the medium trail half-life (0.22 s),
350x250 history textures, note-linked ripples and targeted block flashes.
OpenFL's GPU preview remains enabled with `-D woc_gpu_trails`.

The Rack panel mirrors the desktop's Speed/Volume columns, three colour cards
and grouped lower controls. Its voice rows align with the nine existing output
sockets. The panel keeps its 48 HP width and an undistorted 700:500 playfield.
The generator outlines the EDN-derived panel labels using the vendored DejaVu
Sans font. Static text lives entirely in the panel SVG; module C++ only draws
the live playfield and host widgets. Label anchors retain the approved layout.
