#include "WocMidiScheduler.h"

#include <algorithm>
#include <cmath>

namespace worldofcake::jucehost
{
    void WocMidiScheduler::prepare(double newSampleRate) noexcept
    {
        if (std::isfinite(newSampleRate) && newSampleRate > 0.0)
            sampleRate = newSampleRate;
        reset();
    }

    void WocMidiScheduler::reset(juce::MidiBuffer* panicOutput) noexcept
    {
        for (auto& active : notes) {
            if (active.active && panicOutput != nullptr)
                panicOutput->addEvent(juce::MidiMessage::noteOff(active.channel, active.note), 0);
            active.active = false;
            active.samplesRemaining = 0;
        }
        for (auto& trigger : pending)
            trigger.active = false;
        if (panicOutput != nullptr) {
            for (int channel = 1; channel <= 16; ++channel)
                panicOutput->addEvent(juce::MidiMessage::allNotesOff(channel), 0);
        }
    }

    bool WocMidiScheduler::queueTrigger(std::int64_t sampleTime, std::uint64_t transportEpoch,
                                        int channel, int note, int velocity) noexcept
    {
        for (auto& trigger : pending) {
            if (trigger.active)
                continue;
            trigger.sampleTime = std::max<std::int64_t>(0, sampleTime);
            trigger.transportEpoch = transportEpoch;
            trigger.channel = channel;
            trigger.note = note;
            trigger.velocity = velocity;
            trigger.noteOff = false;
            trigger.active = true;
            return true;
        }
        return false;
    }

    bool WocMidiScheduler::queueNoteOff(std::int64_t sampleTime, std::uint64_t transportEpoch,
                                        int channel, int note) noexcept
    {
        for (auto& trigger : pending) {
            if (trigger.active) continue;
            trigger.sampleTime = std::max<std::int64_t>(0, sampleTime);
            trigger.transportEpoch = transportEpoch;
            trigger.channel = channel;
            trigger.note = note;
            trigger.velocity = 0;
            trigger.noteOff = true;
            trigger.active = true;
            return true;
        }
        return false;
    }

    void WocMidiScheduler::renderBlock(juce::MidiBuffer& output, std::int64_t blockStart,
                                       int blockSize, std::uint64_t transportEpoch) noexcept
    {
        emitDueNoteOffs(output, blockSize);
        const auto blockEnd = blockStart + blockSize;
        for (auto& trigger : pending) {
            if (!trigger.active)
                continue;
            if (trigger.transportEpoch != transportEpoch) {
                trigger.active = false;
                continue;
            }
            if (trigger.sampleTime >= blockEnd)
                continue;
            const auto offset = static_cast<int>(std::max<std::int64_t>(0, trigger.sampleTime - blockStart));
            if (trigger.noteOff)
                output.addEvent(juce::MidiMessage::noteOff(std::clamp(trigger.channel, 1, 16), std::clamp(trigger.note, 0, 127)), std::clamp(offset, 0, std::max(0, blockSize - 1)));
            else
                addTrigger(output, trigger.channel, trigger.note, trigger.velocity, offset, blockSize);
            trigger.active = false;
        }
    }

    void WocMidiScheduler::addTrigger(juce::MidiBuffer& output, int channel, int note, int velocity,
                                      int sampleOffset, int blockSize) noexcept
    {
        channel = std::clamp(channel, 1, 16);
        note = std::clamp(note, 0, 127);
        velocity = std::clamp(velocity, 1, 127);
        sampleOffset = std::clamp(sampleOffset, 0, std::max(0, blockSize - 1));

        ActiveNote* slot = nullptr;
        for (auto& active : notes) {
            if (active.active && active.channel == channel && active.note == note) {
                output.addEvent(juce::MidiMessage::noteOff(channel, note), sampleOffset);
                slot = &active;
                break;
            }
            if (!active.active && slot == nullptr)
                slot = &active;
        }
        if (slot == nullptr)
            return;

        output.addEvent(juce::MidiMessage::noteOn(channel, note, static_cast<juce::uint8>(velocity)), sampleOffset);
        const auto durationSamples = std::max(1, static_cast<int>(std::lround(sampleRate * triggerLengthSeconds)));
        const auto noteOffOffset = sampleOffset + durationSamples;
        if (noteOffOffset < blockSize) {
            output.addEvent(juce::MidiMessage::noteOff(channel, note), noteOffOffset);
            slot->active = false;
            slot->samplesRemaining = 0;
            return;
        }
        slot->channel = channel;
        slot->note = note;
        slot->samplesRemaining = noteOffOffset - blockSize;
        slot->active = true;
    }

    void WocMidiScheduler::emitDueNoteOffs(juce::MidiBuffer& output, int blockSize) noexcept
    {
        for (auto& active : notes) {
            if (!active.active)
                continue;
            if (active.samplesRemaining < blockSize) {
                output.addEvent(juce::MidiMessage::noteOff(active.channel, active.note),
                                std::max(0, active.samplesRemaining));
                active.active = false;
                active.samplesRemaining = 0;
            } else {
                active.samplesRemaining -= blockSize;
            }
        }
    }
}
