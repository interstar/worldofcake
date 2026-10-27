# World of Cake: GPU Graphics Modernisation — Codex Handover

**Date:** 25 October 2026  
**Status:** Architectural direction agreed; implementation feasibility and repository-specific details to be investigated.  
**Audience:** Codex working in the local World of Cake repository.  
**Purpose:** Start a limited, reversible experiment to improve visual quality across WoC targets without compromising audio timing, performance interaction, or existing interface architecture.

> **Instruction to Codex:** This is a design handover, not a declaration that the APIs and classes sketched below already exist. First inspect the current repository and its build targets. Report material discrepancies before making invasive changes. Make a small proof of concept, measure it, and preserve the existing renderer and audio behaviour. Distinguish known facts, agreed product requirements, tentative implementation ideas, and unresolved questions.

## 1. Background and motivation

World of Cake (WoC) is a Haxe-based framework for experimental musical sequencers and instruments. Its code runs in several environments:

1. VST plugins through JUCE/C++ wrappers.
2. VCV Rack modules through native C++ wrappers.
3. OpenFL in browsers.
4. OpenFL desktop applications.
5. Android is a planned fifth target, likely via OpenFL/Lime unless the repository indicates otherwise.

The underlying `ISequencer`, `IControlPanel`, and `IControlPanelView` architectural pattern has held up well. These interfaces have gained functionality (e.g. pause and mute) but should **not** be redesigned for the graphics experiment. Some native wrapper code necessarily uses handwritten, real-time-safe C++ instead of Haxe-generated, garbage-collected code, especially where the audio thread is involved. Some wrapper redundancy is being reduced; avoid adding a new parallel copy of a substantial renderer to every wrapper.

Gbloink! is a good initial testbed: visually animated objects (bouncing balls and blocks) generate musical events through collisions or other simulation activity. Its original implementation and later Haxe versions may differ; inspect the repository rather than assuming a historical structure is current.

The user is increasingly performing live, projecting the real WoC software. Audiences see the performer manipulating software—particularly panning and zooming through VCV Rack, interacting with modules and zooming in on Gbloink!'s play area. That visibility of *instrument operation* is part of the performance. Existing graphics can look plain next to modern GPU-accelerated visuals; the aim is richer graphics **within the actual instrument UI**, not a detached VJ display.

## 2. Agreed goals and constraints

### Firm product requirements

- **Keep the existing performance interface visible.** Enhanced visuals should live in existing play areas/widgets/components, respecting host clipping, zoom, windowing and controls. Do not replace the projected Rack/DAW UI with an entirely separate fullscreen graphics scene.
- **Preserve tight audiovisual connection.** Collisions and other musically meaningful events must appear aligned with their sounds. Do not introduce a networking or multi-process pipeline or frame-delaying processing in the name of pluggability.
- **Keep sequencing authoritative.** Graphics must never delay, block or determine when musical events are emitted. Rendering may degrade or skip cosmetic frames; sound cannot wait for the GPU.
- **Remain cross-platform.** Browser, OpenFL desktop, Rack, JUCE/VST and eventually Android must be supported, though individual effects can feature-detect and degrade gracefully.
- **Retain the proven sequencing/control interface pattern.** Extend via rendering abstractions, not a wholesale architectural rewrite.
- **Make visualisations/looks replaceable where practical.** Different visual styles for the same sequencer are desirable, but not at the expense of timing or large duplication.
- **Support graceful fallback.** If the required GPU features/context are unavailable, or a context is lost, continue with the existing simple graphics path where possible.
- **Build incrementally.** First try trails and bloom/particle-style improvements; don't build a complete 3D engine or generic OpenGL clone prematurely.

### Architectural preferences / working hypotheses

