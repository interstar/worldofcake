#include "TimeSlider.hpp"
#include <WocRackStateJson.hpp>

json_t* TimeSlider::dataToJson()
{
    return worldofcake::rack::makeStateJson(runner->exportStateJson());
}

void TimeSlider::dataFromJson(json_t* root)
{
    auto state = worldofcake::rack::readStateJson(root);
    if (state.empty()) {
        return;
    }
    runner->importStateJson(state);
    const auto snapshot = runner->latestVisualSnapshot();
    params[PAUSE_PARAM].setValue(snapshot.paused ? 1.f : 0.f);
    lastPause = snapshot.paused ? 1 : 0;
    lastReset = 0.f;
}
