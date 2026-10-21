# VCV Rack Plugin Development: A Comprehensive Guide

VCV Rack is a virtual modular synthesizer that models **Eurorack standards**, where discrete **modules** are interconnected via virtual cables carrying **voltages**. A **plugin** is a software unit that can contain multiple modules. This guide provides the technical specifications and workflow required for both human developers and coding agents to build plugins using the VCV Rack SDK.

---

## 1. Development Environment Setup

To compile Rack plugins, you must establish a build environment capable of compiling C++11 code.

### Operating System Prerequisites
*   **Windows**: Install **MSYS2** and use the **MinGW 64-bit shell** (not the default MSYS shell). Ensure anti-virus software is disabled during builds to prevent interference.
*   **macOS**: Install **Homebrew** and the necessary build dependencies.
*   **Linux**: For Ubuntu 16.04+, install `build-essential`, `binutils`, and other development libraries via `apt`.

### The Rack SDK
The **Rack SDK** is the fastest method to build plugins as it does not require compiling the entire Rack source code.
1.  **Download**: Obtain the SDK for your specific architecture (Windows x64, Mac x64/ARM64, or Linux x64).
2.  **Extract**: Place the SDK in a folder with **no spaces** in its absolute path, as spaces will break the Makefile-based build system.
3.  **Environment Variable**: Set the `RACK_DIR` variable to the absolute path of the extracted SDK. 
    *   Example: `export RACK_DIR=<path/to/Rack-SDK>`.
    *   Add this to your `~/.bashrc` or shell profile for persistence.

---

## 2. Project Structure and the Manifest

Every plugin requires a `plugin.json` file at its root to define its identity.

### Key Manifest Fields (`plugin.json`)
*   **slug**: A unique identifier (e.g., "MyCompany-MyPlugin"). It must only contain letters, numbers, hyphens, and underscores. **Never change the slug after release**, as it will break user patches.
*   **version**: Must follow `MAJOR.MINOR.REVISION`. The **MAJOR version must match the version of Rack** (e.g., version 2.x.x for Rack 2).
*   **modules**: An array containing objects for each module, including their own `slug`, `name`, and `tags` (e.g., "Oscillator", "Filter", "Polyphonic").

### Scaffolding
Use the `helper.py` script included in the SDK to create a template:
`python3 $RACK_DIR/helper.py createplugin <slug>`.

---

## 3. Panel Design: Wiring the SVG

VCV Rack uses **SVG files** created in **Inkscape** to define module panels.

### SVG Specifications
*   **Units**: In "Document Properties", set both "Units" and "Display units" to **mm**.
*   **Dimensions**: The height must be exactly **128.5 mm**. The width must be a multiple of **5.08 mm** (1 HP).
*   **Text**: All text must be converted to **paths** (`Path > Object to Path` in Inkscape) because the Rack renderer does not support raw font objects.

### Creating "Placeholders" for Code
To link the visual panel to C++ logic, you must "wire" the components using a specific layer:
1.  Create a layer named **`components`**.
2.  Use the **Circle Tool** to place shapes where you want ports or knobs. The **center point** of the circle determines the component's position.
3.  Set the **Color** of the shape to define the component type:
    *   **Param (Knob/Switch)**: Red (`#ff0000`).
    *   **Input Port**: Green (`#00ff00`).
    *   **Output Port**: Blue (`#0000ff`).
    *   **Light**: Magenta (`#ff00ff`).
4.  Use the **Object Properties** (Shift+Ctrl+O) to set a **Label** for each shape (e.g., "PITCH_KNOB"). These labels will become variable names in C++.
5.  Hide the `components` layer before saving to `res/<module-slug>.svg`.

---

## 4. The Module API and Implementation

Once the SVG is ready, generate the C++ source:
`python3 $RACK_DIR/helper.py createmodule <module-slug> res/<module-slug>.svg src/<module-slug>.cpp`.

### The `Module` Class (The Engine)
This class handles the **Digital Signal Processing (DSP)**. It must implement the `process()` function.

