#include "PluginEditor.h"
#include <algorithm>
#include <cmath>
#include <utility>
#include <worldofcake/generated/goldenpond/GoldenpondControlIdsGenerated.h>
#include "WocJuceCoordinateMapper.h"
#include "WocJuceEditorSupport.h"
#include "worldofcake/generated/juce/goldenpond/LayoutGenerated.h"
#include "worldofcake/generated/goldenpond/GoldenpondControlMetadataGenerated.h"

namespace {
namespace layout = worldofcake::juce_layout::goldenpond;
namespace metadata = worldofcake::metadata::goldenpond;
namespace host = worldofcake::jucehost;

// Knob order: each part's octave then velocity (0..7), then BPM, chord length, zoom.
constexpr std::size_t kPartKnobs = 8;
constexpr std::size_t kBpmKnob = 8;
const std::array<const metadata::Knob*, 11> knobMetadata{
    &metadata::kOctave0, &metadata::kVelocity0, &metadata::kOctave1, &metadata::kVelocity1,
    &metadata::kOctave2, &metadata::kVelocity2, &metadata::kOctave3, &metadata::kVelocity3,
    &metadata::kBpm, &metadata::kChordduration, &metadata::kZoom};
const std::array<const juce::Rectangle<double>*, 11> knobRegions{
    &layout::kOctave0, &layout::kVelocity0, &layout::kOctave1, &layout::kVelocity1,
    &layout::kOctave2, &layout::kVelocity2, &layout::kOctave3, &layout::kVelocity3,
    &layout::kBpm, &layout::kChordduration, &layout::kZoom};
const std::array<const metadata::SemanticSelect*, 3> selectMetadata{
    &metadata::kKeyselect, &metadata::kModeselect, &metadata::kCorrectiontarget};
const std::array<const juce::Rectangle<double>*, 3> selectRegions{
    &layout::kKeyselect, &layout::kModeselect, &layout::kCorrectiontarget};
const std::array<const metadata::TextInput*, 5> textMetadata{
    &metadata::kChordinput, &metadata::kRhythm0, &metadata::kRhythm1, &metadata::kRhythm2, &metadata::kRhythm3};
const std::array<const juce::Rectangle<double>*, 5> textRegions{
    &layout::kChordinput, &layout::kRhythm0, &layout::kRhythm1, &layout::kRhythm2, &layout::kRhythm3};
const std::array<std::pair<const juce::Rectangle<double>*, const metadata::Text*>, 3> headings{{
    {&layout::kRhythm_heading, &metadata::kRhythm_heading},
    {&layout::kOctave_heading, &metadata::kOctave_heading},
    {&layout::kVelocity_heading, &metadata::kVelocity_heading}}};
// Part note colours, matching the part boxes and the OpenFL piano roll.
const std::array<juce::Colour, 4> partColours{juce::Colour(0xff55b7d9), juce::Colour(0xffe56b6f),
                                              juce::Colour(0xff76b947), juce::Colour(0xffc58be8)};
}