- A small shared Haxe GPU abstraction may be useful to bridge desktop OpenGL, OpenGL ES and WebGL.
- The native wrappers should supply host-specific context/lifecycle integration; WoC's higher-level geometry/effect logic should be reusable.
- An effect system working on rendered textures may be more reusable across sequencers than a universal object/scene model.
- Keep **skins/visualisations** (how an object/scene is drawn) conceptually distinct from **post-processing effects** (what is applied to the rendered image).
- Start in the simplest accessible target, probably OpenFL/browser, **but** require a native Rack or JUCE proof before claiming the abstraction really works cross-platform.

### Ideas considered but not selected as the default

- **Separate fullscreen performance renderer** controlled over OSC/WebSocket: rejected as the main approach because audiences should see direct manipulation of the software, and additional synchronization complexity is undesirable. Not prohibited forever as an *optional* special mode.
- **Replacing OpenFL with Heaps or adopting Three.js as the common engine:** not preferred. Heaps/Three.js are capable, but would likely have to be reimplemented or awkwardly embedded within Rack/JUCE. They may be useful for experiments, not a commitment.
- **WebGPU-first architecture:** not recommended for the initial portable base. WebGL/OpenGL-family capabilities are a better common starting point for existing hosts.
- **Full 3D remake:** possible longer-term, not necessary to get large visual improvement. GPU-enhanced 2D should be tested first.

## 3. Existing platform capabilities — and critical caveats

All targets can *potentially* provide graphics from the OpenGL family, but do not assume binary/source/API equivalence or universal availability.

| Target | Likely graphics route | Implementation caveat |
| --- | --- | --- |
| Rack | Rack `OpenGlWidget` / host GL context | Respect Rack's widget draw/framebuffer lifecycle, scissoring, zoom, GL state restoration, resource lifetime. Verify exact Rack SDK/version and rules. |
| JUCE VST | `juce::OpenGLContext`, `juce::OpenGLRenderer` | OpenGL in plugin hosts has lifecycle/thread/compatibility concerns; verify against deployed JUCE and FL Studio versions. JUCE owns attached context and callback model. |
| OpenFL browser | WebGL through OpenFL/Lime; potentially low-level hooks | Verify whether actual OpenFL rendering path/context can be shared safely; don't assume raw WebGL calls can be interleaved without invalidating OpenFL render state. |
| OpenFL desktop | OpenGL through Lime/OpenFL where configured | Determine actual backend in each build; do not presume a GL context if another backend is selected. |
| Android | OpenGL ES when supported by device/driver | Android platform supports GLES, but specific versions/extensions vary by GPU/driver. Verify Android build and GL version at runtime. |

**Baseline proposal:** Explore a portable WebGL 1 / OpenGL ES 2 feature subset first, since simple render-to-texture, textured quads and fragment shaders can implement trails, blur and bloom. However, WebGL 1 has framebuffer format, extension and precision constraints; do not hard-code version choices until the target matrix and needed features are checked. WebGL 2 / GLES 3 can be an enhanced tier. Desktop core-profile shaders will require careful GLSL compatibility/translation rather than assuming ES shader source runs unchanged.

**Very important:** Rack's GUI may already be GPU-backed, and OpenFL's 'standard' rendering path may also use GPU acceleration. The fallback requirement is **not necessarily a literally GPU-free machine**. It means no dependency on WoC custom shader features; if WoC cannot acquire a usable GL context, the existing host/software-style drawing remains the fallback where supported.

## 4. Proposed conceptual architecture

Keep the sequencer and audio logic distinct from graphics.

```text
                       WoC ISequencer
                    (authoritative simulation)
                               |
           timestamped events / stable visual state snapshot
                               |
                               v
                     Visualisation / Skin
                 (sequencer-specific meaning)
                       /               \
             ClassicView           EnhancedView
                  |                      |
           Existing renderer       WoC effects chain
                                         |
                                   small IGpuDevice
                                         |
                     +-------------------+------------------+
                     |                   |                  |
                 WebGL adapter      Native GL adapter   GLES adapter
                     |                   |                  |
                OpenFL web       Rack or JUCE host    Android/OpenFL
                                 context + lifecycle
```

