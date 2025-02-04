# WorldOfCake Framework Overview

## Purpose
WorldOfCake is a framework for creating interactive musical sequencer applications. 

These sequencers generate either MIDI note information, or MIDI CC messages. So can both create musical scores, and modulations of synth sounds etc.

The code is written in Haxe. And the main goal is to have these sequencers on a number of different platforms. Our priorities are : VST plugins via Haxe to C++ compilation. Android apps via Haxe to Java compilation. Web via Haxe to JS compilation. Standalone desktop app via either Haxe to C++ or Haxe to Java.

Future targets may include VCV Rack plugins via Haxe to C++ compilation, platforms that use Lua (Haxe to Lua compilation). And dedicated hardware (maybe through Haxe to C++, or Haxe to MicroPython)

On all these platforms we'll use generic, platform independent Haxe for the algorithmic core of the sequencer.

For some of these sequencer apps, on some plaforms, we'll use platform specific code to implement almost all of the UI components. 

For other apps / platforms, worldofcake includes its own simple UI widgets written in Haxe using OpenFL. This makes it quicker / simpler to get something running on a new platform. Use of this library of UI components is optional.


### Core Architecture

There are two layers of interfaces. The inner layer is the crucial cross-platform definition of a sequencer. It consists of the following interfaces :

- ISequencer in ISequencer.hx. The "model" of the sequencer. Its algorithmic core.

- IControlPanel in IControlPanel.hx. This defines the inputs or commands that can be sent to sequencers from the outer platform. It's how the sequencer is controlled by the user.

- IControlPanelView in IControlPanelView.hx, the "view"  or how the sequencer state is shown to the user. 


Implementations of the ISequencer and IControlPanel should be in pure Haxe and completely platform independent. Of necessity, the implementation of IControlPanelView involves platform / GUI framework specific code. In some cases, the IControlPanelView is implemented using OpenFL, which is itself, somewhat cross-platform.

The outer layer is the application. IF the application is platform specific, it just needs to implement IControlPanelView and its own Main class however it likes.

If we want to use the worldofcake UI components on a platform that supports OpenFL, there should be some kind of "World" class that implements IFullApp. Much of this can be written in Haxe and be run cross-platform. As can most of the IControlPanelView.


It's typical that a World file will be accompanied by a Layout file which specifies in code, the important dimensions and positions of the UI components.

Informally, we have a ui.YAML file which is intended as the single source of truth for the UI layout. (Though note, we do, so far intend to derive the Layout file automatically from it. At the moment it's a reference for human or AI programmers)

### The Apps

Currently there are 5 sequencers apps :

- Gbloink : Balls bounce around a play area. When they collide with blocks, walls or each other, they emit MIDI note messages. Users can add and remove random blocks.

- Zewp : Short lines called "Zewps" move forward until they see something, a wall, block or another Zewp, in front of them. In which case they stop and turn until they see a clear path. Because there are many Zewps the interactions between them become complex and chaotic. Zewps continually emit MIDI CC messages based on their position. Users can drag the block obstacles around the play area.

- Tileland : a grid of Trechet tiles in one of two orientations defines a kind of maze. Three cursors move around the pattern following the lines. By clicking on a tile, the user flips it to the other orientation. This changes the pattern of the maze and the movement of the cursors, which emit MIDI CC.

- KDiagram : a random network of nodes. 3 cursors following statistical paths through it. At each note they randomly choose which new arc to follow based on weightings. The cursors emit both MIDI CC messages based on their position, and MIDI note messages when they arrive at a new node. The user can rotate the network. Click on a node to move a cursor to it. And recreate the network.

- TimeSliders : act like normal slider controls, except they take a certain time to reach the newly clicked destination position. The user can choose the speed of the slider movement, because it depends on the horizontal position of the click within the slider. The sliders emit MIDI CC messages.



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
1. Single source of truth for UI layout in ui.YAML
2. One-way dependencies (View depends on Component, not vice versa)
3. Systematic coordinate mapping rather than ad-hoc transformations
4. Components manage their own state
5. Clear separation between component logic and rendering

## Common Components
- **PlayArea**: Main interactive area unique to each app
- **Sliders**: Standard controls for speed and MIDI channel
  - Vertical sliders for speeds (1-32 range)
  - Horizontal slider for MIDI channel (1-14/16 range)
- More to come ...