GoldenpondAudioProcessorEditor::GoldenpondAudioProcessorEditor(GoldenpondAudioProcessor& p)
    : AudioProcessorEditor(p), processor(p) {
    setOpaque(true);
    setLookAndFeel(&lookAndFeel);

    // Octave and velocity are discrete musical controls and commit once per drag,
    // rather than sending every intermediate value through the Haxe bridge: the
    // score is only useful at the final value, and recompiling on every mouse
    // movement can race persistence/audio work and flood the command queue.
    for (std::size_t i = 0; i < knobs.size(); ++i) {
        auto& knob = knobs[i];
        host::configureKnob(knob, *knobMetadata[i], i < kPartKnobs ? 1.0 : 0.01);
        knob.setName(knobMetadata[i]->shortLabel);
        const int id = knobMetadata[i]->controlId;
        pendingKnobValues[i] = knob.getValue();
        knob.onValueChange = [this, i, id] {
            pendingKnobValues[i] = knobs[i].getValue();
            if (i >= kPartKnobs) processor.sendValue(id, pendingKnobValues[i]);
        };
        if (i < kPartKnobs)
            knob.onDragEnd = [this, i, id] { processor.sendValue(id, pendingKnobValues[i]); };
        addAndMakeVisible(knob);
    }
    // In a DAW the host tempo is authoritative: the BPM knob shows it, read-only.
    knobs[kBpmKnob].setEnabled(false);

    for (std::size_t i = 0; i < selects.size(); ++i) {
        auto& select = selects[i];
        const auto& m = *selectMetadata[i];
        select.setName(m.label);
        select.setTooltip(host::tooltipFor(m.tooltip, m.label));
        for (std::size_t j = 0; j < m.choiceCount; ++j)
            select.addItem(m.choices[j].label, static_cast<int>(j + 1));
        select.setSelectedItemIndex(0, juce::dontSendNotification);
        const int id = m.controlId;
        select.onChange = [this, i, id] { processor.sendValue(id, selects[i].getSelectedId() - 1); };
        addAndMakeVisible(select);
    }

    for (std::size_t i = 0; i < texts.size(); ++i) {
        auto& text = texts[i];
        const auto& m = *textMetadata[i];
        text.setMultiLine(false);
        text.setName(m.label);
        text.setTooltip(host::tooltipFor(m.tooltip, m.label));
        text.setText(m.defaultText, juce::dontSendNotification);
        const int id = m.controlId;
        auto commit = [this, i, id] { processor.sendText(id, texts[i].getText()); };
        text.onReturnKey = commit;
        text.onFocusLostCallback = commit;
        addAndMakeVisible(text);
    }

    // Pause and mute display the model's flags (see timerCallback) and ask the
    // model to flip them; they hold no state of their own.
    reset.onClick = [this] { processor.enqueueGuiCommand(worldofcake::bridge::resetCommand()); };
    pause.onClick = [this] { processor.enqueueGuiCommand(worldofcake::bridge::pauseCommand(!snapshot.paused)); };
    mute.onClick = [this] { processor.enqueueGuiCommand(worldofcake::bridge::muteCommand(!snapshot.muted)); };
    for (auto* button : {&reset, &pause, &mute})
        addAndMakeVisible(button);

    // The panel scales with the window; keep the generated layout's proportions.
    setResizable(true, true);
    setResizeLimits(static_cast<int>(layout::kPanelWidth * 0.5), static_cast<int>(layout::kPanelHeight * 0.5),
                    static_cast<int>(layout::kPanelWidth * 3.0), static_cast<int>(layout::kPanelHeight * 3.0));
    if (auto* constrainer = getConstrainer())
        constrainer->setFixedAspectRatio(layout::kPanelWidth / layout::kPanelHeight);
    setSize(static_cast<int>(layout::kPanelWidth), static_cast<int>(layout::kPanelHeight));

    processor.requestVisualSnapshot();
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
    setLookAndFeel(nullptr);
}

worldofcake::jucehost::WocJuceCoordinateMapper GoldenpondAudioProcessorEditor::panelMapper() const {
    return host::WocJuceCoordinateMapper(layout::kPanelWidth, layout::kPanelHeight, getLocalBounds());
}

void GoldenpondAudioProcessorEditor::timerCallback() {
    if (hydratedStateRevision == 0) processor.requestVisualSnapshot();
    auto next = processor.visualSnapshot();
    if (next.generation == snapshot.generation)
        return;
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
    // Follow model changes only, so a pending user edit is never overwritten.
    shownBpm.update(snapshot.bpm, [this](double v) { knobs[kBpmKnob].setValue(v, juce::dontSendNotification); });
    shownPaused.update(snapshot.paused, [this](bool v) { pause.setToggleState(v, juce::dontSendNotification); });
    shownMuted.update(snapshot.muted, [this](bool v) { mute.setToggleState(v, juce::dontSendNotification); });
    repaint(playArea);
}