The diagram is **conceptual**, not a proposed mandatory class hierarchy. It should be reconciled to the current architecture; don't introduce a second redundant `IControlPanelView` abstraction without need.

Four boundaries need to be considered separately:

1. **Sequencer/simulation → presentation:** stable state and/or event stream, with authoritative collision/note timestamps where relevant.
2. **Presentation → effect pipeline:** draw a visualisation to an offscreen target, then optionally apply fullscreen texture effects.
3. **Effects → small GPU API:** textures, render targets, shaders, uniforms, mesh or quad draws, blending, viewport, resource deletion.
4. **GPU API → host adapter:** GL context ownership, draw callback, surface size, clipping, lifecycle, GL state save/restore, context loss and thread affinity.

An intentionally small illustrative interface (do not implement verbatim without a concrete design):

```haxe
interface IGpuDevice {
    function createTexture(width:Int, height:Int):TextureHandle;
    function createRenderTarget(width:Int, height:Int):RenderTargetHandle;
    function createProgram(vertex:String, fragment:String):ProgramHandle;
    function setRenderTarget(target:RenderTargetHandle):Void;
    function drawFullscreenQuad(program:ProgramHandle):Void;
    function dispose():Void;
}
```

Design questions include whether to expose state-setting primitives or use a higher-level `IEffect` API; whether resources should be device-scoped; and where shader version/precision translation belongs. Avoid writing an exhaustive GL wrapper until two targets prove the necessary minimal features.

Potential alternative: **first prototype an effect using native OpenFL mechanisms** before building `IGpuDevice`, to learn what texture/shader hooks really exist. The adapter may turn out to be much smaller than assumed.

## 5. Pluggable looks versus post-processing effects

Keep these distinct:

- **Visualisation/skin:** maps sequencer-specific state to renderable scene/objects. Examples: simple circles, luminous spheres, geometric forms, psychedelic 2D patterns. May need knowledge of balls/blocks/collisions.
- **Effect:** operates on the rendered image or event-driven particle inputs: persistent trails, bloom, colour shift, distortion, optional blur. Aim for reusable effects across multiple WoC instruments.

Proposed conceptual flow:

```text
Sequencer → chosen Visualisation → render texture
                                       |
                           [trails → bloom → grade]
                                       |
                                  host play area
```

This architecture should support the plain original visualisation with effects disabled. A shared GPU effect does not imply that every sequencer needs the same object model; avoid prematurely forcing radically different sequencers into generic `VisualObject` records.

**Performance constraint:** Pluggability should mean choosing a local implementation running on the existing render thread, not external IPC or extra video buffering. Shader compilation and allocation should happen at appropriate initialization/change points, not on each frame, and certainly not on the audio thread.

## 6. First effects to explore

### A. Persistent motion trails — first prototype

Use two offscreen textures/render targets (ping-pong, avoiding read/write feedback to the same texture):

1. Combine the previous frame's history with decay (`history * persistence`) into the current history target.
2. Draw the **current** Gbloink objects/event marks on top.
3. Composite to the host play area in the same displayed frame.
4. Swap history targets for the next frame.

The history texture represents past appearance, **not a delayed copy of the present**. The current ball/collision should always appear immediately; the trail is a fading complement. Resize or context loss should clear/recreate history safely.

Be careful that decay measured per frame varies with refresh rate; ideally use elapsed time, e.g. retention derived from `exp(-dt / tau)` or a meaningful half-life. Avoid accumulating artefacts in alpha blending. Test transparency over the host's actual background.

### B. Bloom — second prototype

Use a reduced-resolution bright-pass texture, 1–2 blur passes (separable blur if suitable), then composite bloom with the sharp current image. Choose quality tiers/blur radii and avoid large allocations at zoomed resolutions. Test GL framebuffer format/attachment compatibility.

### C. Collision particles — after first portability test

Trigger small particle bursts from authoritative collision events with their timestamps. Prefer batched or instanced drawing when supported. Cosmetic events may be dropped if render demand is high; never backpressure the sequencer/audio thread.

