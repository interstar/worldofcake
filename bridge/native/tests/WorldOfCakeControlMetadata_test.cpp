#include "../worldofcake/generated/gbloink/GbloinkControlMetadataGenerated.h"
#include "../worldofcake/generated/goldenpond/GoldenpondControlMetadataGenerated.h"
#include "../WorldOfCakeOutputMapping.h"

#include <cassert>
#include <cmath>
#include <cstring>

int main()
{
    using namespace worldofcake::metadata;

    const auto& speed = gbloink::kRedspeed;
    assert(std::strcmp(speed.mapping, "logarithmic") == 0);
    assert(std::strcmp(speed.unit, "speed") == 0);
    assert(std::strcmp(speed.output, "midi-note") == 0);
    for (double value : {speed.minimum, 0.2, speed.defaultValue, 1.0, speed.maximum}) {
        const double normalized = gbloink::normalize(speed, value);
        const double restored = gbloink::denormalize(speed, normalized);
        assert(std::abs(restored - value) < 1e-9);
    }

    const auto& velocity = goldenpond::kVelocity0;
    assert(std::strcmp(velocity.unit, "midi-velocity") == 0);
    assert(std::strcmp(velocity.output, "midi-note") == 0);
    assert(std::abs(goldenpond::normalize(velocity, velocity.minimum)) < 1e-12);
    assert(std::abs(goldenpond::normalize(velocity, velocity.maximum) - 1.0) < 1e-12);
    assert(goldenpond::kKeyselect.choiceCount == 12);
    assert(goldenpond::kKeyselect.choices[goldenpond::kKeyselect.defaultIndex].value == 0.0);

    assert(worldofcake::output::normalizedToMidi7(-1.0) == 0);
    assert(worldofcake::output::normalizedToMidi7(1.0) == 127);
    assert(std::abs(worldofcake::output::normalizedToUnipolar10V(0.5) - 5.0) < 1e-12);
    assert(std::abs(worldofcake::output::normalizedToBipolar5V(0.5)) < 1e-12);
    assert(std::abs(worldofcake::output::midiNoteToOneVoltPerOctave(72) - 1.0) < 1e-12);
    assert(worldofcake::output::gate10V(true) == 10.0);
}
