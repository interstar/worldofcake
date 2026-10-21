#include "PluginEditor.h"
#include <algorithm>
#include <cmath>
#include <worldofcake/generated/goldenpond/GoldenpondControlIdsGenerated.h>
#include "WocJuceCoordinateMapper.h"
#include "WocJuceEditorSupport.h"
#include "worldofcake/generated/juce/goldenpond/LayoutGenerated.h"
#include "worldofcake/generated/goldenpond/GoldenpondControlMetadataGenerated.h"

GoldenpondAudioProcessorEditor::GoldenpondAudioProcessorEditor(GoldenpondAudioProcessor& p)
    : AudioProcessorEditor(p), processor(p) {
    setSize(static_cast<int>(worldofcake::juce_layout::goldenpond::kPanelWidth),
            static_cast<int>(worldofcake::juce_layout::goldenpond::kPanelHeight));
    for (std::size_t i = 0; i < knobs.size(); ++i) {
        auto& s = knobs[i];
        s.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
        // Octave and velocity are discrete musical controls.  OpenFL does not
        // display a numeric readout for these compact knobs, so leave the
        // JUCE text box off too; the generated metadata still owns the range.
        if (i < 8)
            s.setTextBoxStyle(juce::Slider::NoTextBox, false, 0, 0);
        else
            s.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 48, 18);
        addAndMakeVisible(s);
    }
    // In a DAW the host tempo is authoritative. Keep the shared BPM control
    // visible for cross-target layout consistency, but make it read-only.
    knobs[8].setEnabled(false);
    const worldofcake::metadata::goldenpond::Knob* knobMetadata[] = {
        &worldofcake::metadata::goldenpond::kOctave0, &worldofcake::metadata::goldenpond::kVelocity0,
        &worldofcake::metadata::goldenpond::kOctave1, &worldofcake::metadata::goldenpond::kVelocity1,
        &worldofcake::metadata::goldenpond::kOctave2, &worldofcake::metadata::goldenpond::kVelocity2,
        &worldofcake::metadata::goldenpond::kOctave3, &worldofcake::metadata::goldenpond::kVelocity3,
        &worldofcake::metadata::goldenpond::kBpm, &worldofcake::metadata::goldenpond::kChordduration,
        &worldofcake::metadata::goldenpond::kZoom};
    for (std::size_t i = 0; i < knobs.size(); ++i) {
        const double interval = i < 8 ? 1.0 : 0.01;
        knobs[i].setName(knobMetadata[i]->shortLabel);
        knobs[i].setTooltip(knobMetadata[i]->tooltip);
        knobs[i].setRange(knobMetadata[i]->minimum, knobMetadata[i]->maximum, interval);
        knobs[i].setNumDecimalPlacesToDisplay(i < 8 ? 0 : 2);
        knobs[i].setValue(knobMetadata[i]->defaultValue, juce::dontSendNotification);
    }
    for (std::size_t i = 0; i < selects.size(); ++i) addAndMakeVisible(selects[i]);
    const worldofcake::metadata::goldenpond::SemanticSelect* selectMetadata[] = {
        &worldofcake::metadata::goldenpond::kKeyselect, &worldofcake::metadata::goldenpond::kModeselect,
        &worldofcake::metadata::goldenpond::kCorrectiontarget};
    for (std::size_t i = 0; i < selects.size(); ++i) { selects[i].setName(selectMetadata[i]->label); selects[i].setTooltip(selectMetadata[i]->tooltip); }
    for (std::size_t i = 0; i < selects.size(); ++i) for (std::size_t j = 0; j < selectMetadata[i]->choiceCount; ++j)
        selects[i].addItem(selectMetadata[i]->choices[j].label, static_cast<int>(j + 1));
    for (auto& s : selects) s.setSelectedItemIndex(0, juce::dontSendNotification);
    for (auto& t : texts) { t.setMultiLine(false); addAndMakeVisible(t); }
    addAndMakeVisible(reset); addAndMakeVisible(pause); addAndMakeVisible(mute);
    processor.requestVisualSnapshot();
    // Musical octave/velocity controls commit once per drag, rather than
    // sending every intermediate pixel value through the Haxe bridge.  The
    // score is only useful at the final quantized value and recompiling on
    // every mouse movement can race persistence/audio work and flood the
    // command queue. Other knobs retain continuous updates.
    for (std::size_t i = 0; i < knobs.size(); ++i) {
        const int id = knobMetadata[i]->controlId;
        pendingKnobValues[i] = knobs[i].getValue();
        knobs[i].onValueChange = [this, i, id] {
            pendingKnobValues[i] = knobs[i].getValue();
            if (i >= 8) processor.sendValue(id, pendingKnobValues[i]);
        };
        if (i < 8) {
            knobs[i].onDragEnd = [this, i, id] {
                processor.sendValue(id, pendingKnobValues[i]);
            };
        }
    }
    for (std::size_t i = 0; i < selects.size(); ++i) { const int id = selectMetadata[i]->controlId; selects[i].onChange = [this, i, id] { processor.sendValue(id, selects[i].getSelectedId() - 1); }; }
    const worldofcake::metadata::goldenpond::TextInput* textMetadata[] = {
        &worldofcake::metadata::goldenpond::kChordinput, &worldofcake::metadata::goldenpond::kRhythm0,
        &worldofcake::metadata::goldenpond::kRhythm1, &worldofcake::metadata::goldenpond::kRhythm2,
        &worldofcake::metadata::goldenpond::kRhythm3};
    for (std::size_t i = 0; i < texts.size(); ++i) {
        texts[i].setName(textMetadata[i]->label);
        texts[i].setTooltip(textMetadata[i]->tooltip);
        texts[i].setText(textMetadata[i]->defaultText, juce::dontSendNotification);
        const int id = textMetadata[i]->controlId;
        auto commit = [this, i, id] { processor.sendText(id, texts[i].getText()); };
        texts[i].onReturnKey = commit;
        texts[i].onFocusLostCallback = commit;
    }
    reset.onClick = [this] { processor.sendValue(worldofcake::control::goldenpond::kReset, 1); };
    pause.onClick = [this] { processor.sendValue(worldofcake::control::goldenpond::kPause, pause.getToggleState() ? 1 : 0); };
    mute.onClick = [this] { processor.setOutputMuted(mute.getToggleState()); };
    startTimerHz(30);
}

