#include "WocMidiScheduler.h"

#include <iostream>
#include <vector>

namespace
{
    struct Captured
    {
        int offset = 0;
        bool noteOn = false;
        bool noteOff = false;
        int note = -1;
    };

    std::vector<Captured> capture(const juce::MidiBuffer& buffer)
    {
        std::vector<Captured> result;
        for (const auto metadata : buffer) {
            const auto message = metadata.getMessage();
            result.push_back({metadata.samplePosition, message.isNoteOn(), message.isNoteOff(), message.getNoteNumber()});
        }
        return result;
    }

    bool require(bool condition, const char* message)
    {
        if (!condition)
            std::cerr << "FAIL " << message << '\n';
        return condition;
    }
}

int main()
{
    worldofcake::jucehost::WocMidiScheduler scheduler;
    scheduler.prepare(1000.0);
    bool ok = true;

    ok &= require(scheduler.queueTrigger(20, 7, 1, 60, 100), "queue trigger");

    juce::MidiBuffer first;
    scheduler.renderBlock(first, 0, 32, 7);
    const auto firstEvents = capture(first);
    ok &= require(firstEvents.size() == 1, "one event in first block");
    ok &= require(firstEvents.size() == 1 && firstEvents[0].noteOn && firstEvents[0].offset == 20,
                  "note-on keeps exact block offset");

    juce::MidiBuffer second;
    scheduler.renderBlock(second, 32, 32, 7);
    ok &= require(second.isEmpty(), "note remains active through second block");

    juce::MidiBuffer third;
    scheduler.renderBlock(third, 64, 32, 7);
    const auto thirdEvents = capture(third);
    ok &= require(thirdEvents.size() == 1 && thirdEvents[0].noteOff && thirdEvents[0].offset == 6,
                  "note-off keeps duration across block boundaries");

    ok &= require(scheduler.queueTrigger(100, 8, 2, 64, 90), "queue next-epoch trigger");
    juce::MidiBuffer stale;
    scheduler.renderBlock(stale, 96, 32, 9);
    ok &= require(stale.isEmpty(), "stale transport epoch is discarded");

    ok &= require(scheduler.queueTrigger(80, 9, 3, 67, 80), "queue late same-epoch trigger");
    juce::MidiBuffer late;
    scheduler.renderBlock(late, 96, 32, 9);
    const auto lateEvents = capture(late);
    ok &= require(lateEvents.size() == 1 && lateEvents[0].noteOn && lateEvents[0].offset == 0,
                  "late same-epoch trigger is emitted at block start");

    if (!ok)
        return 1;
    std::cout << "All WorldOfCake MIDI scheduler tests passed\n";
    return 0;
}
