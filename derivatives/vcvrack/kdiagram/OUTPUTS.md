# KDiagram outputs

Source: `apps/kdiagram/rack.edn`. The generated header supplies socket labels,
positions and voltage laws; C++ preserves the existing output IDs and order.

The 44 HP panel has three colored cursor rows. Each row has four outputs,
left to right:

- **Gate:** 10 V while that cursor's model note sounds. Note duration follows
  the node shape: the Circle note control, 0.5-1 second for triangles, or
  1-2 seconds for squares. The cursor's longer node wait continues afterward.
- **Y:** continuous vertical position, local -1..1 mapped to 0..10 V.
- **X:** continuous horizontal position, local -1..1 mapped to 0..10 V.
- **Pitch:** the model's scale-corrected arrival note as 1 V/oct, held until
  that cursor's next note.

Pause and transport boundaries release sounding notes. Node timing and the
Terminus setting remain owned by the Haxe model. Rack has no MIDI-channel
widget; channels in a restored model are internal routing only.
