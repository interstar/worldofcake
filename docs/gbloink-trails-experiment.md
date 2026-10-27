# Gbloink OpenFL trails experiment

This started as an opt-in OpenFL experiment and now also has a native Rack port.
Normal OpenFL builds exclude the experimental view. The sequencer/control
interfaces, audio callback, Layla/EDN and panel chrome retain their existing roles;
the model and native snapshots now also publish bounded cosmetic collision cues.

## Collision ripples follow-up

Rack's Gbloink context menu now has a separate **Collision ripples** switch
(enabled initially). Ripples work independently of the trails switch. The
experimental OpenFL build displays the same look.

Each contact emits three rings, staggered by 80 ms, expanding over 700 ms and
fading out. Maximum radius is `120 * MIDI velocity / 127` in the 700x500 world:
velocity 127 reaches 120 units, velocity 64 about 60.5. Velocity is captured at
impact, so later knob edits do not resize existing rings. Ball-to-ball contact
emits one set in each participating ball's colour and velocity. Those rings have
higher opacity, slightly thicker strokes, and a 25% lift towards white compared
with wall/block rings. Rings are clipped to the play area and are drawn separately
from the retained trail texture, so they do not leave their own trails.

`Gbloink.collisionCues` is an authoritative, transient, 32-entry history with
model timestamps and a 0.9-second retention window. It is not part of state JSON
or the MIDI event queue. Native visual snapshots copy a bounded POD array on the
control thread; each renderer deduplicates cue serials and ages rings using its
presentation clock. An explicit cosmetic epoch clears old rings on reset/restore.
Mute does not suppress physical collision cues; wall cues are also available when
wall notes are disabled. Ball-to-ball collisions play one note per participating
ball, on its own channel at its own MIDI velocity, with pitch mapped from the
contact height and the normal note-length/pause/mute/transport handling. Closely
repeated resolution of the same contact is debounced for cosmetics only.

Rack uses its GPU-backed NanoVG circle strokes for these sparse rings; this needs
no extra history texture or full-screen shader pass. Existing rings fade while
paused, consistently with the agreed trail behaviour. Dense impacts can discard
the oldest cosmetic cues and never backpressure audio.

Checks: `haxe hxml/tests/test-gbloink-collision-cues.hxml` covers actual contact
positions, timestamps, two-ball cues, captured velocities, MIDI preservation,
bounded history, expiry, reset and restoration. The existing Gbloink headless
suite remains the sequencing regression check. Visual acceptance in Rack is a
manual check; screen capture and UI automation remain stopped.

### Ripple visibility follow-up

The initial rings faded quadratically from birth, used thin strokes, and sat
behind the obstacles. The revised look holds brightness through the first 60%
of expansion, fades over the remaining 40%, draws above obstacles, and uses a
minimum 1.5-pixel Rack stroke at the current zoom. Wall/block opacity starts at
0.65; ball-pair opacity at 0.9, retaining the pair's white lift. World-space
radius and captured MIDI-velocity mapping are unchanged.

A one-time Rack log entry reports the first accepted cue and another reports
the first submitted ring. This distinguishes missing cue delivery from drawing
or visibility trouble without screen capture or per-frame logging. These log
entries prove submission, not visible pixel output.

`test/native/GbloinkCollisionBridge.cpp` exercises the actual hxcpp harness and
native runner without a window, audio device, or capture. It can also accept an
app-owned state JSON file and run the real control thread after restoration.
The fresh-model probe received 13 cues over 15 simulated seconds; a restored
Rack-patch probe received 46 cues over approximately four real seconds, with
valid ages, positions and velocities. This confirms the native snapshot path;
it does not establish the cause of the user's missing visual rings.

## Windows incremental-build repair

After adding collision fields to the native visual snapshot, an old GPU-renderer
object survived an incremental build. Its old struct layout read the collision
data as lifecycle flags, suppressing trail marks despite successful shader/FBO
initialization. The menu and classic scene still worked, masking the build error.

MinGW dependency files named object targets as `G:/...`, but MSYS make's object
rules used `/g/...`. The shared Windows Rack make rules now normalize generated
dependency files into `.d.posix` includes, repairing existing dependency files as
well as new ones. Linux/macOS dependency handling is unchanged.

Verified on the actual GPU object: before repair, make considered it up to date
although the snapshot header was newer. After repair it scheduled recompilation.
After rebuilding, a normal dry run was a no-op, while `make -n -W` against the
snapshot header scheduled recompilation again. The package was rebuilt with the
consistent snapshot layout. Runtime visual confirmation remains manual.

## Run

```powershell
haxelib run lime build derivatives/openfl/project-gbloink.xml html5 -D woc_gpu_trails
```

