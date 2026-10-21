# World of Cake — TimeSlider (VCV Rack 2)

Linux-first Rack module wrapping the Haxe `timeslider.TimeSliderSequencer` from `Source/timeslider/` (**26 HP** panel: four wide tracks in the playfield, four CV jacks in a narrow right column).

## Build

From this directory (path must not break GNU Make or the linker):

```bash
export RACK_DIR=/absolute/path/to/Rack-SDK
make
```

`make install` / `make dist` use the WoC shared Rack Makefile and place local artifacts under `../../../build/vcvrack/timeslider/linux/`; the Windows wrapper uses the sibling `windows/` tree.

Rack 2 on Linux installs to `~/.local/share/Rack2/plugins/<slug>/`. After upgrading, remove any old `WorldOfCake-TimeSlider` folder there (or run `make install` so the new `plugin.so` overwrites the old one), then **fully quit and restart Rack**. Patches saved before the four-wide layout used `stateJson` **v:1** with three narrow tracks; the sequencer now **migrates** those on load (or use **Reset** to force the default four-track layout).

## Layout

- **Play area:** click inside a vertical track to set a target level; horizontal position sets **travel time** on a **log** scale (defaults: **120 s** at the left edge, **0.5 s** at the right; same as `TimeSliderMain` / `TimeSliderHarness` creation).
- **Sim rate:** physics tick period (like Gbloink).
- **Reset / Pause:** `ISequencer.reset()` and pause/resume.

## Haxe

- `haxe/timeslider.hxml` compiles `worldofcake.bridge.TimeSliderHarness` with `-cp` to shared `Source/` and `bridge/haxe`.
- C++ must call `__hxcpp_lib_main()` once (`plugin.cpp`) before any harness use.
