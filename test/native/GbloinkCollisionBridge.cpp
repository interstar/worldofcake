#include <hxcpp.h>
#include <hx/Native.h>
#include <HaxeRuntimeBoot.h>
#include <GbloinkControlRunner.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <thread>

void __boot_all();
extern "C" void __hxcpp_lib_main() {
    HX_TOP_OF_STACK
    hx::Boot();
    __boot_all();
}

// No window, capture, audio device or Rack process. Exercise the actual native
// model/harness/runner/snapshot path used by the plugin.
int main(int argc, char** argv) {
    worldofcake::bridge::bootHaxeRuntime();
    hx::NativeAttach attachment;
    worldofcake::bridge::GbloinkControlRunner runner(700, 500, 12345);
    if (argc > 1) {
        std::ifstream input(argv[1]);
        std::ostringstream state;
        state << input.rdbuf();
        if (state.str().empty() || !runner.start(0.001)) return 4;
        runner.importStateJson(state.str());
    }
    int lastSerial = 0, seen = 0;
    for (int step = 0; step < (argc > 1 ? 400 : 1500); ++step) {
        if (argc > 1) std::this_thread::sleep_for(std::chrono::milliseconds(10));
        else runner.pump(0.01);
        const auto snapshot = runner.latestVisualSnapshot();
        if (snapshot.collisionCount < 0 || snapshot.collisionCount > 32) return 2;
        for (int i = 0; i < snapshot.collisionCount; ++i) {
            const auto& cue = snapshot.collisions[i];
            if (cue.serial <= lastSerial) continue;
            lastSerial = cue.serial;
            ++seen;
            const double age = snapshot.collisionModelTime-cue.time;
            if (age < -0.000001 || age > 0.9 || cue.velocity < 1 || cue.velocity > 127) return 3;
            if (seen <= 4) std::cout << "cue serial=" << cue.serial << " kind=" << cue.kind
                << " age=" << age << " velocity=" << cue.velocity << " x=" << cue.x << " y=" << cue.y << '\n';
        }
    }
    std::cout << "native collision cues received=" << seen << '\n';
    runner.stop();
    return seen > 0 ? 0 : 1;
}