Serve `derivatives/openfl/Export/html5/bin` over localhost. Click the play-area
diagnostic strip or press **T** to switch trails on/off. **[**/**]** change trail
half-life; Shift-click the strip cycles it. **R** switches full/half history
resolution. Keyboard shortcuts require the page to have focus. These temporary
appearance controls are not persisted in musical state.

**B** runs an automatic 48-second profile: classic, copy-only, decay-only,
full-resolution trails, half-resolution trails, then classic again. Each mode
warms up for two seconds and samples for six. Trail controls are held fixed
during the profile. Leave the page visible without interacting. Results are
logged as `TRAIL_PROFILE result` JSON, including median/p95/longest frame
intervals, stalls over 250 ms, CPU submission, and model/wall time ratio.

## Rendering

`GpuTrailSurface` owns two reusable rectangle textures wrapped in non-readable
`BitmapData`. `BitmapData.draw` in installed OpenFL 9.3.4 selects its OpenGL
render-to-texture branch for these targets. Each frame samples the other texture
through `TrailDecayShader`, then draws only new ball marks into the destination.
History and marks are children of one offscreen scene, submitted through a
single `BitmapData.draw` call per frame. This avoids the original second renderer
creation and framebuffer visit. History is opaque and decays towards the original play-area background using
`pow(0.5, elapsedSeconds / halfLife)`. No pixel readback or per-frame texture
creation is used by our code. OpenFL creates internal renderer objects for draw
calls; this is a potential source of overhead, not a proven optimal GPU path.

Current balls and blocks are rendered sharply above history. Half-resolution
history is enlarged with smoothing; the sharp scene stays at design resolution.
Texture dimensions are capped at 1536 per axis independently of window zoom.
Pause lets history fade without depositing stationary-ball marks. Mute leaves
motion and trails running. A model replacement, time rewind or toggle clears
history. The classic drawing path remains available on initialization failure.
Lime context-loss/restoration listeners discard history and recreate the shader;
their presence is not a substitute for a context-loss runtime test.

## Measurements and limitations

The diagnostic CPU submission time is **not GPU execution time**. Where supported,
two preallocated `EXT_disjoint_timer_query_webgl2` queries sparsely sample GPU
execution of the offscreen pass. Results are read asynchronously only after
availability is reported; there is no synchronous wait. Disjoint results are
discarded. The reported GPU value is the **latest individual sample**, not an
average, and excludes the later stage composite and other UI rendering.

Frame-rate
windows are logged as `TRAIL_BENCH`; exclude startup and mixed-mode windows.
Compare the same size and model state with no concurrent builds or other load.
Browser background throttling and tooling can affect the readings.

Initial full-resolution sidebar observations were approximately 17–39 fps on,
25–45 fps off, with substantial variation. Submission was around 1–3 ms. These
were exploratory observations with other activity, not controlled performance
claims. The actual reported device was Intel UHD Graphics 630 through ANGLE /
Direct3D 11; WebGL 2 alone did not establish this. Half resolution is a subsequent
experiment, not yet evidence of a performance improvement.
Later half-resolution windows were around 25–39 fps, and full-resolution windows
around 18–46 fps. The off baseline also fell into the 10–26 fps range during other
activity. These overlapping, unstable samples do not isolate GPU pixel cost or
establish the effect's overhead. A quieter repeatable benchmark and profiling of
OpenFL pass setup are required before promoting this implementation.

## Single-pass profiling follow-up (26 October 2026)

Removed per-frame diagnostic text changes (now 2 Hz) and disabled trail-mark
geometry rebuilding when effects are off. Combined history and marks into one
offscreen scene/pass. Added the automated mode sequence and asynchronous GPU
queries described above. These are prototype overhead reductions; the current
samples do not establish how much each individual change contributed.

The subsequent sidebar run on the same Intel UHD 630 reported:

- Classic-before: 44.0 fps, median 22 ms, p95 30 ms; classic-after: 38.3 fps,
  median 19 ms, p95 35 ms.
- Full-resolution trails: 41.5 fps, median 17 ms, p95 26 ms; mean CPU submission
  0.764 ms; latest offscreen GPU execution sample 0.248 ms.
- Half-resolution trails: 42.2 fps, median 19 ms, p95 34 ms; mean CPU submission
  0.811 ms; latest GPU execution sample 0.121 ms.
- Copy-only latest GPU sample: 0.184 ms; decay-only: 0.123 ms.
- Model/wall time ratios across all modes were approximately 0.9997–1.0007.

Several modes, including classic-after, contained 0.5–1.1-second display stalls.
Accordingly, do not claim a stable frame rate or a precise effects-on/off speedup.
The GPU samples support a cheap offscreen effect on this device; overall sidebar
frame scheduling remains variable. Next verify the single-pass look and lifecycle
in a native host before extracting a generic device API or adding bloom.

The OpenFL target is a preview that discards musical output. It cannot establish
audible/visible alignment. Gbloink headless regression tests passed after adding
the initial view-only effect. Rack/JUCE portability, collision cues, bloom,
context-loss resilience and GPU execution timing remain separate verification
work. Do not promote this path to the default on the basis of the browser demo.