*   **`process(const ProcessArgs& args)`**: Called every audio frame (e.g., 44,100 times per second).
*   **`args.sampleTime`**: The duration of one sample (1 / sample rate).

### The Four API Basics
1.  **Params**: `params[NAME].getValue()` — Returns the position of a knob/switch.
2.  **Inputs**: `inputs[NAME].getVoltage()` — Reads the incoming voltage from a port.
3.  **Outputs**: `outputs[NAME].setVoltage(v)` — Sends a voltage out to a port.
4.  **Lights**: `lights[NAME].setBrightness(b)` — Sets the visual intensity of an LED.

---

## 5. Sample Module: Simple Sine Oscillator

The following is a conceptual C++ implementation of a sine oscillator with a pitch input and a blinking light.

```cpp
struct MyModule : Module {
    float phase = 0.f;
    float blinkPhase = 0.f;

    enum ParamIds { PITCH_PARAM, NUM_PARAMS };
    enum InputIds { PITCH_INPUT, NUM_INPUTS };
    enum OutputIds { SINE_OUTPUT, NUM_OUTPUTS };
    enum LightIds { BLINK_LIGHT, NUM_LIGHTS };

    MyModule() {
        // Configure parameters with (id, min, max, default, label)
        configParam(PITCH_PARAM, -1.f, 1.f, 0.f, "Pitch");
    }

    void process(const ProcessArgs& args) override {
        // 1. Calculate Frequency based on 1V/oct standard
        float pitch = params[PITCH_PARAM].getValue();
        pitch += inputs[PITCH_INPUT].getVoltage();
        // C4 (middle C) is the baseline frequency
        float freq = dsp::FREQ_C4 * std::pow(2.f, pitch);

        // 2. Update Oscillator Phase
        phase += freq * args.sampleTime;
        if (phase >= 1.f) phase -= 1.f;

        // 3. Set Sine Output (Standard ±5V audio)
        float sine = std::sin(2.f * M_PI * phase);
        outputs[SINE_OUTPUT].setVoltage(5.f * sine);

        // 4. Update Blinking Light (1 Hz)
        blinkPhase += 1.f * args.sampleTime;
        if (blinkPhase >= 1.f) blinkPhase -= 1.f;
        lights[BLINK_LIGHT].setBrightness(blinkPhase < 0.5f ? 1.f : 0.f);
    }
};
```

---

## 6. Voltage Standards and Rules

To ensure your module works with others, follow these **Voltage Standards**:
*   **Audio**: Typically **±5 V**.
*   **CV (Control Voltage)**: **0 to 10 V** (unipolar) or **±5 V** (bipolar).
*   **Pitch**: Use **1 V/octave**. Frequency $f = f_0 \cdot 2^V$.
*   **Triggers**: Should produce **10 V** for **1 ms**. Use a **Schmitt Trigger** for inputs to avoid false retriggering from bandlimited signals.
*   **Polyphony**: If supporting multiple channels, use `Port::getPolyVoltage(channel)` for inputs. Support up to **16 channels**.
*   **Safety**: If an algorithm (like an IIR filter) becomes unstable, check with `std::isfinite()` and return **0** if it produces NaNs or Infinity.

---

## 7. Compiling and Using in VCV Rack

### Build Commands
Navigate to your plugin directory and use the following:
*   **`make`**: Compiles the plugin.
*   **`make install`**: Compiles and copies the plugin to your **Rack user folder**.
*   **`make dist`**: Creates a `.vcvplugin` package in the `dist/` folder for distribution.

### Plugin Locations
`make install` moves your plugin to:
*   **Mac**: `~/Library/Application Support/Rack2/plugins/`
*   **Windows**: `C:\Users\<username>\AppData\Local\Rack2\plugins\`
*   **Linux**: `~/.local/share/Rack2/plugins/`

### Testing
Open VCV Rack and search for your module in the **Module Browser**. If it does not appear or Rack crashes, check the **`log.txt`** file in the Rack user folder for detailed error messages.
