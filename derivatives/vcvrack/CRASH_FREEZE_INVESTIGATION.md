# World of Cake VCV Rack Freeze/Crash Investigation

## Summary

The current VCV Rack ports work initially and then freeze or crash after some minutes of runtime.

At this stage, the failure should **not** be assumed to be a simple native memory leak.

Because these modules run:

- **VCV Rack C++ audio-thread code**
- **VCV Rack C++ UI-thread code**
- **Haxe code transpiled through hxcpp**
- **hxcpp garbage collection / runtime state**

there are several plausible causes:

1. **GC pressure or heap growth in hxcpp** from repeated allocation on the realtime path
2. **Threading / lock contention** between Rack audio and UI threads
3. **Incorrect interaction with hxcpp runtime across threads**
4. **Native C++ misuse** in the Rack wrapper
5. **An actual leak** in Haxe-owned or C++-owned objects

The most suspicious issue in the current design is not a classic leak first. It is the fact that **both the Rack audio thread and the Rack UI thread call into Haxe**, while sharing a single mutex and relying on hxcpp thread attachment.


## Current Architecture Relevant To Failure

This should **not** be read as a claim that separating audio processing and UI is a mistake.

That separation is important, and it is consistent with the longer-term WoC direction for plugin-style hosts such as **VCV Rack** and future **VST** targets. In fact, the existence of a time-critical processing side and a UI side is part of what makes the WoC design attractive for those hosts.

The more precise concern is this:

- **two threads are expected and correct**
- **both threads directly entering the same live Haxe/hxcpp-managed object graph is the risky part**

So the likely lesson is **not** that WoC should abandon its engine/view separation. The likely lesson is that Rack, and probably future VST adapters too, need a **stricter bridge pattern** between the processing thread and the UI thread.

A good plugin-host pattern is usually:

- audio/process thread owns live sequencing state
- UI thread sends commands to that state
- UI thread reads a snapshot, mirror, or exported render state
- UI thread does not directly inspect the live engine object graph during draw

That distinction matters because the current failures may reflect a **host adapter design issue**, not a flaw in the core WoC idea.


The Rack modules currently follow this pattern:

- Rack `process()` runs on the **audio thread**
- Rack widget drawing and interaction run on the **UI thread**
- Both threads call into Haxe through generated hxcpp bindings
- Both threads take the same `std::mutex`

Concrete example:

- [gbloink/src/Gbloink.cpp](/media/phil/DATA/PRODUCTION/MAIN_MUSIC_IDS/gilbert_lister_research/worldofcake/derivatives/vcvrack/gbloink/src/Gbloink.cpp)
- the old Gbloink direct-Haxe facade, now removed
- [Source/gbloink/Gbloink.hx](/media/phil/DATA/PRODUCTION/MAIN_MUSIC_IDS/gilbert_lister_research/worldofcake/Source/gbloink/Gbloink.hx)

Important details:

- `process()` repeatedly calls Haxe `advanceTime()`, event accessors, parameter sync methods
- `draw()` calls Haxe accessors for ball/block state
- UI click handling calls Haxe interaction methods
- hxcpp thread attachment is done manually via `::hx::SetTopOfStack(...)`
- Haxe allocates `Event` objects during sequencing


## Most Plausible Failure Modes

## 1. Audio-thread allocation and GC pressure

This is the first thing to suspect on the Haxe side.

In [Source/gbloink/Gbloink.hx](/media/phil/DATA/PRODUCTION/MAIN_MUSIC_IDS/gilbert_lister_research/worldofcake/Source/gbloink/Gbloink.hx):

- every event is allocated as a new `Event`
- events are stored in `Array<Event>`
- `getNextEvent()` uses `events.shift()`

Why this is risky:

- `shift()` is not a cheap queue primitive
- repeated allocation on the audio path increases GC activity
- hxcpp GC pauses may look like freezes
- long-running heap growth may look like a leak even when it is delayed collection

This pattern is especially poor for realtime-style scheduling.


## 2. UI thread calling into Haxe during draw

In the current Rack design, the UI thread enters Haxe to fetch playfield state for drawing.

Why this is risky:

- draw frequency can be high
- Haxe runtime activity now happens on both audio and UI threads
- both threads contend on the same mutex
- if GC or runtime bookkeeping stalls one thread while the other waits on the mutex, Rack can appear frozen

Even if memory usage is stable, this can still produce stalls or apparent deadlocks.


## 3. hxcpp thread/runtime interaction

The code already recognizes this risk and attaches each thread using `::hx::SetTopOfStack(...)`.

That is good, but it does not prove the arrangement is safe under long-running mixed UI/audio traffic.

