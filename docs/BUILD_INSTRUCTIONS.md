# WorldOfCake Build Instructions

This document describes how to build, package, install, and verify the WorldOfCake VCV Rack 2 modules on Windows and Linux.

## Supported Rack modules

- `gbloink`
- `goldenpond`
- `kdiagram`
- `tileland`
- `timeslider`
- `zewp`

Goldenpond depends on its adjacent source checkout. The aggregate build scripts skip it with a warning when that checkout is unavailable.

## Build-system structure

Every module has a small declarative Makefile under `derivatives/vcvrack/<module>/Makefile`. It identifies the module, its Haxe build file, native runner, and generated panel resources.

Shared build behavior lives in:

```text
derivatives/vcvrack/common/plugin.mk
```

Platform-specific policy lives in:

```text
derivatives/vcvrack/common/platform-windows.mk
derivatives/vcvrack/common/platform-linux.mk
```

Do not duplicate the complete build graph in per-platform or per-module Makefiles. Module Makefiles should contain only module-specific declarations and include `../common/plugin.mk`.

Generated and compiled artifacts are isolated by host platform:

```text
build/vcvrack/<module>/windows/
build/vcvrack/<module>/linux/
```

This allows Windows and Linux outputs to coexist without either build deleting or linking the other platform's objects.

## Source-generation policy

Rack panels and native layout metadata are generated from the canonical Rack Layla/EDN sources under `layouts/rack/`. Generated sources and SVG files are gitignored build output and must not be edited manually.

The same Layla/EDN generation pass also emits target-neutral native control metadata for every app under `bridge/native/worldofcake/generated/<app>/*ControlMetadataGenerated.h`. This is the common semantic layer for Rack and JUCE/VST adapters: ranges, choices, labels, defaults, and text defaults belong there. Host wrappers should bind their own widgets/parameters to these generated IDs and metadata; they should not recreate those values by hand. Regenerate all apps before a native build with the bundled generator JAR (requires Java 11+; no Layla or Clojure checkout is needed). From the repository root, run one app at a time, for example:

```powershell
java -jar vendor\layla\worldofcake-laylagen.jar --input layouts\openfl\gbloink.layla --config layouts\openfl\gbloink.edn --output Source --native-output bridge\native
```

Repeat for each app (`gbloink`, `goldenpond`, `kdiagram`, `tileland`, `timeslider`, `zewp`).

Layout generation is separate from ordinary native compilation. A routine Rack rebuild should not modify generated source files.

## Native metadata regression test

Compile and run the target-neutral parameter conversion test on Windows:

```powershell
& 'C:\msys64\mingw64\bin\g++.exe' -std=c++11 -I bridge/native bridge/native/tests/WorldOfCakeControlMetadata_test.cpp -o "$env:TEMP\woc-control-metadata-test.exe"
& "$env:TEMP\woc-control-metadata-test.exe"
```

## Windows

### Verified toolchain

- Windows x64
- Rack Free 2.6.4
- Rack SDK 2.6.4 for Windows x64
- Haxe 4.3.6
- hxcpp 4.3.2
- MSYS2 MinGW64 with GCC 16.2

Expected paths on the verified workstation:

```text
C:\Program Files\VCV\Rack2Free\Rack.exe
C:\HaxeToolkit\haxe\haxe.exe
C:\msys64\msys2_shell.cmd
derivatives\Rack-SDK-2.6.4-win-x64\Rack-SDK
```

The local hxcpp 4.3.2 `mingw-toolchain.xml` contains the required GCC 16 compatibility adjustment: `__STRICT_ANSI__` is restored after hxcpp's legacy undefinition. Re-evaluate this local compatibility change after upgrading hxcpp or GCC.

### Why Windows uses a wrapper

The Windows build has two phases:

1. PowerShell runs Haxe and hxcpp as native Windows programs, preserving the configured Windows haxelib repository.
2. MSYS2 MinGW64 compiles the maintained Rack C++ glue, links it with the hxcpp objects, and packages the Rack plugin.

Do not invoke the Windows `haxelib` executable from an MSYS2 shell with a temporary `HOME`. It may lose its configured library repository. Use `build-rack-windows.ps1`.

