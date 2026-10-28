# WorldOfCake Gbloink for VCV Rack 2

The Rack adapter runs the shared Haxe Gbloink model through its asynchronous
native control runner. The audio callback consumes prepared note events and
published native data; it never enters Haxe or draws the interface.

App semantics live in `apps/gbloink/app.edn`. Rack panel geometry, sockets and
host presentation live in `apps/gbloink/rack.edn` and `rack.layla`. Generate the
Rack tree explicitly before building:

```powershell
.\generate.ps1 -App gbloink -Target rack
.\derivatives\vcvrack\build-rack-windows.ps1 -Module gbloink -Package
```

On Linux, use `./generate.sh gbloink rack`, followed by
`./derivatives/vcvrack/build_module.sh gbloink build` from the repository root.
See `docs/BUILD_INSTRUCTIONS.md` for toolchains, installation and load checks.

The module offers three ball speed and MIDI velocity controls, note length,
scale, pause, mute and wall notes. Motion uses elapsed seconds, independently
of host callback cadence. Click the playfield to add/remove blocks. Each ball
has gate, pitch and velocity outputs; `OUTPUTS.md` defines their voltage laws.

The generated panel is `generated/Gbloink.svg` inside the module. Published
snapshots feed the sharp scene, GPU trail history, note-linked collision rings
and block flashes. Graphics resources belong to the widget/context and never
the audio callback. Existing effects finish fading while paused; mute clears
impact effects while ball trails continue.