void GoldenpondAudioProcessorEditor::resized() {
    const auto map = panelMapper();
    playArea = host::panelRegion(map, layout::kPlayarea).toNearestInt();
    for (std::size_t i = 0; i < knobs.size(); ++i)
        knobs[i].setBounds(host::knobBounds(host::panelRegion(map, *knobRegions[i]), *knobMetadata[i]));
    for (std::size_t i = 0; i < selects.size(); ++i)
        selects[i].setBounds(host::panelRegion(map, *selectRegions[i]).toNearestInt());
    for (std::size_t i = 0; i < texts.size(); ++i)
        texts[i].setBounds(host::textFieldBounds(host::panelRegion(map, *textRegions[i])));
    reset.setBounds(host::panelRegion(map, layout::kReset).toNearestInt());
    pause.setBounds(host::panelRegion(map, layout::kPause).toNearestInt());
    mute.setBounds(host::panelRegion(map, layout::kMute).toNearestInt());
}

void GoldenpondAudioProcessorEditor::paint(juce::Graphics& g) {
    const auto map = panelMapper();
    g.fillAll(host::chrome::background);
    host::paintBoxes(g, map, layout::kBoxes);
    for (const auto& heading : headings)
        host::paintText(g, host::panelRegion(map, *heading.first), *heading.second);
    for (std::size_t i = 0; i < knobs.size(); ++i)
        host::paintKnobLabel(g, host::panelRegion(map, *knobRegions[i]), *knobMetadata[i]);
    paintScore(g);
}

void GoldenpondAudioProcessorEditor::paintScore(juce::Graphics& g) {
    g.setColour(host::chrome::playArea);
    g.fillRoundedRectangle(playArea.toFloat(), host::chrome::corner * 1.5f);
    if (snapshot.compileError) {
        g.setColour(juce::Colour(0xbfc8525c));
        g.drawRoundedRectangle(playArea.toFloat().reduced(0.5f), host::chrome::corner * 1.5f, 1.0f);
    }
    if (snapshot.notes.empty())
        return;
    int lowest = 127, highest = 0;
    for (const auto& note : snapshot.notes) { lowest = std::min(lowest, note.pitch); highest = std::max(highest, note.pitch); }
    const int pitchSpan = std::max(36, highest - lowest + 5);
    const double centre = (lowest + highest) * 0.5;
    lowest = static_cast<int>(std::floor(centre - pitchSpan * 0.5));
    lowest = std::max(0, std::min(127 - pitchSpan + 1, lowest));
    // Keep the score fixed in the play area, as Rack does.  Only the playhead
    // advances; notes must never scroll outside the generated play-area bounds.
    const double visibleLength = std::max(1.0, snapshot.loopLengthTicks);
    for (const auto& note : snapshot.notes) {
        const double noteStart = note.startTick, noteEnd = noteStart + note.durationTicks;
        if (noteEnd <= 0.0 || noteStart >= visibleLength) continue;
        auto x = noteStart / visibleLength * playArea.getWidth();
        auto w = std::max(2.0, note.durationTicks / visibleLength * playArea.getWidth());
        auto y = playArea.getHeight() - (note.pitch - lowest + 1.0) / pitchSpan * playArea.getHeight();
        auto h = std::max(3.0, playArea.getHeight() / pitchSpan * 0.8);
        g.setColour(partColours[static_cast<std::size_t>(std::abs(note.partId)) % partColours.size()]);
        const auto clippedX = std::max(0.0, x);
        const auto clippedW = std::min(w + (x < 0.0 ? x : 0.0), static_cast<double>(playArea.getWidth()) - clippedX);
        if (clippedW > 0.0)
            g.fillRect(juce::Rectangle<float>((float)(playArea.getX() + clippedX), (float)(playArea.getY() + y), (float)clippedW, (float)h));
    }
    const auto loopPosition = std::fmod(std::max(0.0, snapshot.positionTicks), visibleLength);
    const auto playhead = playArea.getX() + loopPosition / visibleLength * playArea.getWidth();
    g.setColour(juce::Colours::white.withAlpha(0.8f));
    g.drawLine((float)playhead, (float)playArea.getY(), (float)playhead, (float)playArea.getBottom(), 2.0f);
}