Later possibilities: distortion, chromatic effects, colour grading, geometric scene variants, camera transforms, 3D; these are **not initial implementation commitments**.

## 7. Audio/visual timing design

This is a hard requirement, not cosmetic polish.

- Determine where Gbloink simulation actually runs in each target (control thread, GUI thread or audio callback). Prior discussions suggested some Gbloink simulation is control-side and notes are timestamped before delivery to the audio engine, but confirm the implementation.
- Determine how and when audio event timestamps are interpreted, and when sound actually emerges after host/audio buffering.
- Prefer **authoritative timestamps** for collision/note events and a coherent clock for the visualiser. Do not derive note events a second time inside the skin.
- Keep state handoff bounded and nonblocking on audio paths: preallocated ring buffers, atomics, double-buffered snapshots or existing mechanisms as appropriate. No GL calls, blocking mutexes or uncontrolled Haxe allocations in a real-time audio callback.
- Rendering happens on the host-authorised GUI/graphics thread. A renderer may skip frames or decorative particles if overloaded, but may not hold up simulation or note emission.
- Budget for unavoidable display scanout/frame scheduling and audio buffer latency. A 60 Hz frame interval is ~16.7 ms; actual presentation latency can be higher. The target is **no extra systematic frame delay from WoC effects**, not physically impossible zero latency.
- Test audiovisual event alignment with an on-screen sharp collision flash and corresponding audible transient. Instrument event timestamps and frame presentation as best available; avoid claiming sample-perfect visible display timing.
- If needed, investigate a calibration offset for graphics vs audible sound, but only after measuring and understanding platform timing.

## 8. Graceful fallback and capability tiers

Suggested rendering policies (exact names not mandated):

```haxe
enum RenderQuality {
    Classic;
    BasicGpu;
    EnhancedGpu;
    FullGpu;
}
```

- **Classic:** existing renderer, no custom shaders. Always preserve the old path during experimentation.
- **BasicGpu:** ordinary textured/geometry GPU rendering.
- **EnhancedGpu:** trails, basic particle effects.
- **FullGpu:** bloom or other expensive post-processing.

Choose by actual context initialization, supported API version/extensions, framebuffer completeness and compile/link success—not by OS name alone. Add a manual off/quality selection even if auto-detection works. Optional adaptive quality should reduce visual cost without affecting the sound.

Runtime resilience:

- WebGL context loss/restoration.
- OpenFL/native GL context recreation on window events.
- JUCE editor open/close/reopen; host switching, resize and hi-DPI.
- Rack module add/delete, zoom, framebuffer caching and widget teardown.
- Android surface pause/resume/recreation when that target is introduced.
- Effects fail independently: bloom failure should not necessarily disable basic GPU rendering.
- Never leave a blank or broken module when an effect fails. Log diagnostics without flooding real-time audio callbacks.

## 9. Host integration and resource rules

- Do not create a second application window or independent GL context inside Rack/JUCE merely for the first prototype.
- Use the host's offered widget/component draw callbacks and respect their threading/context ownership.
- Preserve and restore any OpenGL state that host draw calls rely on: framebuffer, viewport, scissor, blend state, program, VAO/VBO bindings and texture bindings as relevant. Verify with the host SDK, particularly Rack.
- Handle pixel density and zoom correctly. Distinguish logical UI dimensions from framebuffer pixel dimensions; clamp render texture sizes.
- Keep effects bounded to the play-area region, not accidentally applied to the entire Rack/DAW UI.
- Allocate/delete GPU resources in a valid context, and avoid cross-thread use.
- Shader variants may need GL ES and desktop GLSL differences (`precision`, `#version`, attribute/varying conventions, texture functions). Use a constrained source subset plus small explicit translation/variants; validate on both browser and native host.
- Avoid assuming WebGL context exposure within OpenFL is public/stable; inspect current Lime/OpenFL APIs and actual renderer backend.

## 10. Concrete Codex investigation tasks

### Stage 0 — audit before modification

