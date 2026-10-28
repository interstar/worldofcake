# How to use the World of Cake panel editor

The panel editor lets you edit a World of Cake panel's Layla and EDN sources and
see a live, static preview in your browser. It works with the six canonical
OpenFL panels: Gbloink, Goldenpond, KDiagram, TileLand, TimeSliders, and Zewp.

## 1. Start the editor

Open PowerShell and run:

From the repository root:

```powershell
.\panel-editor\run.ps1
```

The script compiles the browser application, then starts the local server. Wait
until the terminal prints:

```text
World of Cake panel editor: http://127.0.0.1:8765
```

Open [the panel editor](http://127.0.0.1:8765/) in your browser. Keep the
PowerShell window running while you use it. The browser does not open
automatically.

Java 17 or later and the Clojure CLI must be installed. No Haxe, OpenFL, Node,
or Python process is required to run this editor. On first use, Clojure may need
to download compiler dependencies, so startup can take longer.

The Layla parser and the target resolver come from the bundled generator JAR
(`vendor/layla/worldofcake-laylagen.jar`); no other checkout is needed.

## 2. Choose a panel

Use the **Panel** menu at the top right. Gbloink opens initially.

The source tabs depend on whether that app has moved to the new `apps/` structure.
The filename beside the tabs always shows the file you are actually editing.

For a migrated app such as TimeSliders:

- **Layla** — `apps/timeslider/openfl.layla`: arrangement and proportions.
- **OpenFL EDN** — `apps/timeslider/openfl.edn`: geometry and presentation,
  including colours, icons, padding, boxes and view hooks.
- **App EDN** — `apps/timeslider/app.edn`: semantics shared with the other
  targets, including labels, ranges, defaults, choices, outputs and model settings.

The preview combines the app definition and OpenFL overlay using the same target
resolver as the build, including any `:extends` chain. Presentation changes
usually belong in OpenFL EDN; semantic changes belong in App EDN and may affect
VST and Rack as well. The editor does not move properties between files for you.

Apps not yet migrated retain two tabs, **Layla** and **EDN**, using
`layouts/openfl/<app>.layla` and `.edn`. As soon as `apps/<app>/app.edn` exists,
the editor switches to the new files on load. It never saves the obsolete
`layouts/` copies for a migrated app.

## 3. Edit and preview

Type directly into either source tab. The preview updates shortly after you
pause typing. Switching tabs retains the text in every source.

For a first experiment, open Gbloink's EDN tab and change the `"Speed"` heading
text. You should see the new heading in the preview. Restore it or reload the
pair if you do not want to keep the experiment.

To change proportions, edit weights in Layla. For example:

```layla
<left(3) right(1)>
```

This gives the left region three times the horizontal space of the right region,
after padding and gaps. Weights are relative to siblings, not pixel dimensions.
In an existing panel, keep its actual component names and change their weights.

Named containers such as `<%red redspeed/knob redvelocity/knob>` can have an EDN
entry named `"red"` defining their box colour, border, and padding. If you add a
new leaf component in Layla, also add its matching entry to the EDN `:components`
map. Removing one generally means removing the other too.

The preview is static. Controls show their EDN defaults and cannot be played or
dragged. Sequencer play areas are black placeholders; TimeSlider lanes show their
dark background. Browser fonts and antialiasing may differ slightly from OpenFL.

## 4. Check the size and spacing

Use **Zoom** above the preview:

- **Fit** scales the complete panel into the available preview area without
  changing its layout.
- **100%** shows one design unit per browser CSS pixel. Scroll the preview area
  if the panel is larger than the available space.
- Other percentages let you inspect smaller or enlarged versions.

The dimensions beside Zoom come from the EDN `:panel-width` and `:panel-height`.
Turn on **Bounds** to display the calculated layout rectangles, including
containers and spacers.

## 5. Save your changes

Click **Save sources** (**Save pair** for legacy apps), or press **Ctrl+S** on Windows (**Cmd+S** on macOS).

This writes the changed sources to the paths shown in the tabs: all three
`apps/<app>/` sources for migrated apps, or the legacy pair under `layouts/openfl/`. There is no separate editor copy to export. Typing alone does
not write anything to disk.

The indicator at the top shows **Unsaved edits** while your text differs from
the loaded files, and **Saved on disk** once it matches the saved pair. The Save
button is disabled when there are no changes or the sources are invalid.

Saving does not regenerate Haxe/C++ output or rebuild OpenFL, VST, or Rack.
Use the normal WoC generation and target build workflow when you want to try the
saved design in an actual application. Rack uses separate source layouts and is
not previewed by this version of the editor.

## 6. Handle errors or discard an experiment

If a source or the merged result becomes invalid, the editor shows an error banner and an orange
outline around the last valid preview. **Preview out of date** means the picture
does not reflect your current source text. Fix the reported problem; the preview
updates and saving becomes available again once the resolved panel is valid.

Common causes include a missing closing bracket, a Layla component without its
EDN entry, an unused EDN entry, or padding and gaps that leave no space for a
component. EDN must contain one complete top-level form; extra text after it is
an error, although comments are allowed.

Click **Reload** to read the current source set from disk and discard your unsaved
edits. The editor asks before discarding changes when reloading or switching
panels. The browser also warns before leaving a page with unsaved edits.

If another program changes a source or inherited overlay after you loaded it, Save refuses to
overwrite the newer disk version. Copy any edits you want to keep, click Reload,
and then reapply them to the updated sources.

## 7. Stop and restart

Save anything you want to keep, then press **Ctrl+C** in the PowerShell window
running the server. Closing the browser tab alone does not stop the server.

For a faster launch after the browser application has already been built:

```powershell
.\panel-editor\run.ps1 -SkipBuild
```

You can use `-SkipBuild` while changing panel Layla/EDN files; these are read at
runtime, including app definitions and target overlays. After changing the editor's ClojureScript code or the Layla parser,
launch without `-SkipBuild` to rebuild, then refresh the browser.

To build without starting a server:

```powershell
.\panel-editor\run.ps1 -BuildOnly
```

To run the editor's automated checks:

```powershell
.\panel-editor\run.ps1 -Test
```

## Troubleshooting startup

**The browser says it cannot connect:** check that the terminal has printed the
server address and is still running. Open the exact address printed there.

**Port 8765 is already in use:** an editor may already be running. Use its browser
page, stop its server, or start another instance on a different port:

```powershell
.\panel-editor\run.ps1 -SkipBuild -Port 8766
```

Then open [port 8766](http://127.0.0.1:8766/).

**PowerShell blocks the script:** if your local execution policy permits a
process-specific override, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\panel-editor\run.ps1
```

This applies to that PowerShell process rather than changing your saved execution
policy.

**Java or Clojure is not recognised:** check `java -version` and `clojure -Sdescribe`
in your terminal, and ensure their installations are available on `PATH`.

**The page loads but the editor does not start:** if you used `-SkipBuild` before
the first successful build, stop the server and run the normal launch command.
After a build completes, refresh the browser page.
