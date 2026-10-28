# TileLand (VCV Rack) — outputs

The Rack socket metadata for this module is `apps/tileland/rack.edn` (with `apps/tileland/app.edn`). It records output IDs, labels, voltage laws, and patch-bay geometry for checker/generator use.


The Haxe core emits **`Event` type `1`** (CC-style): `data1` = MIDI channel (cursor 1…3), `data2` = controller **1** (X) or **2** (Y), `data3` = value **0…127** (position mapped across the play area).

Rack maps each stream to **0…10 V** linearly: `voltage = (value / 127) × 10`.

| Jack   | Source                         |
|--------|--------------------------------|
| Ch1 X  | Channel 1, CC #1 (cursor red)  |
| Ch1 Y  | Channel 1, CC #2             |
| Ch2 X  | Channel 2, CC #1 (green)       |
| Ch2 Y  | Channel 2, CC #2             |
| Ch3 X  | Channel 3, CC #1 (blue)        |
| Ch3 Y  | Channel 3, CC #2             |

There are **no gates**; outputs are continuous CV updated as CC events are drained from the logical-time queue.
