#include "KDiagram.hpp"
#include <WocRackStateJson.hpp>
#include <worldofcake/generated/kdiagram/KdiagramControlMetadataGenerated.h>

namespace
{
    float clampRange(float value, float lo, float hi)
    {
        if (value < lo)
            return lo;
        if (value > hi)
            return hi;
        return value;
    }
} // namespace

json_t* KDiagram::dataToJson()
{
    const auto state = runner->exportStateJson();
    const auto timeouts = runner->stateRequestTimeouts();
    if (timeouts > reportedPersistenceTimeouts) {
        const auto stage = runner->diagnosticStage();
        WARN("WorldOfCake-KDiagram: persistence timeout count=%llu stage=%s stageAgeMs=%llu heartbeatAgeMs=%llu pumps=%llu/%llu exports=%llu/%llu",
             static_cast<unsigned long long>(timeouts),
             worldofcake::bridge::KDiagramControlRunner::diagnosticStageName(stage),
             static_cast<unsigned long long>(runner->diagnosticStageAgeMs()),
             static_cast<unsigned long long>(runner->heartbeatAgeMs()),
             static_cast<unsigned long long>(runner->controlPumpCompletions()),
             static_cast<unsigned long long>(runner->controlPumpStarts()),
             static_cast<unsigned long long>(runner->stateExportCompletions()),
             static_cast<unsigned long long>(runner->stateExportStarts()));
        reportedPersistenceTimeouts = timeouts;
    }
    return worldofcake::rack::makeStateJson(state);
}

void KDiagram::dataFromJson(json_t* root)
{
    auto state = worldofcake::rack::readStateJson(root);
    if (state.empty()) {
        return;
    }
    runner->importStateJson(state);
    const auto snapshot = runner->latestVisualSnapshot();
    for (int i = 0; i < static_cast<int>(kCursorCount); ++i) {
        const float speed = static_cast<float>(snapshot.cursors[i].speed);
        const auto* parameter = std::array<const worldofcake::metadata::kdiagram::Knob*, 3>{
            &worldofcake::metadata::kdiagram::kRedspeed,
            &worldofcake::metadata::kdiagram::kGreenspeed,
            &worldofcake::metadata::kdiagram::kBluespeed}[static_cast<std::size_t>(i)];
        params[SPEED_CURSOR1_PARAM + i].setValue(static_cast<float>(worldofcake::metadata::kdiagram::normalize(*parameter, speed)));
        lastSpeed[i] = speed;
    }
    baseMidiChannel = snapshot.cursors[0].channel;
    const int selected = static_cast<int>(clampRange(static_cast<float>(snapshot.selectedCursor), 0.f, static_cast<float>(worldofcake::metadata::kdiagram::kSelectcursor.choiceCount - 1)));
    params[CURSOR_SELECT_PARAM].setValue(static_cast<float>(selected));
    lastCursor = selected;
    const int scale = static_cast<int>(clampRange(static_cast<float>(snapshot.scaleIndex), 0.f, static_cast<float>(worldofcake::metadata::kdiagram::kScaleselect.choiceCount - 1)));
    params[SCALE_PARAM].setValue(static_cast<float>(scale));
    lastScaleIdx = scale;
    params[NOTE_LENGTH_PARAM].setValue(static_cast<float>(
        worldofcake::metadata::kdiagram::normalize(worldofcake::metadata::kdiagram::kNote_length, snapshot.noteLength)));
    lastNoteLength = static_cast<float>(snapshot.noteLength);
    params[PAUSE_PARAM].setValue(snapshot.paused ? 1.f : 0.f);
    lastPause = snapshot.paused ? 1 : 0;
    params[TERMINUS_PARAM].setValue(snapshot.terminusEnabled ? 1.f : 0.f);
    lastTerminus = snapshot.terminusEnabled ? 1 : 0;
    lastReset = 0.f;
    lastL = 0.f;
    lastR = 0.f;
}
