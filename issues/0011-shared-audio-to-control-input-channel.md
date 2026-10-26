---
id: 11
title: "Define a shared audio-to-control input channel for sequencers"
status: open
labels: [bridge, audio, vcv, vst]
created: 2026-10-24
---

Sequencers need a common, real-time-safe way for host audio callbacks to pass
incoming control values or events to the control thread. This should be a
shared bridge/specification mechanism, not a different ad hoc solution for
each app. KDiagram's Rack rotation CV request is the first use case (issue 10,
`issues/0010-kdiagram-rack-external-cv-rotation.md`).

## Current state

`ControlRunnerBase` owns `hostCommands`, a custom fixed-size SPSC ring buffer
of 64 `ControlCommand` slots (63 usable). Host processing publishes commands
with `enqueueHostCommand()`; the control thread drains them in FIFO order via
`applyPendingCommands()`. If the queue is full, `push()` rejects the new
command and the drop counter is incremented. Existing Rack code uses this for
changed host parameter values. The GUI has a separate command queue.

This is not a standard-library queue with a selectable overflow mode. The
standard FIFO containers do not provide this bounded SPSC behavior. The
current ring does not overwrite older entries when full, and its fixed size
alone does not prevent a backlog of stale values.

JUCE Goldenpond's `processBlock()` currently corrects incoming MIDI pitches
using an atomic correction table and emits the transformed MIDI. It does not
post those incoming MIDI events to the sequencer control thread. The shared
`CommandKind` also has no MIDI-input event kind.

## Desired behavior

Define a shared host-audio-to-control mechanism and its data semantics. For
continuous values such as CV, newest-value semantics are appropriate: the
audio thread can publish updates without waiting, and the control thread reads
the latest value when it pumps, skipping intermediate readings rather than
building a stale backlog. A one-value atomic mailbox is the fixed-size case
for one scalar input; multiple independent inputs could use a fixed set of
latest-value slots. Related values that must be coherent need a snapshot
publication mechanism.

Keep continuous latest-state values separate from ordered events such as MIDI
note-on/note-off, where overwriting unread events can change behavior. Define
the event queue's bounded overflow behavior separately.

The common C++ bridge should own transport and thread-safety semantics. Decide
whether sequencers also need a shared input contract (for example, mapping an
input identifier/value to model behavior), while leaving app-specific meaning
such as KDiagram's voltage-to-rotation mapping to the app. Audio callbacks
must remain non-blocking and must not call Haxe.

## Questions to resolve

- Should the shared value channel be a fixed set of atomic slots, a
  double-buffered snapshot, or another bounded latest-value structure?
- How should values be identified and connected to sequencer/model controls?
- What bounded queue and overflow policy should ordered MIDI/control events
  use?
- How should the common mechanism expose diagnostics for dropped events?
