# WorldOfCake Framework Overview

## Purpose
WorldOfCake is a framework for creating interactive musical sequencer applications. 

These sequencers generate either MIDI note information, or MIDI CC messages. So can both create musical scores, and modulations of synth sounds etc.

The code is written in Haxe. And the main goal is to have these sequencers on a number of different platforms. Our priorities are : VST plugins via Haxe to C++ compilation. Android apps via Haxe to Java compilation. Web via Haxe to JS compilation. Standalone desktop app via either Haxe to C++ or Haxe to Java.

VCV Rack plugins are now an active target through Haxe-to-C++ plus a shared native control runner. VST/JUCE is also a near-term target. Potential future targets include platforms that use Lua (Haxe to Lua compilation) and dedicated hardware (maybe through Haxe to C++, or Haxe to MicroPython).

On all these platforms we'll use generic, platform independent Haxe for the algorithmic core of the sequencer.

For some of these sequencer apps, on some plaforms, we'll use platform specific code to implement almost all of the UI components. 

For other apps / platforms, worldofcake includes its own simple UI widgets written in Haxe using OpenFL. This makes it quicker / simpler to get something running on a new platform. 

Use of this library of UI components is optional.


### Core Architecture

There are two layers of interfaces. The inner layer is the crucial cross-platform definition of a sequencer. It consists of the following interfaces :

- ISequencer in ISequencer.hx. The "model" of the sequencer: time stepping (`advanceTime`), the event queue, **transport** (`pause`, `resume`, `reset`), and **patch persistence** (`exportStateJson`, `importStateJson`). Transport and `reset` may no-op where they do not apply; each sequencer owns its JSON shape (use a version field such as `"v"` when it evolves). See `architecture.md` for why these live on `ISequencer` and how hosts use them.

- IControlPanel in IControlPanel.hx. This defines the inputs or commands that can be sent to sequencers from the outer platform. It's how the sequencer is controlled by the user.

- IControlPanelView in IControlPanelView.hx, the "view"  or how the sequencer state is shown to the user. 


Implementations of the ISequencer and IControlPanel should be in pure Haxe and completely platform independent. Of necessity, the implementation of IControlPanelView involves platform / GUI framework specific code. In some cases, the IControlPanelView is implemented using OpenFL, which is itself, somewhat cross-platform.
 
The outer layer is the application. IF the application is platform specific, it just needs to implement IControlPanelView and its own Main class however it likes.

Dependency between the View and the innards (behind the ISequencer and IControlPanel) is one way. The innards should not know or care how the View organizes itself. However we are NOT trying to build a 2-way decoupling of the View and innards, such that, say the View could negotiate discovery of generic innards.

A good example of this last principle : when the View updates a parameter in the sequencer, it will do it by sending a command through IControlPanel call newValue(parameterId:Int, value:Float). Whoever writes the view will have to know which id corresponds to which parameter of the sequencer. This kind of dependency is fine.


As stated above, the use of the worldofcake UI components is optional. (Though only an option on platforms that support OpenFL).And you may take what you like from the framework. 

Typically, you would make some kind of "World" class that implements IFullApp. Much of this can be written in Haxe and be run cross-platform. As can most of the IControlPanelView.


A World file can be accompanied by a Layout file which specifies in code, the important dimensions and positions of the UI components.


Older notes mention `ui.YAML` as the intended layout source of truth. Current work has moved to Layla plus companion EDN files: Layla owns spatial panel composition and the EDN files own component details such as UIDs, ranges, labels, colours, widget hints, and target bindings. Generated Haxe composition and layout constants live under `Source/generated/` and should not be hand-edited.

Rack is expected to need target-specific Layla variants because Rack panels have different proportions, sockets, and control idioms. OpenFL remains the reference implementation for UI layout and behaviour, with Rack and VST adapting that intent where the host requires different physical controls.

### Coordinate Spaces

The gui framework recognises 3 coordinate spaces :

- Window Space : The physical screen coordinates of the component.
- Panel Space : The virtual coordinates of the component, defined in terms of a Control Panel. Often this is the same as the Window coordinates, but not necessarily.
- Local Space : The component's own internalcoordinates, independent of its parent. (These may be relevant for, say, a slider component where you'll need to know where within the component the mouse is currently being dragged)

