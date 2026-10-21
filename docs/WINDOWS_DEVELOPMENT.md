# WorldOfCake development on Windows

Status: Stages 1–3 complete; all five WorldOfCake Layla/OpenFL migrations exist and the previews are in an active sizing/interaction/widget refinement pass, 26 August 2026.

## Layla generation

The migrated OpenFL panel compositions are generated offline from Layla. From the repository root:

```powershell
.\run-laylagen.ps1 -Task test
.\run-laylagen.ps1 -Task generate
.\run-laylagen.ps1 -Task check
```

The script runs the project-owned generator against the canonical Layla source tree. It defaults to `G:\PRODUCTION\MAIN_PROJECTS\language_oriented\langdev\layla`; use `-LaylaRoot` when the canonical checkout is elsewhere. It invokes the already-cached Clojure 1.11.1 and Instaparse jars through Java, so the current Windows machine does not require a global `clojure` command. Generated Haxe and geometry are written beneath `Source\generated\<app>` and must not be hand-edited. Use `-App gbloink`, `timeslider`, `kdiagram`, `tileland`, or `zewp` to operate on one application; the default `all` operates on all five.

To type-check and compile the generated OpenFL compositions through native C++:

```powershell
haxelib run openfl build derivatives/openfl/project-gbloink.xml windows -debug
```

## Standalone visual previews

Migrated applications have a standalone Windows OpenFL preview with MIDI/monitor output disabled. To build without opening a window:

```powershell
.\run-openfl-preview.ps1 -App gbloink -BuildOnly
.\run-openfl-preview.ps1 -App timeslider -BuildOnly
.\run-openfl-preview.ps1 -App goldenpond -BuildOnly
.\run-openfl-preview.ps1 -App kdiagram -BuildOnly
.\run-openfl-preview.ps1 -App tileland -BuildOnly
.\run-openfl-preview.ps1 -App zewp -BuildOnly
```

To launch and interact with one:

```powershell
.\run-openfl-preview.ps1 -App gbloink
.\run-openfl-preview.ps1 -App timeslider
.\run-openfl-preview.ps1 -App goldenpond
.\run-openfl-preview.ps1 -App kdiagram
.\run-openfl-preview.ps1 -App tileland
.\run-openfl-preview.ps1 -App zewp
```

The launcher selects the corresponding `project-<app>.xml`. Previews suppress MIDI/monitor output but run the real application model and interaction code. Their playfield rendering should retain parity with Rack for shared state, palette, coordinate orientation, and interaction; Rack-specific panel chrome is intentionally outside that requirement.

Each project file declares the generated panel's initial client dimensions. `ResponsivePanelHost` then treats those dimensions as the design resolution: it scales the complete panel uniformly on resize, centers/letterboxes it when aspect ratios differ, and maps stage pointer coordinates back into design coordinates. Do not resize component coordinate mappers independently of their drawing and input paths.

The current `SemanticSelect` OpenFL proofs are:

- K-Diag: coloured segmented R/G/B cursor selector, synchronized with keys 1–3;
- Gbloink: compact previous/current/next scale selector displaying the current scale name.

Choice values, labels, colours, defaults, and presentation hints live in the application-owned EDN; Layla owns only the semantic region and composition. The latest selector code passes OpenFL HTML5 compilation. A Windows native rebuild requires all running preview processes to be closed because they share and lock `derivatives\openfl\Export\windows\bin\lime.ndll`.

## Verified toolchain

- Windows 64-bit
- Haxe 4.3.6: `C:\HaxeToolkit\haxe\haxe.exe`
- hxcpp 4.3.2, installed through `haxelib`
- Lime 8.1.3, matching the earlier Linux-generated project metadata
- OpenFL 9.3.4, matching the earlier Linux-generated project metadata
- Visual Studio Community 2022 17.8.1 with the x64 C++ toolchain
- Visual Studio environment script: `C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat`

