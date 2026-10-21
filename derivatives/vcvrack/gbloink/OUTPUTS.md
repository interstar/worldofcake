# Gbloink Rack Outputs

Gbloink exposes one Rack output row per ball. Each row has a short gate pulse and a held pitch CV.

The current Rack socket metadata pilot is `layouts/rack/gbloink.edn`. It records the same output IDs, labels, voltage laws, and patch-bay geometry so the C++ code, SVG panel, and docs can be checked against one explicit Rack-specific source.

| Row | Ball | Gate output | Note CV output | Socket position |
| ---: | --- | --- | --- | --- |
| 1 | Red | `GATE_BALL1_OUTPUT` / `Gate (red)` | `PITCH_BALL1_OUTPUT` / `CV (red, 1V/oct)` | y = 30 mm, x = 198/218 mm |
| 2 | Green | `GATE_BALL2_OUTPUT` / `Gate (green)` | `PITCH_BALL2_OUTPUT` / `CV (green, 1V/oct)` | y = 52 mm, x = 198/218 mm |
| 3 | Blue | `GATE_BALL3_OUTPUT` / `Gate (blue)` | `PITCH_BALL3_OUTPUT` / `CV (blue, 1V/oct)` | y = 74 mm, x = 198/218 mm |

## Voltage Mapping

- Gate outputs use Rack-style 0 V / 10 V gate pulses.
- Note CV outputs use 1 V/oct pitch voltage from the current held MIDI note for that ball.
- Pitch voltage is calculated as `(midiNote - 60) / 12`, so MIDI note 60 is 0 V.

## WoC Event Mapping

Gbloink produces note-style WoC events. Rack drains those events, routes each event to the corresponding ball row, pulses that ball's gate output, and updates that ball's held pitch CV.

This file should stay in sync with:

- `layouts/rack/gbloink.edn`
- `derivatives/vcvrack/gbloink/src/Gbloink.hpp` `OutputIds`
- `derivatives/vcvrack/gbloink/src/Gbloink.cpp` `configOutput()` and socket placement
- `derivatives/vcvrack/gbloink/res/Gbloink.svg` patch-bay labels and placeholder circles
