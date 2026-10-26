---
id: 9
title: "Show Goldenpond compile errors with a subtle piano-roll border"
status: closed
labels: [goldenpond, vcv, haxe-target]
created: 2026-10-22
closed: 2026-10-22
---

When a rhythm or chord pattern has invalid syntax, the user needs a subtle cue
that the latest edit did not compile, while the last valid score remains
visible and playing. Long parser warnings in the OpenFL status area are too
prominent. Keep the error state as a boolean in the visual data passed to the
native UI; draw a faint red outline around the piano roll/play area.

## Comments

### 2026-10-22

Added the compile-error boolean to Goldenpond's shared native visual snapshot
and drew a subtle red border around the play area in Rack and JUCE. OpenFL's
piano roll uses the same error state for its border, and the verbose status
text is suppressed.
