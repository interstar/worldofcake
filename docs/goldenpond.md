# Goldenpond Integration Notes

Status: OpenFL reference implementation started 15 September 2026. Goldenpond integration is an important near-term World of Cake target. The reusable UI-free sequence-player model, Goldenpond dependency adapter, generated Layla panel, editable inputs, and first piano-roll view are now implemented; Rack/VST hosts remain future work.

## Purpose

Goldenpond is a Haxe library for turning compact chord-oriented text into note material. A World of Cake Goldenpond app should wrap that library in a real sequencer that can run in Rack, VST/DAW hosts, and the usual OpenFL/browser reference environment.

Goldenpond itself is not the sequencer framework. It compiles musical input into note data. World of Cake should own transport, looping, scheduling, persistence, editing behaviour, host output, and target-specific presentation.

## Compiled Pattern Model

Goldenpond starts from chords in its input language, but the reusable playback layer should not know about chords. Goldenpond should publish concrete note events per musical part.

The useful low-level model is:

```text
Pattern
  parts: PartPattern[]

PartPattern
  partId
  channel/output mapping
  loopLength
  notes: Note[]

Note
  pitch: MIDI note number
  start: position within the loop
  duration
  velocity

Goldenpond's concrete notes currently use ticks for `start` and `duration`.
`TimeManipulator.ppq` defines the ticks-per-quarter-note resolution, while
Goldenpond's seconds conversion is derived from PPQ and BPM. The WoC player
therefore uses ticks as its canonical unit and leaves seconds/sample offsets to
host adapters.
```

In existing Goldenpond embeddings, an extra parameter such as `chordDuration` defines how long a chord lasts in host terms. The total generated sequence length is:

```text
loopLength = chordDuration * numberOfChords
```

Goldenpond can use that rule while compiling chord material into note starts and durations. The lower-level World of Cake sequence player only needs the resulting notes and loop length.

## Reusable Sequence Player

The Goldenpond app should drive the creation of a reusable mini-framework inside World of Cake: a multi-part looping note sequence player.

The player should own:

- per-part note lists
- loop length per pattern or part
- host/free-running transport position mapping
- loop wraparound
- note-on and note-off scheduling
- replacement of the active pattern while playback continues
- part/channel/output mapping
- persistence-friendly playback state
- absolute tick transport and snapshot phase origins
- active note-instance tracking so note-offs survive score replacement and
  loop boundaries without releasing unrelated notes

The player should not own:

- Goldenpond parsing
- chord interpretation
- music-theory source structure
- target-specific MIDI, CV, gate, or UI code

This keeps the player useful for any future World of Cake app that produces concrete notes, not only Goldenpond.

## Live Editing And Publication

Text edits should be parsed and compiled away from the audio callback. When compilation succeeds, the control side publishes a complete read-only compiled pattern to the sequence player. The real-time side consumes the latest valid pattern without parsing text, allocating, mutating Goldenpond internals, or entering Haxe from a hard real-time callback.

If parsing fails during live editing, playback should normally continue using the last valid compiled pattern. The UI can show the parse error while the current pattern keeps playing.

This is the intended meaning of "immutable score publication": publish a whole compiled pattern snapshot, then let playback consume that stable snapshot until a newer valid one replaces it. The generic player does not know about chords. The current reference app publishes a successful edit immediately at the current transport position; the player first emits note-offs for active notes, then starts the replacement snapshot there. This keeps editing responsive without allowing invalid partial text to replace the active score.

## Settled Initial Contract

- Every part shares one global loop length.
- A compiled note is represented in WoC as `partId`, MIDI `pitch`, MIDI
  `velocity`, `startTick`, and `durationTicks`.
- `partId` is the canonical identity for a generated line/output. A separate
  channel field is not required in the reusable player; a host adapter may map
  the part to MIDI channels or Rack outputs.
- Notes may extend beyond the loop boundary. The player tracks each active
  note instance and emits its note-off at the original absolute end tick.
- Stop/reset emits note-offs only for active note instances. Rack may map this
  to a gate reset or all-gates-off operation where that is more appropriate.
- The player is a plain Haxe model, not an `IComponent` and not a UI class.
  The future piano-roll component consumes score snapshots and playhead state.
