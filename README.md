## World of Cake

A Haxe/C++ framework for writing experimental music sequencers.

In particular for writing generative simulations and interactive worlds that emit musical events.

The framework and the sequencers are largely written in the [Haxe language](https://haxe.org/). This was chosen because of its ability to compile to many other languages and platforms. Especially C++, JS, Java and Python.

WoC's main targets are currently :
* [OpenFL](https://www.openfl.org/). A Haxe graphics toolkit in which we can prototype the interactivity. From Haxe/OpenFL we can also compile to browser-ready JS.
* [JUCE](https://juce.com/) / VST. JUCE is the standard C++ framework for writing VST plugins for DAWs such as FL Studio and Ableton.
* [VCV Rack](https://vcvrack.com/). Rack is a popular open-source virtual modular synthesizer. Again, the framework uses C++. 




See the [architecture overview](docs/architecture.md) for architectural overview


`Source/` directory is for Haxe code.

`bridge/` directory is for C++ and connections to the Haxe.

`derivatives/` directory is for target platform specific 



I'm putting this on github and gitlab just to have a public URL for the code right now. It is not very well documented, so get in touch if you're interested in working with WoC.

### AI Disclosure

This code is written with AI. This codebase has been touched by Codex, Claude, DeepSeek and Cursor.  I, as human overseer, pay close attention to the data-structures and the interfaces between the modules. I am on top of the overall architecture of the system. But I do not review every individual line of code.

