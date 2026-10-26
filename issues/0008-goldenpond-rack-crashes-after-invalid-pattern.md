---
id: 8
title: "Goldenpond Rack crashes after correcting an invalid rhythm pattern"
status: open
labels: [goldenpond, vcv]
created: 2026-10-22
---

## Reproduction

1. Run Goldenpond in VCV Rack with a working rhythm pattern.
2. Add a semicolon to a rhythm pattern so it has invalid syntax.
3. Correct the pattern, then turn a velocity or octave knob.
4. Rack closes completely.

The sequencer should tolerate the invalid edit: keep playing and displaying the
last syntactically valid score until a complete valid replacement is available.
Correcting the pattern and adjusting a knob should not crash Rack.

## Findings

The Rack log records a fatal signal 11. The stack includes
`GoldenpondControlRunner::publishVisualSnapshot()` and resolves to native note
snapshot construction (`std::vector<GoldenpondNoteSnapshot>::push_back`,
`GoldenpondControlRunner.cpp`, around line 97). Haxe note accessors are also in
the trace. This identifies the failing path, but does not yet establish the
underlying cause.

The temporary native snapshot copies the Haxe score's notes one at a time.
Further investigation should determine why this copy can fault after an invalid
pattern is corrected and a velocity or octave control is changed.

## Comments

### 2026-10-22

Compilation now preserves the active score, timing, and queued events when a
new score fails to compile. Native snapshot collection also reads the note
count once before copying. The crash still needs to be reproduced against the
updated build; neither change is confirmed as the crash fix.
