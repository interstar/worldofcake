#pragma once

#include <juce_audio_basics/juce_audio_basics.h>

#include <array>
#include <cstddef>
#include <cstdint>

namespace worldofcake::jucehost
{
    /**
        Fixed-capacity MIDI trigger scheduler used by the audio thread.

        Gbloink currently emits trigger events rather than paired note events,
        so the VST shell creates a short, bounded note and schedules its note-off.
        No allocation or Haxe call occurs here.
    */
    class WocMidiScheduler
    {
      public:
        void prepare(double newSampleRate) noexcept;
        void reset(juce::MidiBuffer* panicOutput = nullptr) noexcept;
        bool queueTrigger(std::int64_t sampleTime, std::uint64_t transportEpoch,
                          int channel, int note, int velocity) noexcept;
        bool queueNoteOff(std::int64_t sampleTime, std::uint64_t transportEpoch,
                          int channel, int note) noexcept;
        void renderBlock(juce::MidiBuffer& output, std::int64_t blockStart,
                         int blockSize, std::uint64_t transportEpoch) noexcept;
        void emitDueNoteOffs(juce::MidiBuffer& output, int blockSize) noexcept;

      private:
        struct ActiveNote
        {
            int channel = 1;
            int note = 60;
            int samplesRemaining = 0;
            bool active = false;
        };

        struct PendingTrigger
        {
            std::int64_t sampleTime = 0;
            std::uint64_t transportEpoch = 0;
            int channel = 1;
            int note = 60;
            int velocity = 100;
            bool noteOff = false;
            bool active = false;
        };

        void addTrigger(juce::MidiBuffer& output, int channel, int note, int velocity,
                        int sampleOffset, int blockSize) noexcept;

        static constexpr std::size_t capacity = 64;
        static constexpr double triggerLengthSeconds = 0.050;
        std::array<ActiveNote, capacity> notes{};
        std::array<PendingTrigger, capacity> pending{};
        double sampleRate = 44100.0;
    };
}