- The Goldenpond app remains an ordinary WoC `ISequencerControl` application.
  It owns text editing, compilation diagnostics, Goldenpond settings, and
  conversion into `SequenceSnapshot`; it delegates playback to the reusable
  player rather than defining a second transport interface.

## Current Implementation

The generic model currently lives in:

- `Source/worldofcake/SequenceNote.hx`
- `Source/worldofcake/SequenceSnapshot.hx`
- `Source/worldofcake/SequenceNoteEvent.hx`
- `Source/worldofcake/LoopingNotePlayer.hx`
- `Source/goldenpond/GoldenpondScoreCompiler.hx`
- `Source/goldenpond/GoldenpondSequencer.hx`
- `Source/goldenpond/GoldenpondWorld.hx`, `GoldenpondView.hx`, `GoldenpondMain.hx`
- `Source/worldofcake/ui/TextInput.hx` and `PianoRoll.hx`
- `Source/test/TestSequencePlayerHeadless.hx`
- `Source/test/TestGoldenpondScoreCompiler.hx`

It exposes tick-based advance, absolute-position event scheduling, loop
wrapping, score publication at an explicitly supplied tick, and active-note
cleanup. `GoldenpondSequencer` is now the application-level `ISequencerControl`
wrapper: it converts WoC elapsed time into Goldenpond ticks and converts player
events back into ordinary WoC `Event` values. Text fields commit on Enter or
focus loss; scalar controls publish immediately. There is no Compile button.

The first OpenFL reference panel is driven by `layouts/openfl/goldenpond.layla`
and `.edn`. It exposes one chord progression input, four fixed rhythm-part
inputs, BPM and chord-duration knobs, transport/compile buttons, and a reusable
OpenFL piano-roll display. The model supports any number of parts; four is only
the first UI/Rack topology decision.

Goldenpond uses normal 1x playback: one wall-clock second corresponds to one
second of musical time at the configured BPM and PPQ. The playback multiplier
is applied consistently to transport advancement, event timestamps, and
correction lookups so those paths cannot drift apart. Host-specific speed
controls can be added later, but the default policy is normal playback.

The Rack adapter uses Rack's sample clock as its native clock. Its control
runner advances the Goldenpond logical clock at the Rack control period, while
prepared events retain their absolute WoC timestamps. The audio-side adapter
keeps a bounded pending-event array and compares timestamps with the sample
clock; it does not call Haxe, take a UI mutex, or discard event timestamps.

Rack also exposes three independent pitch-CV correction inputs and outputs.
Each input uses the same convention as generated Goldenpond pitch outputs:
`0 V` is MIDI note 60 and `1 V/octave`. The control thread asks Goldenpond to
correct all MIDI notes against the chord active at the current logical time and
publishes the resulting 128-entry map as atomic POD values. Rack applies that
map at audio rate, with the map refreshed at the 60 Hz control rate. This is a
global chord service, not a per-part feature, so the three correction channels
are independent of Goldenpond's generated parts.

The generic `ISequencer.correctInputNote()` capability returns its input
unchanged by default. Goldenpond overrides it with `GoldenData.correct()`,
which uses the active chord's scale and optional melodic direction.

`test-goldenpond-linux.sh` is an optional local-source test entry point. It
uses `GOLDENPOND_ROOT` when set, otherwise the expected sibling checkout path.
The main Linux rebuild invokes it only when the Goldenpond source directory is
present and prints a warning otherwise. The Windows headless test wrapper has
the same optional behavior.

## Target Behaviour

VST/JUCE should use the host transport and emit MIDI note events naturally. Chord duration should likely be expressed in host musical units such as beats, bars, or synced divisions.

Rack should adapt the same note facts to Rack idioms: gate/trigger and pitch CV outputs, possibly with multiple pitch/gate pairs or polyphonic outputs. Rack may need internal clocking first, and later external clock/reset inputs.

OpenFL remains the reference UI and behaviour environment. It does not currently generate musical note output, so exact musical timing parity is less important there than layout, interaction, edit flow, and visible playback state.

## Open Design Questions

- Should WoC eventually consume Goldenpond through a versioned Haxelib-style
  source archive? Local development currently uses the configurable source
  path; no Goldenpond code is copied into this repository.
- How should Rack expose parts: multiple mono pitch/gate pairs, polyphonic outputs, or both?
- The application model should support a variable number of parts, but the
  first UI and Rack design use four parts because Rack output topology cannot
  dynamically add sockets.
