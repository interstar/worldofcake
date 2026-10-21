#pragma once
#include "PluginProcessor.h"
#include <juce_gui_extra/juce_gui_extra.h>
#include <functional>

class WocCommitTextEditor final : public juce::TextEditor {
public:
    std::function<void()> onFocusLostCallback;
    void focusLost(juce::Component::FocusChangeType cause) override {
        juce::TextEditor::focusLost(cause);
        if (onFocusLostCallback) onFocusLostCallback();
    }
};

class GoldenpondAudioProcessorEditor final : public juce::AudioProcessorEditor, private juce::Timer {
public:
    explicit GoldenpondAudioProcessorEditor(GoldenpondAudioProcessor&);
    ~GoldenpondAudioProcessorEditor() override;
    void paint(juce::Graphics&) override;
    void resized() override;

private:
    GoldenpondAudioProcessor& processor;
    juce::Rectangle<int> playArea;
    std::array<juce::Slider, 11> knobs;
    std::array<double, 11> pendingKnobValues{};
    std::array<juce::ComboBox, 3> selects;
    std::array<WocCommitTextEditor, 5> texts;
    juce::TextButton reset{"Reset"};
    juce::ToggleButton pause{"Pause"};
    juce::ToggleButton mute{"Mute output"};
    worldofcake::bridge::GoldenpondVisualSnapshot snapshot;
    std::uint64_t hydratedStateRevision = 0;
    void timerCallback() override;
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(GoldenpondAudioProcessorEditor)
};