In order to avoid confusion when passing coordinates around, we have defined three classes of Point object : WindowPoint, PanelPoint and LocalPoint. Most of the functions in the ui framework are explicitly written in terms of these classes. Although this seems like over-engineering, it has proven useful to avoid (or fix) various bugs.

Translation between these three spaces is handled through CoordinateMapper objects. But typically you don't access them directly. All components in the UI framework (via the IComponent interface) have methods for converting between spaces, that are typed in terms of the LocalPoint, PanelPoint and WindowPoint classes.

It is STRONGLY advised that you stick to these functions for all mappings between spaces, rather than introducing ad-hoc translations from one coordinate system to another. This will help avoid bugs.

Components implement the IComponent interface. The ComponentCommon class provides default implementations of the IComponent methods. And other components, such as Slider and PlayArea use it via a composition pattern. Ie. they implement the IComponent interface, but delegate the work to an inner ComponentCommon object.



### The Apps

Currently there are 5 sequencers apps :

- Gbloink : Balls bounce around a play area. When they collide with blocks, walls or each other, they emit MIDI note messages. Users can add and remove random blocks.

- Zewp : Short lines called "Zewps" move forward until they see something - a wall, block or another Zewp - in front of them. In which case they stop and turn until they see a clear path. Because there are many Zewps the interactions between them become complex and chaotic. Zewps continually emit MIDI CC messages based on their position. Users can drag the block obstacles around the play area.

- Tileland : a grid of Trechet tiles in one of two orientations defines a kind of maze. Three cursors move around the pattern following the lines. By clicking on a tile, the user flips it to the other orientation. This changes the pattern of the maze and the movement of the cursors, which emit MIDI CC.

- KDiagram : a random network of nodes. 3 cursors following statistical paths through it. At each note they randomly choose which new arc to follow based on weightings. The cursors emit both MIDI CC messages based on their position, and MIDI note messages when they arrive at a new node. The user can rotate the network. Click on a node to move a cursor to it. And recreate the network.

- TimeSliders : four wide parallel slider tracks; each moves toward the clicked level over a **travel time** chosen by horizontal position on a **log** scale (defaults: ~two minutes at the far left, ~half a second at the far right). The sliders emit MIDI CC messages. Note that TimeSliders are not part of the worldofcake.ui library. They are a custom type of sequencer.



### Important UI Component Model Details
- Apps are built from reusable UI components (sliders, play areas)
- Each component has a unique ID and manages its own state 
- Components exist in multiple coordinate spaces (local, panel, window) 
- Coordinate mapping between spaces is handled systematically through CoordinateMapper


### Coordinate Spaces
- **Window Space**: Physical screen coordinates
- **Panel Space**: Virtual coordinates for layout
- **Local Space**: Component-specific coordinates
- All coordinate transformations are managed through mapper objects

## Standard App Structure
1. **Main**: Entry point, creates World
2. **World**: Implements IFullApp
   - Creates and manages components
   - Handles mouse events
   - Routes events to appropriate components
3. **Layout**: Constants defining UI dimensions and positions
4. **Sequencer**: Manages musical state and MIDI output
5. **View**: Handles rendering of components

## Design Decisions
1. Single source of truth for UI layout in Layla plus companion EDN metadata; `ui.YAML` is historical reference material
2. One-way dependencies (View depends on Component, not vice versa)
3. Systematic coordinate mapping rather than ad-hoc transformations
4. Components manage their own state
5. Transport and model snapshot hooks on `ISequencer` so every host steps, pauses, resets, and persists through the same contract (details in `architecture.md`).

## Common Components
- **PlayArea**: Main interactive area unique to each app
- **Sliders**: Which can be both vertical and horizontal
- More to come ...

## Native Host Boundary

Rack and VST hosts should not call Haxe from a hard real-time audio callback. The current native boundary under `bridge/` uses a control thread, two bounded SPSC command queues (GUI/message and host/audio), prepared event queues, continuous-control snapshots, visual snapshots, and JSON persistence mailboxes. The host audio side consumes prepared native data only.

This runner contract is already proven for the five current apps. Rack modules should use this boundary rather than the older direct-Haxe facade pattern where `Module::process()` entered Haxe under a mutex.