Inspect and summarize:

1. Repository layout and build commands for browser OpenFL, desktop OpenFL, Rack, JUCE/VST and any Android skeleton.
2. Actual current Haxe interfaces and their ownership: `ISequencer`, `IControlPanel`, `IControlPanelView`, and Gbloink simulation/view classes.
3. Drawing implementation in each target (OpenFL sprite/bitmap/custom render, Rack widget NanoVG/framebuffer, JUCE paint/OpenGL etc.).
4. How native wrappers call Haxe-generated code and which code is intentionally handwritten for real-time safety.
5. Where rendering occurs relative to sequencing, collision detection and note timestamps.
6. Existing GL shaders/filters, graphics libraries and helpers already in the repo; do not duplicate them.
7. Host SDK/Lime/OpenFL/JUCE versions and the documented GL integration APIs actually available.
8. Current test harnesses and practical way to run a minimal graphics test in at least browser and one native plugin.

Produce a brief audit report and identify the **least-invasive first prototype path**. Where unclear, cite repository paths/classes/functions in the report.

### Stage 1 — trails in a single target

Implement a feature-flagged trails effect for the Gbloink play area in OpenFL/browser (or another target if repository inspection shows a simpler route). Prefer offscreen texture ping-pong; use current visuals immediately plus decayed history. Controls should include effect enabled and persistence, with sensible defaults. Preserve original rendering unchanged when disabled.

Add basic diagnostics: time spent in render passes, framebuffer size, shader compile errors, context recreation and ability to turn off effects without restarting the sequencer.

### Stage 2 — test actual portability

Port the **same effect implementation/algorithm and shader logic** into *one* native host (Rack **or** JUCE; choose the easiest stable one). This is the key validity test of the proposed minimal abstraction. If a clean shared abstraction works, extract just enough common code. If forced duplication is substantial, document why and compare an alternate architecture before generalizing further.

Validate rendering inside the play area at different UI zooms/sizes and host lifecycle transitions. Test with the sequencer actively sounding.

### Stage 3 — bloom, then optional particles

Only after Stage 2: add bloom as a small composable effect. Compare performance, memory and latency across browser and native. Consider particle bursts triggered from collision timestamps. Keep any fallback/quality settings explicit.

### Stage 4 — optional visualisation plugin API

Decide whether a distinct skin/visualisation interface is required after two or more real views exist. Avoid building an extensible plugin registry solely to render one new look. If introduced, local in-process swapping should be the default, with no extra audiovisual buffering.

## 11. Acceptance criteria for proof of concept

**Functionality:**
- Gbloink remains playable and behaves identically with effects on/off.
- Visible current positions/collisions are not delayed by an extra retained frame.
- Trails can be toggled and adjusted; old view remains available.
- No new fullscreen window or obstruction of host controls.
- At least one browser/OpenFL and one native Rack/JUCE path demonstrate reusable shader/effect logic, or limitations are explicitly documented.

**Reliability:**
- Missing shaders/GL capabilities fail safely to existing view.
- Resize and context lifecycle don't crash, leak indefinitely, or produce permanently black widgets.
- Appropriate host state is restored after rendering.
- No allocation/locking/graphics work added to real-time audio callbacks.

**Performance / user experience:**
- Visual quality is visibly improved in projected use at realistic Rack zoom / window sizes.
- New effects do not cause audible timing changes, glitches or measurable sequencer event drift.
- Compare effects on/off frame times and observable audiovisual alignment; report actual data rather than treating a theoretical 60 fps target as proof.
- Add user-selectable off/quality settings where feasible.

**Engineering:**
- Small, reviewable commits and a short usage note.
- Shared code extracted only where justified by both actual target implementations.
- Document why any host-specific C++ code cannot be shared.
- Preserve original source paths/builds and avoid editing unrelated architecture.

## 12. Outstanding questions for Codex to answer from the repository

### Architecture / graphics