GoldenpondAudioProcessorEditor::~GoldenpondAudioProcessorEditor() {
    stopTimer();
    for (auto& text : texts) {
        text.onReturnKey = {};
        text.onFocusLostCallback = {};
    }
    for (auto& knob : knobs) { knob.onValueChange = {}; knob.onDragStart = {}; knob.onDragEnd = {}; }
    for (auto& select : selects) select.onChange = {};
    reset.onClick = {};
    pause.onClick = {};
    mute.onClick = {};
}

void GoldenpondAudioProcessorEditor::timerCallback() {
    if (hydratedStateRevision == 0) processor.requestVisualSnapshot();
    auto next = processor.visualSnapshot();
    if (next.generation != snapshot.generation) {
        snapshot = std::move(next);
        // The processor owns GoldenData. Rehydrate editor text fields from the
        // latest model snapshot whenever an editor is created or reopened.
        if (snapshot.stateRevision != hydratedStateRevision) {
            texts[0].setText(snapshot.chordInput, juce::dontSendNotification);
            for (std::size_t i = 0; i < 4; ++i)
                texts[i + 1].setText(snapshot.rhythmInputs[i], juce::dontSendNotification);
            for (std::size_t i = 0; i < 4; ++i) {
                knobs[i * 2].setValue(snapshot.octaves[i], juce::dontSendNotification);
                knobs[i * 2 + 1].setValue(snapshot.velocities[i], juce::dontSendNotification);
            }
            hydratedStateRevision = snapshot.stateRevision;
        }
        if (std::abs(knobs[8].getValue() - snapshot.bpm) > 0.001)
            knobs[8].setValue(snapshot.bpm, juce::dontSendNotification);
        pause.setToggleState(snapshot.paused, juce::dontSendNotification);
        mute.setToggleState(snapshot.muted, juce::dontSendNotification);
        repaint(playArea);
    }
}

