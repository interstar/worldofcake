# Goldenpond Rack Stress Harness

Run the native harness on Linux from the WoC repository root:

```sh
bash test/native/run-goldenpond-rack-stress.sh [seconds] [runner-count]
```

Defaults are 600 seconds and four concurrent `GoldenpondControlRunner`
instances. The script regenerates the same hxcpp code used by the Rack module,
then links the production runner and `ControlThread` into a standalone test
executable under `build/vcvrack/goldenpond/`.

Each runner advances at Rack's 60 Hz control cadence. BPM is changed periodically
to exercise project recompilation and correction-cache invalidation. A separate
audio-consumer thread simulates 48 kHz processing in 64-sample blocks: it reads
all three correction maps and drains prepared note events without calling Haxe.
The harness checks that visual snapshots keep advancing and counts successful
correction-table publications. It exits with failure if a runner stops
publishing snapshots for 15 seconds or publishes fewer than two tables.
To keep a failed process alive for debugger attachment, run with
`WOC_STRESS_HOLD_ON_STALL=1`. The failure line prints its PID; then capture
threads with `sudo gdb -q -p PID -batch -ex 'thread apply all bt'` and interrupt
the held harness afterward.

This stresses concurrent instances of the Goldenpond Rack runner and its hxcpp
runtime. It does not launch Rack or reproduce every host/plugin interaction;
passing is useful evidence, not a substitute for a prolonged Rack test.