The wrapper also redirects MSYS2 compiler temporary files into the module's workspace artifact directory. This avoids relying on write access to `C:\msys64\tmp`.

### Build one module

Run from `derivatives\vcvrack`:

```powershell
.\build-rack-windows.ps1 -Module gbloink -Clean -Package
```

Build and install into Rack's user plugin directory:

```powershell
.\build-rack-windows.ps1 -Module gbloink -Clean -Install
```

Valid module names are:

```text
gbloink goldenpond kdiagram tileland timeslider zewp
```

Options:

- `-Clean`: remove that module's Windows artifact tree before rebuilding.
- `-Package`: produce a `.vcvplugin` archive without installing it.
- `-Install`: package and copy the archive into `%LOCALAPPDATA%\Rack2\plugins-win-x64`.
- With neither `-Package` nor `-Install`, the wrapper builds `plugin.dll` only.

### Build all modules

From `derivatives\vcvrack`:

```powershell
.\build-all-rack-windows.ps1 -Clean -Package
```

Build and install all available modules:

```powershell
.\build-all-rack-windows.ps1 -Clean -Install
```

Modules are deliberately built sequentially.

### Windows outputs

For Gbloink, for example:

```text
build\vcvrack\gbloink\windows\native\
build\vcvrack\gbloink\windows\rack-build\
build\vcvrack\gbloink\windows\plugin.dll
build\vcvrack\gbloink\windows\dist\WorldOfCake-Gbloink-<version>-win-x64.vcvplugin
```

### Windows binary verification

After building, inspect the DLL:

```powershell
C:\msys64\mingw64\bin\objdump.exe -p `
  ..\..\build\vcvrack\gbloink\windows\plugin.dll
```

The export table must contain `init`. The import list should contain only Windows system DLLs and `libRack.dll`. It must not depend on:

```text
libgcc_s_seh-1.dll
libstdc++-6.dll
libwinpthread-1.dll
```

The shared Windows policy deliberately appends the static libgcc/winpthread flags after Rack's dependency defaults. That ordering must be preserved.

### Load verification in Rack

Close Rack before replacing or troubleshooting extracted plugin directories. After installing, start Rack and inspect:

```text
%LOCALAPPDATA%\Rack2\log.txt
```

Look for one line per plugin such as:

```text
Loaded plugin WorldOfCake-Gbloink 2.0.1
```

Successful compilation, packaging, or extraction alone does not prove that Windows loaded the DLL.

### K-Diagram hang diagnostics

K-Diagram's control runner records a heartbeat and the native/Haxe boundary it is currently executing. If an
autosave persistence request exceeds its bounded wait, Rack writes a warning like this to `%LOCALAPPDATA%\Rack2\log.txt`:

```text
WorldOfCake-KDiagram: persistence timeout count=1 stage=export-state stageAgeMs=501 heartbeatAgeMs=517 pumps=1200/1201 exports=0/1
```

The stage identifies the operation that had not returned when autosave timed out. Pump and export counters are
reported as `completed/started`; unequal values identify an in-flight operation. Logging happens only from Rack's
non-real-time persistence path, never from `Module::process()`.

For debugger attachment, use the unstripped Windows build artifact:

```text
build\vcvrack\kdiagram\windows\plugin.dll
```

It retains debug symbols and frame pointers. The DLL copied into the `.vcvplugin` package is stripped, so preserve
the matching unstripped artifact whenever collecting a stack from the installed build.

### hxcpp thread lifecycle

Rack calls each plugin's `init()` on a host thread which does not continue executing Haxe. All WorldOfCake Rack
plugins must boot hxcpp through `bridge/native/HaxeRuntimeBoot.h`; it runs `__hxcpp_lib_main()` once and then
unregisters that host thread from the hxcpp collector. Do not call `__hxcpp_lib_main()` directly from an individual
module adapter.

The shared `ControlThread` uses `hx::NativeAttach` for the lifetime of its worker. Model construction, pumping, and
destruction therefore occur while the worker is registered, and its registration is released when the worker exits.
An unbalanced loader or worker registration can make a later stop-the-world collection wait forever even though the
module appears healthy until its managed heap first needs collection.

For full runtime verification:

1. Find the module in Rack's module browser.
2. Add it to a patch.
3. Exercise every control and interactive playfield.
4. Connect and inspect all outputs.
5. Save and reload the patch.
6. Duplicate and delete module instances.
7. Restart Rack and inspect the new log for errors.

## Linux

### Expected toolchain

- Haxe and hxcpp available on `PATH`
- GNU Make and a C++ compiler
- Rack SDK 2.6.6 at `derivatives/Rack-SDK-2.6.6-lin-x64/Rack-SDK`, or an explicit `RACK_DIR`
- `tar`, `zstd`, `jq`, and standard Unix build tools

Unlike Windows, the Linux Make invocation can run Haxe/hxcpp directly because Haxe, haxelib, Make, and the compiler share the same environment.

### Build one module

From the repository root:

```bash
./derivatives/vcvrack/build_module.sh gbloink clean build
```

Create a package:

```bash
./derivatives/vcvrack/build_module.sh gbloink clean dist
```

Build and install:

```bash
./derivatives/vcvrack/build_module.sh gbloink clean install
```

Override the SDK when necessary:

```bash
RACK_DIR=/absolute/space-free/path/to/Rack-SDK \
  ./derivatives/vcvrack/build_module.sh gbloink clean dist