OpenFL and Lime were initially absent and were restored at the versions recorded by the previous Linux build. The updated Gbloink application passes a Windows HTML5 smoke build with:

```powershell
haxelib run lime build derivatives/openfl/project-gbloink.xml html5 -debug
```

## Run the headless model and bridge tests

From PowerShell in the WorldOfCake root:

```powershell
.\build-headless.ps1
```

Run only the Haxe interpreter tests:

```powershell
.\build-headless.ps1 -Target interp
```

Build with hxcpp and run the native Windows executable:

```powershell
.\build-headless.ps1 -Target native
```

Build and run the handwritten C++ consumer harness:

```powershell
.\build-headless.ps1 -Target harness
```

The command runs the Gbloink, TimeSlider, TileLand, K-Diag, and Zewp suites. Native executables are generated in corresponding `build\headless-*\` directories. The generated hxcpp trees and executables are build products and should not be hand-edited.

The combined C++ harness is generated under `build\native-harness\`. Its maintained source is `test\native\GbloinkHarness.cpp`. Reusable native code lives under `bridge\native`.

`ControlThread` supplies the common background lifecycle for all three applications. It attaches its worker to hxcpp once, advances the Haxe model at a configured control cadence, and is stopped and joined before the Haxe object is destroyed. `GbloinkControlRunner`, `TimeSliderControlRunner`, and `TileLandControlRunner` can also be pumped manually by tests or a future host integration.

Both runners accept bounded commands and publish UI-safe visual snapshots. Each runner has two explicit SPSC input queues: `GUI/message thread -> control thread` and `host/audio thread -> control thread`. The control thread drains host commands first and then GUI commands before advancing the model. Each queue has its own drop counter and high-water measurement, so GUI traffic cannot consume capacity reserved for MIDI, clock, reset, or other host events and queue pressure remains observable.

Gbloink copies discrete musical events into a lock-free SPSC output queue. TimeSlider publishes continuous control snapshots through the same kind of output queue. The harness consumes both kinds of output in simulated audio functions that contain no Haxe API calls, locks, allocations, or UI work. A concurrent test runs separate GUI and host producer threads while the background Haxe control thread consumes both queues.

Continuous automation, CV, and transport values should not flood the host command queue. A later host adapter should publish replaceable latest-value state through atomic or immutable mailboxes, while reserving the host command queue for loss-sensitive discrete events. Lifecycle operations arising from another thread must be marshalled to an existing producer or performed while the runner is safely stopped; they must not silently create a second producer for either SPSC queue.

## TileLand compatibility result

TileLand fits the shared lifecycle without another thread architecture. Seed injection makes its randomized 12 x 12 tile grid repeatable in tests. Cursor stepping now preserves travel across tile boundaries, so equivalent elapsed time produces the same cursor positions under coarse and fine control cadences. The GUI queue carries tile flips; either input queue can carry semantic speed changes. The runner publishes six normalized X/Y values through a native continuous-control snapshot and publishes the 144 tile types plus three cursors separately for UI drawing.

The older Haxe model emits six MIDI-style CC events on every call to `advanceTime`. They represent the same sampled positions and are not the native runner's output contract. The TileLand facade discards those redundant legacy events on the owning control thread after each native tick, preventing unbounded accumulation while leaving existing OpenFL and old Rack behaviour unchanged.

## K-Diag compatibility result

K-Diag fits the shared lifecycle and proves mixed output publication. Its runner publishes six normalized X/Y cursor values continuously and retains only discrete node-arrival note events in the prepared event queue. Dense legacy movement CC events are consumed and discarded. Coordinates are correctly mapped from the model's `-1..1` space to `0..127`; this deliberately avoids the older Haxe CC calculation that could produce negative values.

Graph creation, cursor starts, arc selection, and subsequent traversal now use the common injectable random source. Cursor stepping consumes all travel within a delta and timestamps each arrival at its actual logical time. The UI snapshot has bounded storage for twelve nodes, up to 64 arcs, and three cursors. Tests cover deterministic graphs, cadence, controls, persistence, continuous output, arrival output, and the native boundary.

## Zewp compatibility result

Zewp completes the five-app audit. Its default ten agents and twenty draggable blocks use seeded construction in tests, and state schema v3 saves the complete world, motion, turn direction, speed multiplier, logical time, and pause state. Movement and turning use elapsed seconds while preserving the former 1 ms default feel. OpenFL population is adjustable from 0–40 and speed from one-third to 1.5 times default. Because obstacle avoidance is a nonlinear sampled simulation, exact chaotic trajectories can still vary with control cadence; hosts should use the declared bounded control cadence rather than arbitrarily coarse steps.

The native output contract remains ten continuous Y-position values. The previous `generateEvents()` method was invoked from view drawing rather than the audio/control timer, so it is retained only as a legacy OpenFL path. GUI down/drag/up commands move obstacles through the GUI SPSC queue. A fixed visual snapshot publishes at most ten agents and twenty blocks. The later Rack/VST design must decide how dynamic agents map to stable control identities; the OpenFL UI experiment does not pre-empt that decision.

## Behavioural calibration

Gbloink velocities are now expressed in logical play-area units per second. The conversion preserves the existing OpenFL default at its nominal 1 ms cadence:

```text
old default: 0.5 units per 1 ms tick
new default: 500 units per second
```

The existing Rack modules previously treated the number of `advanceTime` calls as a simulation-rate control. Their feel will change when they consume this delta-based model. Stage 4 replaces that transitional timing with the shared WorldOfCake runner and should redesign or recalibrate the Rack `Sim rate` control deliberately.

## Deterministic randomness

Interactive Gbloink still uses normal runtime randomness by default. Tests inject `SeededRandomSource`, allowing the same command sequence to create identical block geometry and colours across interpreter and hxcpp runs. Current persistence saves materialized blocks but does not promise continuation of the RNG sequence after reload.

## VCV Rack 2 development environment

The Windows Rack environment was established on 26 August 2026:

- installed host: Rack Free 2.6.4, `C:\Program Files\VCV\Rack2Free`;
- matching SDK: `derivatives\Rack-SDK-2.6.4-win-x64\Rack-SDK`;
- compiler environment: MSYS2 MinGW64 under `C:\msys64`;
- Haxe/hxcpp: Haxe 4.3.6 and hxcpp 4.3.2 under `C:\HaxeToolkit\haxe`.

MSYS2 currently supplies GCC 16.2. hxcpp 4.3.2's MinGW toolchain explicitly undefines `__STRICT_ANSI__`, which is unsupported by GCC 16's libstdc++. The local hxcpp `mingw-toolchain.xml` therefore restores `__STRICT_ANSI__` immediately after that legacy flag. Its original is backed up as `mingw-toolchain.xml.pre-gcc16`. Reapply or re-evaluate this compatibility edit after changing hxcpp or GCC.

From `derivatives\vcvrack`, build and package Gbloink with:

```powershell
.\build-rack-windows.ps1 -Module gbloink -Clean -Package
```

Use `-Install` instead of `-Package` to package and copy the plugin to Rack's user plugin directory. The verified first package is `gbloink\dist\WorldOfCake-Gbloink-2.0.1-win-x64.vcvplugin`.

Only Gbloink's Makefile has been made cross-platform so far. The other historical modules remain Linux-oriented until they move to the shared runner and generated Rack composition. The current Gbloink Windows build is an environment/compatibility proof and still uses the old direct C++-to-Haxe mutex bridge; do not treat that bridge as the Stage 4 architecture.

Rack-specific layouts will live alongside the OpenFL layouts but may use different portrait-oriented Layla compositions. Companion EDN owns HP width, fixed panel geometry, Rack widget choices, labels, ports, and drawing style. The project-owned generator will emit both panel SVG and deterministic C++ widget composition. Custom NanoVG playfield rendering and module behavior remain maintained code.
