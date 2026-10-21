#include "TileLand.hpp"
#include <WocRackStateJson.hpp>
#include <worldofcake/generated/tileland/TilelandControlMetadataGenerated.h>

namespace
{
    float clampUnit(float value)
    {
        if (value < 0.f)
            return 0.f;
        if (value > 1.f)
            return 1.f;
        return value;
    }
} // namespace

json_t* TileLand::dataToJson()
{
    return worldofcake::rack::makeStateJson(runner->exportStateJson());
}

void TileLand::dataFromJson(json_t* root)
{
    auto state = worldofcake::rack::readStateJson(root);
    if (state.empty()) {
        return;
    }
    runner->importStateJson(state);
    const auto snapshot = runner->latestVisualSnapshot();
    for (int i = 0; i < 3; ++i) {
        const float speed = static_cast<float>(snapshot.cursors[i].speed);
        const auto* parameter = std::array<const worldofcake::metadata::tileland::Knob*, 3>{
            &worldofcake::metadata::tileland::kRedspeed,
            &worldofcake::metadata::tileland::kGreenspeed,
            &worldofcake::metadata::tileland::kBluespeed}[static_cast<std::size_t>(i)];
        params[SPEED_CURSOR1_PARAM + i].setValue(static_cast<float>(worldofcake::metadata::tileland::normalize(*parameter, speed)));
        lastSpeed[i] = speed;
    }
    params[PAUSE_PARAM].setValue(snapshot.paused ? 1.f : 0.f);
    lastPause = snapshot.paused ? 1 : 0;
    lastReset = 0.f;
}