```

Rack SDK paths should not contain spaces because Rack's GNU Make build files are not robust to them.

### Build all modules

```bash
./derivatives/vcvrack/build_all.sh clean build
./derivatives/vcvrack/build_all.sh clean dist
./derivatives/vcvrack/build_all.sh clean install
```

The aggregate script builds modules sequentially and includes Goldenpond when its source checkout is available.

### Build, install, and refresh extracted Linux plugins

For local interactive development:

```bash
./derivatives/vcvrack/install_linux_local.sh
```

This builds and installs the archives, removes the exact old extracted WorldOfCake plugin directories, and extracts the new packages into Rack's Linux plugin directory.

Override that directory with:

```bash
WOC_RACK_PLUGIN_DIR=/custom/Rack2/plugins-lin-x64 \
  ./derivatives/vcvrack/install_linux_local.sh
```

### Linux outputs

For Gbloink, for example:

```text
build/vcvrack/gbloink/linux/native/
build/vcvrack/gbloink/linux/rack-build/
build/vcvrack/gbloink/linux/plugin.so
build/vcvrack/gbloink/linux/dist/WorldOfCake-Gbloink-<version>-lin-x64.vcvplugin
```

### Linux verification

Inspect the unstripped plugin before packaging when diagnosing symbols or dependencies:

```bash
nm -D build/vcvrack/gbloink/linux/plugin.so | grep ' init$'
readelf -d build/vcvrack/gbloink/linux/plugin.so
```

Restart Rack after installation and verify the newest Rack log contains `Loaded plugin WorldOfCake-<Module>` for every installed module.

## Common Make targets

The shared Makefile provides:

- `codegen`: run Haxe/hxcpp generation, unless the Windows wrapper has already supplied generated objects.
- `build`: run code generation and build `plugin.dll` or `plugin.so`.
- `dist`: build and create the `.vcvplugin` archive.
- `install`: create the archive and copy it into the Rack user plugin directory.
- `clean`: remove only the current module's current-platform artifact tree.
- `cleandist`: remove only the current module's current-platform package directory.

## Generated layout checks

Layout generation is not required for every C++ rebuild. When Layla or EDN sources change, regenerate and validate them before compiling modules. On Linux, the Rack generator entry points are:

```bash
./derivatives/vcvrack/generate_rack_layout.sh
./derivatives/vcvrack/generate_rack_metadata.sh
./derivatives/vcvrack/check_rack_metadata.sh
```

On Windows, drive the same bundled JAR with `java` (requires Java 11+); the Linux scripts above are the canonical argument reference for each generator task.

Do not hand-edit files under `Source/generated/`, `bridge/native/worldofcake/generated/`, or module `generated/` directories.

## Troubleshooting

### Windows Haxe reports `End_of_file`

This commonly means Windows Haxe/haxelib was invoked from an MSYS2 environment that cannot see its configured haxelib repository. Run the PowerShell wrapper rather than invoking `make` directly.

### GCC cannot create a temporary file under `C:\msys64\tmp`

Use the PowerShell wrapper. It sets `TMP`, `TEMP`, and `HOME` to a writable directory under the module's Windows artifact tree.

### Rack does not show the module

Check all of the following:

- The plugin manifest version uses Rack ABI major version 2.
- The package slug, manifest module slug, and `createModel` slug agree.
- The archive is in the correct `plugins-<os>-<cpu>` directory.
- Rack was fully restarted after installation.
- The newest Rack log reports `Loaded plugin` rather than only package extraction.

### Windows loader error 127

Inspect `plugin.dll` with `objdump -p`. A missing runtime DLL or symbol is more likely than a module-browser indexing problem.

### Switching between Windows and Linux

No cleanup is required solely because the host platform changed. Each platform has its own artifact directory. Use `clean` only when a clean rebuild is otherwise needed.

## JUCE/VST3 — Windows WorldOfCake plugins

The WorldOfCake JUCE work is under `derivatives/juce`. Its architecture and staged acceptance criteria are in `../VST3_IMPLEMENTATION_PLAN.md`.

The current machine has been verified with:

- Visual Studio 2022 Community and the MSVC 14.38 x64 toolchain;
- Visual Studio's bundled CMake 3.27;
- Haxe 4.3.6 and hxcpp 4.3.2;
- JUCE 8.0.15 at `G:\PRODUCTION\MUSIC\music-software\falling sand 2026\sandsonify-vst\JUCE`.

The JUCE checkout is supplied as a build parameter rather than copied into or hard-coded by CMake. The wrapper's default points at the verified checkout above; override `-JuceDir` when moving the project or using another JUCE checkout.

From the WorldOfCake root in PowerShell:

```powershell
.\derivatives\juce\build-windows.ps1 -Config Release
```

To use another JUCE checkout:

```powershell
.\derivatives\juce\build-windows.ps1 -Config Release -JuceDir 'D:\SDKs\JUCE'
```

The wrapper supports `Gbloink`, `TimeSliders`, and `Goldenpond`:

The generated `Mute output` control is separate from `Pause`. Mute suppresses emitted MIDI while the WorldOfCake model and, for Goldenpond, DAW-synchronised transport continue advancing. Pause changes the model state. Both controls are defined in Layla/EDN and adapters must consume their generated IDs and geometry.

```powershell
.\derivatives\juce\build-windows.ps1 -Plugin Gbloink -Target WorldOfCakeGbloink_VST3 -Config Release
.\derivatives\juce\build-windows.ps1 -Plugin TimeSliders -Target WorldOfCakeTimeSliders_VST3 -Config Release
.\derivatives\juce\build-windows.ps1 -Plugin Goldenpond -Target WorldOfCakeGoldenpond_VST3 -Config Release
```

The wrapper:

1. locates hxcpp through `haxelib`;
2. enters the Visual Studio x64 developer environment;
3. compiles the Gbloink Haxe bridge and hxcpp runtime with MSVC;
4. configures the JUCE CMake project; and
5. builds both VST3 and standalone products.

`-D NO_AUTO_MSVC` is intentional. hxcpp 4.3.2's automatic Visual Studio setup loses the usable compiler environment on this machine. The wrapper establishes that environment explicitly. It also normalizes duplicate `Path`/`PATH` entries because MSBuild otherwise fails before compiler identification.

Release artifacts are written under the matching target directory:

```text
build/juce/cmake-vs2022/WorldOfCakeGbloink_artefacts/Release/VST3/WorldOfCake Gbloink.vst3
build/juce/cmake-vs2022/WorldOfCakeGbloink_artefacts/Release/Standalone/WorldOfCake Gbloink.exe
build/juce/cmake-vs2022/WorldOfCakeTimeSliders_artefacts/Release/VST3/WorldOfCake TimeSliders.vst3
build/juce/cmake-vs2022/WorldOfCakeGoldenpond_artefacts/Release/VST3/WorldOfCake Goldenpond.vst3
```

The `.vst3` item is a bundle directory. Copy the whole directory, not only the binary inside it. A normal system-wide VST3 location is:

```text
C:\Program Files\Common Files\VST3
```

Copy the complete `.vst3` bundle directory, not only its binary. Installation normally requires an elevated PowerShell. Keep one copy per plugin in the standard VST3 directory; do not also copy the same bundle into `C:\Program Files\Common Files\VstPlugins`, because FL Studio will list duplicate entries (often with `_2`) and may load a stale bundle. A valid bundle has the binary under `Contents\x86_64-win\`.

Alternatively, add the artifact's `Release\VST3` directory to FL Studio's plug-in search paths while developing. In FL Studio, open **Manage plugins**, select the containing VST3 directory, and run **Find installed plugins**. After replacing a plugin, close/reopen its instance or restart FL Studio before judging the result. Route MIDI output to an instrument and verify play, stop, project reload, and multiple instances.

### JUCE architecture requirements

VST adapters must reuse the WorldOfCake native bridge rather than reimplementing framework behavior:

- `bridge/native/ControlRunnerBase.h` owns runner lifecycle, queues, persistence requests, and host transport publication.
- `bridge/native/WorldOfCakeBridgeTypes.h` owns native `PanelPoint`, `LocalPoint`, `ScreenPoint`, `CoordinateMapper`, commands, snapshots, and prepared events.
- generated `bridge/native/worldofcake/generated/juce/<app>/LayoutGenerated.h` and control-ID headers come from the canonical OpenFL Layla/EDN layout.
- JUCE code supplies host widgets, drawing, and audio/MIDI block integration only.
- Coordinate conversion must go through the shared native mapper. Do not add per-plugin scaling formulas.
- VST widget bounds should be mapped from generated layout rectangles; hand-authored JUCE geometry is deprecated.
- Transport behavior is an explicit host-adapter policy: Gbloink and K-Diagram are free-running generators that pause/resume with DAW play/stop without seeking to host position; Goldenpond and other clocked sequencers follow DAW play/stop and host transport position; TimeSliders may remain independent because its motion is gesture-driven. Keep these policies out of shared Haxe sequencer code.
- EDN component metadata is also the source for labels, short labels, and tooltips. JUCE and Rack choose the host-specific font/widget presentation, but must not duplicate semantic text in C++.

When layouts change, regenerate with the bundled generator JAR (`java -jar vendor\layla\worldofcake-laylagen.jar …`) before rebuilding. Generated files are not hand-edited.

The Gbloink runner uses a host-clock mailbox and simulates 20 ms ahead in 1 ms host-neutral physics steps. Prepared events carry a transport epoch and absolute logical timestamp. A fixed-capacity native scheduler converts those timestamps to offsets within the current audio block and retains future events for later blocks. Stop, seek, and other transport discontinuities increment the epoch, discard stale events, and emit panic note-offs. Notes currently have a bounded 50 ms duration.

The native editor reads only published visual snapshots and sends commands through the bounded GUI queue. Click the field to add or remove note blocks, or enable **Wall notes** to hear collisions with the boundary. The three speed controls and scale selector drive the same semantic control IDs used by the other WorldOfCake targets.

Run the native scheduler regression test after changing timing or MIDI code:

```powershell
& '.\build\juce\cmake-vs2022\WocMidiSchedulerTest_artefacts\Release\WocMidiSchedulerTest.exe'
```

The remaining first-milestone validation is host-side: scan in FL Studio, test MIDI routing and transport changes, save/reload a project, and stress multiple plug-in instances. Steinberg validator/pluginval are not yet part of the wrapper.

The build currently emits many warnings from hxcpp 4.3.2 headers under JUCE's recommended MSVC warning level. They are noisy but did not prevent the verified Release VST3 and standalone products from linking. Project-owned warnings should still be fixed rather than hidden among them.

## Related documentation

- `architecture.md`
- `../VST3_IMPLEMENTATION_PLAN.md`
- `WINDOWS_DEVELOPMENT-rack.md`
- `../docker/DOCKER_DEVELOPMENT.md`
- `../derivatives/vcvrack/vcvrack.md`
- `../derivatives/vcvrack/CRASH_FREEZE_INVESTIGATION.md`