1. What concrete renderer does each target currently use, and which targets already have access to a GL context during play-area drawing?
2. Can OpenFL/Lime's existing texture/framebuffer/shader APIs implement feedback effects cleanly without raw WebGL calls?
3. Does Rack's `OpenGlWidget` fit the current widget composition and zoom/caching model? What native plumbing is needed?
4. Does the deployed JUCE version and FL Studio host reliably support an attached GL component on Windows? What thread/callback and resource restrictions apply?
5. Is a **single** native GL device adapter usable in both Rack and JUCE, with only thin host-lifecycle wrappers, or do context/API differences justify two adapters?
6. What are the true lowest supported browser, desktop GPU and Android GL versions? What GLES/WebGL extensions or formats are essential for trails/bloom?
7. Can a portable shader format/subset be maintained with limited preprocessing? Do host desktop contexts mandate separate shader versions?
8. How is HiDPI/Rack zoom handled in framebuffer allocation, coordinate mapping and compositing?
9. Does the existing OpenFL desktop target always render through GL, or can it select alternate backends?

### Sound and simulation

10. Which thread actually advances the Gbloink simulation in each environment? Where are collision/note events timestamped?
11. What state/event transfer facilities are already present? Can the view sample a coherent snapshot without locks or garbage collection inside the audio callback?
12. Is the visual event trigger tied to collision simulation time or arrival time of an audio message? How does the host's audio buffer latency affect observed alignment?
13. How do pause, mute, stopped transport and UI inactivity affect visual history? Should trails freeze, decay, or clear? **Ask the user before assigning musical meaning to these states.**

### Visual language / product decisions

14. Should trails follow all moving objects, collisions only, or particular object types?
15. Should trails persist while zooming/panning Rack or only when simulation remains stable? Should they clear on resize, skin change or restart?
16. Preferred baseline look: clean subtle trails, neon glow, or a more intense psychedelic effect? Start with easily adjustable parameters instead of imposing an aesthetic.
17. Should appearance settings be saved per sequencer instance, shared as a preset, or controlled at a global level?
18. Should there be a common WoC effects chain for all instruments, or should Gbloink first prove the API locally?
19. Which native target is easiest/most valuable for the second-stage test: Rack (live projection use case) or JUCE/VST (FL Studio workflow)?

Do not block Stage 0 or the first limited trails proof on product-preference answers. Choose conservative, reversible defaults and surface questions with concrete alternatives.

## 13. Explicit non-goals for this iteration

- Rewriting existing `ISequencer` / `IControlPanel` architecture.
- Replacing all OpenFL drawing or switching every target to Heaps/Three.js.
- Rendering a separate VJ-only presentation that obscures the actual host interface.
- Networked visual state transfer / OSC / WebSocket as the main visual path.
- Developing a full general-purpose graphics engine or abstracting the entire OpenGL API.
- Adding complete 3D scene graphs, PBR, physics, model loading or elaborate visual-editor tooling.
- Introducing new non-real-time-safe work into native audio callbacks.
- Claiming all platforms work because a WebGL demo worked.

## 14. Suggested immediate request to Codex

> Inspect the World of Cake repository and produce a concise architecture audit against the attached GPU graphics handover. Identify exactly how Gbloink draws in OpenFL/browser, Rack and JUCE, how rendering contexts are owned, and whether OpenFL already offers suitable offscreen framebuffer/custom-shader facilities. Then implement the **smallest reversible Gbloink trails proof of concept** on the easiest target. Keep the current scene/current collisions in the latest frame, add decaying history with GPU feedback, and preserve a no-effects fallback. Do not modify the real-time audio code or undertake a general renderer rewrite. Report findings, tested build commands, visual results, performance/latency observations, cross-target risks, and a concrete recommendation for a second implementation in Rack or JUCE. If the proof requires host-specific changes, keep them isolated and explain them.

## 15. Key principle

**The audience should still see the real instrument being played. GPU effects make its existing graphical behaviour more expressive; they must not become a detached performance layer, compromise sound timing, or demand five redundant graphics implementations.**

