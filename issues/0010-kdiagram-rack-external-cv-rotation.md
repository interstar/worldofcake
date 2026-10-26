---
id: 10
title: "Add external CV control for KDiagram rotation in Rack"
status: open
labels: [kdiagram, vcv]
created: 2026-10-22
---

KDiagram in VCV Rack should accept an external CV input that controls the
diagram's rotation. This would let a patch modulate the network orientation
while the sequencer runs.

KDiagram already rotates through `rotateNetwork(deltaAngle)` on the control
thread, driven by its rotate controls. Rack's audio `process()` is where input
voltages are read, but it must not call Haxe or block on control work.
`ControlRunnerBase` already has a bounded SPSC host-command queue from host
processing to the control thread, and Rack KDiagram uses it for changed
parameter values. Continuous CV needs a rate-safe/coalescing handoff so that
per-sample voltage changes do not flood this finite command queue. Apply the
resulting rotation through the model's control-thread API.

The voltage-to-angle mapping and how CV combines with manual rotation remain
to be decided. The visual snapshot should continue to reflect the resulting
orientation.

## Comments

### 2026-10-22

Confirmed that `ControlRunnerBase` owns `hostCommands`, an SPSC ring buffer of
64 `ControlCommand` slots (63 usable), consumed by `applyPendingCommands()` on
the control thread. Rack's KDiagram `process()` submits changed values through
`enqueueHostCommand()`. JUCE Goldenpond's `processBlock()` does not use this
queue for incoming MIDI: it looks up corrected pitches in an atomic correction
table and emits transformed MIDI. `ControlCommand` currently has no MIDI-input
command kind, and no incoming MIDI events are posted to the sequencer model on
the control thread.

For continuous CV, prefer a shared fixed-size latest-value input mechanism in
the common C++ bridge rather than an app-specific queue. A one-value atomic
mailbox is sufficient for one scalar input; a common sequencer-facing contract
may be useful for mapping those inputs into model controls. Keep latest-state
CV separate from ordered MIDI/event input, where dropping intermediate events
would change behavior.