void GoldenpondAudioProcessorEditor::resized() {
    const worldofcake::jucehost::WocJuceCoordinateMapper map(
        worldofcake::juce_layout::goldenpond::kPanelWidth,
        worldofcake::juce_layout::goldenpond::kPanelHeight,
        getLocalBounds());
    playArea = worldofcake::jucehost::panelRegion(
                   map, worldofcake::juce_layout::goldenpond::kPlayarea)
                   .toNearestInt();
    const juce::Rectangle<double> knobRegions[] = {worldofcake::juce_layout::goldenpond::kOctave0, worldofcake::juce_layout::goldenpond::kVelocity0, worldofcake::juce_layout::goldenpond::kOctave1, worldofcake::juce_layout::goldenpond::kVelocity1, worldofcake::juce_layout::goldenpond::kOctave2, worldofcake::juce_layout::goldenpond::kVelocity2, worldofcake::juce_layout::goldenpond::kOctave3, worldofcake::juce_layout::goldenpond::kVelocity3, worldofcake::juce_layout::goldenpond::kBpm, worldofcake::juce_layout::goldenpond::kChordduration, worldofcake::juce_layout::goldenpond::kZoom};
    for (std::size_t i = 0; i < knobs.size(); ++i) knobs[i].setBounds(worldofcake::jucehost::panelRegion(map, knobRegions[i]).toNearestInt());
    const juce::Rectangle<double> selectRegions[] = {worldofcake::juce_layout::goldenpond::kKeyselect, worldofcake::juce_layout::goldenpond::kModeselect, worldofcake::juce_layout::goldenpond::kCorrectiontarget};
    for (std::size_t i = 0; i < selects.size(); ++i) selects[i].setBounds(worldofcake::jucehost::panelRegion(map, selectRegions[i]).toNearestInt());
    const juce::Rectangle<double> textRegions[] = {worldofcake::juce_layout::goldenpond::kChordinput, worldofcake::juce_layout::goldenpond::kRhythm0, worldofcake::juce_layout::goldenpond::kRhythm1, worldofcake::juce_layout::goldenpond::kRhythm2, worldofcake::juce_layout::goldenpond::kRhythm3};
    for (std::size_t i = 0; i < texts.size(); ++i) texts[i].setBounds(worldofcake::jucehost::panelRegion(map, textRegions[i]).toNearestInt());
    reset.setBounds(worldofcake::jucehost::panelRegion(map, worldofcake::juce_layout::goldenpond::kReset).toNearestInt());
    pause.setBounds(worldofcake::jucehost::panelRegion(map, worldofcake::juce_layout::goldenpond::kPause).toNearestInt());
    mute.setBounds(worldofcake::jucehost::panelRegion(map, worldofcake::juce_layout::goldenpond::kMute).toNearestInt());
}

void GoldenpondAudioProcessorEditor::paint(juce::Graphics& g) {
    g.fillAll(juce::Colour(0xff101218));
    const worldofcake::jucehost::WocJuceCoordinateMapper map(
        worldofcake::juce_layout::goldenpond::kPanelWidth,
        worldofcake::juce_layout::goldenpond::kPanelHeight,
        getLocalBounds());
    worldofcake::jucehost::drawPanelTitle(
        g, "WorldOfCake - Goldenpond",
        worldofcake::jucehost::panelRegion(map, worldofcake::juce_layout::goldenpond::kTitle)
            .toNearestInt());
    g.setColour(juce::Colours::darkgrey);
    g.fillRect(playArea);
    if (snapshot.notes.empty()) {
        worldofcake::jucehost::drawPanelLabel(g, "Goldenpond play area", playArea.toFloat());
        return;
    }
    int lowest = 127, highest = 0;
    for (const auto& note : snapshot.notes) { lowest = std::min(lowest, note.pitch); highest = std::max(highest, note.pitch); }
    const int pitchSpan = std::max(36, highest - lowest + 5);
    const double centre = (lowest + highest) * 0.5;
    lowest = static_cast<int>(std::floor(centre - pitchSpan * 0.5));
    lowest = std::max(0, std::min(127 - pitchSpan + 1, lowest));
    // Keep the score fixed in the play area, as Rack does.  Only the playhead
    // advances; notes must never scroll outside the generated play-area bounds.
    const double visibleLength = std::max(1.0, snapshot.loopLengthTicks);
    const double windowStart = 0.0;
    const auto colours = std::array<juce::Colour, 4>{juce::Colour(0xff55b7d9), juce::Colour(0xffe56b6f), juce::Colour(0xff76b947), juce::Colour(0xffc58be8)};
    for (const auto& note : snapshot.notes) {
        const double noteStart = note.startTick, noteEnd = noteStart + note.durationTicks;
        if (noteEnd <= 0.0 || noteStart >= visibleLength) continue;
        auto x = (noteStart - windowStart) / visibleLength * playArea.getWidth();
        auto w = std::max(2.0, note.durationTicks / visibleLength * playArea.getWidth());
        auto y = playArea.getHeight() - (note.pitch - lowest + 1.0) / pitchSpan * playArea.getHeight();
        auto h = std::max(3.0, playArea.getHeight() / pitchSpan * 0.8);
        g.setColour(colours[static_cast<std::size_t>(std::abs(note.partId)) % colours.size()]);
        const auto clippedX = std::max(0.0, x);
        const auto clippedW = std::min(w + (x < 0.0 ? x : 0.0), static_cast<double>(playArea.getWidth()) - clippedX);
        if (clippedW > 0.0)
            g.fillRect(juce::Rectangle<float>((float)(playArea.getX() + clippedX), (float)(playArea.getY() + y), (float)clippedW, (float)h));
    }
    const auto loopPosition = std::fmod(std::max(0.0, snapshot.positionTicks), visibleLength);
    const auto playhead = playArea.getX() + (loopPosition - windowStart) / visibleLength * playArea.getWidth();
    g.setColour(juce::Colours::white.withAlpha(0.8f));
    g.drawLine((float)playhead, (float)playArea.getY(), (float)playhead, (float)playArea.getBottom(), 2.0f);
}