Possible issues:

- entering Haxe from multiple OS threads even with attachment may still expose runtime edge cases
- GC interaction may become unstable when one thread allocates while another is traversing/accessing Haxe objects
- the failure may be timing-sensitive and only surface after minutes of activity


## 4. Native C++ bug rather than leak

The Rack wrapper may still contain a conventional native bug:

- invalid object lifetime
- data race outside the mutex
- use-after-free
- undefined behavior in UI or module code

This could produce either a crash or what looks like a freeze.


## 5. Genuine leak

A true leak is still possible, for example:

- persistent Haxe allocations that remain referenced forever
- C++-side objects or resources never released
- generated data accumulating in arrays or strings

But this should be demonstrated by measurement rather than assumed.


## Repo-Specific Risk Points

## `Gbloink.cpp`

[gbloink/src/Gbloink.cpp](/media/phil/DATA/PRODUCTION/MAIN_MUSIC_IDS/gilbert_lister_research/worldofcake/derivatives/vcvrack/gbloink/src/Gbloink.cpp)

Risky characteristics:

- `process()` takes `haxeMutex` and calls Haxe repeatedly
- widget `draw()` takes `haxeMutex` and calls Haxe repeatedly
- widget click handling also enters Haxe
- `syncPanelToHaxeLocked()` is called frequently

This means the same lock protects:

- transport sync
- parameter sync
- simulation stepping
- event draining
- draw-state reads
- interaction writes

That is a large critical section crossing the host runtime boundary.


## Old Gbloink direct-Haxe facade

The old file has been removed; this section describes the former direct-Haxe facade design.

Risky characteristics:

- exposes many direct accessors into live Haxe state
- UI rendering reads Haxe-owned arrays directly through repeated calls
- event queue is consumed through repeated peek/pop calls

This is convenient, but it encourages many small cross-language calls on hot paths.


## `Gbloink.hx`

[Source/gbloink/Gbloink.hx](/media/phil/DATA/PRODUCTION/MAIN_MUSIC_IDS/gilbert_lister_research/worldofcake/Source/gbloink/Gbloink.hx)

Risky characteristics:

- allocation-heavy event queue behavior
- transient object creation in movement/state code
- `Array.shift()` queue semantics

This is not automatically wrong for desktop apps, but it is a weak fit for a realtime host.


## What To Do First

The investigation should begin by separating four cases:

1. **steady memory growth**
2. **GC pauses with bounded memory**
3. **lock contention / freeze**
4. **native crash / undefined behavior**

Do not start by rewriting large amounts of code blindly.


## Recommended Investigation Sequence

## Step 1: Measure process memory over time

Run Rack with one WoC module active and monitor resident memory.

Goal:

- determine whether RSS climbs steadily and never comes back down
- distinguish leak-like behavior from pauses/crashes with stable memory

If memory remains roughly bounded, the problem is less likely to be a simple leak.


## Step 2: Capture stack traces on freeze

If Rack freezes rather than crashes:

- attach `gdb`
- run `thread apply all bt`

Goal:

- see whether one thread is blocked on `haxeMutex`
- see whether execution is inside hxcpp GC/runtime code
- see whether the audio thread and UI thread are waiting on one another

This is one of the highest-value diagnostics.


## Step 3: Build a module with sanitizers

Use a debug build of one module with:

- `-fsanitize=address`
- `-fsanitize=undefined`
- debug symbols

Goal:

- catch native use-after-free
- catch buffer misuse
- catch undefined behavior in the Rack wrapper

This helps rule out the C++ bridge as the primary fault.


## Step 4: Instrument hxcpp heap behavior

Add temporary Haxe-side or bridge-side diagnostics around GC and allocation.

Possible approaches:

- expose debug methods from Haxe using `cpp.vm.Gc`
- log heap size or collection info periodically
- compare heap behavior while idle vs while interacting heavily

Goal:

- determine whether Haxe heap growth is monotonic
- detect whether collections are happening but not reclaiming much
- correlate freezes with GC activity


## Step 5: Reduce cross-thread Haxe access

This is both an investigation aid and likely the right architectural fix.

Recommended change:

- keep Haxe sequencing on the audio thread only
- periodically copy a plain C++ snapshot of draw state
- make UI `draw()` read only from the snapshot
- do not let `draw()` enter Haxe at all

Why:

- removes one major source of contention
- reduces hxcpp multithreaded runtime exposure
- gives a clean test of whether UI-thread Haxe access is the trigger


## Step 6: Remove allocation-heavy queue behavior

Replace:

- `Array<Event>`
- `shift()`

with:

- a ring buffer
- or a head-index queue structure

Goal:

- reduce GC pressure
- eliminate repeated array compaction/copy behavior
- make the event path more deterministic


## Implication For Future VST Work

This investigation is relevant beyond Rack.

Since WoC was partly designed with plugin-style audio/UI separation in mind, any solution chosen here should be evaluated as a likely **VST-facing pattern** too. That means the preferred fixes are the ones that strengthen the host boundary without weakening the WoC core model.

In other words:

- keep the WoC sequencer as source of truth
- keep the UI as a separate consumer/controller
- avoid making both host threads directly traverse live hxcpp-managed state
- prefer command queues, mirrored params, and snapshot-based render state in plugin hosts

If this is the right diagnosis, then the Rack fix is not a special-case hack. It is probably the beginning of the correct adapter architecture for **all** plugin-style WoC targets.

## Likely First Fixes Even Before Full Root Cause Is Proven

These are strong candidates regardless of which exact failure mode is confirmed.

## A. Stop calling Haxe from UI draw

This is the most important architectural improvement.

Preferred direction:

- audio thread owns the live sequencer
- bridge produces a C++ snapshot struct for balls, blocks, cursor positions, etc.
- UI draws from snapshot only


## B. Reduce small cross-language calls

Instead of many repeated getters such as:

- `ballCount()`
- `ballX(i)`
- `ballY(i)`
- `ballRadius(i)`

prefer:

- one batched state export
- one snapshot transfer

That reduces call overhead and runtime churn.


## C. Rework event queue semantics

The current queue model is easy to write but poor for long-running realtime use.

Better:

- fixed-capacity ring buffer, or
- reusable event objects with head/tail indices


## D. Keep JSON and string-heavy work off hot paths

Patch save/load is fine off the audio path, but no JSON/string work should occur during regular stepping/drawing.


## Investigation Questions To Answer

When the failure happens, determine:

1. Does process memory continuously grow?
2. Is the audio thread blocked on `haxeMutex`?
3. Is the UI thread inside `draw()` waiting for Haxe?
4. Is the process inside hxcpp GC/runtime code at freeze time?
5. Does the failure happen faster with heavy UI interaction?
6. Does it still happen if the module is left alone with no mouse interaction?
7. Does it still happen if playfield drawing is disabled or stubbed?

The answers will narrow the cause quickly.


## Suggested Minimal Test Variants

To isolate the problem, create temporary builds of a single module with:

1. normal behavior
2. UI draw still present, but no Haxe access in draw
3. Haxe sequencing active, but event output disabled
4. Haxe access active, but interaction disabled

These variants can identify whether the fault is in:

- draw-state polling
- event scheduling
- UI interaction
- native output glue


## Conclusion

The current symptoms are consistent with a leak, but the stronger suspicion is:

- **multithreaded Haxe runtime usage from Rack**
- **mutex contention between audio and UI**
- **allocation-heavy Haxe event queue behavior**

The best starting point is:

1. measure memory over time
2. capture stack traces on freeze
3. run a sanitizer build
4. remove Haxe calls from UI draw

If those steps are taken, the issue should become much easier to classify and fix.


## Checklist

- [ ] Reproduce the freeze/crash with one WoC Rack module under controlled conditions
- [ ] Record whether the failure is a hard crash, long freeze, or temporary stall
- [ ] Monitor Rack process RSS over time during the run
- [ ] Note whether memory growth is monotonic or roughly bounded
- [ ] Check whether the issue happens while idle with no UI interaction
- [ ] Check whether the issue happens faster with heavy mouse interaction
- [ ] Attach `gdb` during a freeze and run `thread apply all bt`
- [ ] Confirm whether the audio thread is blocked on `haxeMutex`
- [ ] Confirm whether the UI thread is inside draw-time Haxe access
- [ ] Confirm whether any thread is inside hxcpp GC/runtime code when frozen
- [ ] Build one module with `-fsanitize=address` and `-fsanitize=undefined`
- [ ] Run the sanitizer build long enough to trigger the issue or clear the native wrapper
- [ ] Add temporary hxcpp/GC diagnostics via Haxe bridge methods
- [ ] Observe Haxe heap behavior while idle
- [ ] Observe Haxe heap behavior during heavy interaction
- [ ] Compare behavior before and after disabling Haxe access from UI draw
- [ ] Compare behavior before and after batching draw-state export into a C++ snapshot
- [ ] Replace `Array<Event>` plus `shift()` with a non-shifting queue or ring buffer
- [ ] Re-test long-run stability after queue changes
- [ ] Document which modules reproduce the issue and whether the trigger pattern differs by module
