#include "PluginEditor.h"

#include "WorldOfCakeControlIds.h"
#include "WocJuceCoordinateMapper.h"
#include "WocJuceEditorSupport.h"
#include "worldofcake/generated/juce/gbloink/LayoutGenerated.h"
#include "worldofcake/generated/gbloink/GbloinkControlMetadataGenerated.h"

namespace
{
    namespace layout = worldofcake::juce_layout::gbloink;
    namespace metadata = worldofcake::metadata::gbloink;
    namespace host = worldofcake::jucehost;

    juce::Colour snapshotColour(int rgb, float alpha = 1.0f)
    {
        return juce::Colour(static_cast<juce::uint8>((rgb >> 16) & 0xff),
                            static_cast<juce::uint8>((rgb >> 8) & 0xff),
                            static_cast<juce::uint8>(rgb & 0xff)).withAlpha(alpha);
    }

    const std::array<const metadata::Knob*, 3> speedMetadata{&metadata::kRedspeed, &metadata::kGreenspeed, &metadata::kBluespeed};
    const std::array<const juce::Rectangle<double>*, 3> speedRegions{&layout::kRedspeed, &layout::kGreenspeed, &layout::kBluespeed};
    const std::array<const metadata::Knob*, 3> velocityMetadata{&metadata::kRedvelocity, &metadata::kGreenvelocity, &metadata::kBluevelocity};
    const std::array<const juce::Rectangle<double>*, 3> velocityRegions{&layout::kRedvelocity, &layout::kGreenvelocity, &layout::kBluevelocity};
}

GbloinkAudioProcessorEditor::GbloinkAudioProcessorEditor(GbloinkAudioProcessor& p)
    : AudioProcessorEditor(p), processor(p)
{
    setOpaque(true);
    setLookAndFeel(&lookAndFeel);

    for (std::size_t i = 0; i < speedSliders.size(); ++i) {
        auto& slider = speedSliders[i];
        host::configureKnob(slider, *speedMetadata[i]);
        slider.onValueChange = [this, &slider, i] {
            sendValue(worldofcake::control::gbloink::speedUid(static_cast<int>(i)), slider.getValue());
        };
        addAndMakeVisible(slider);

        auto& velocity = velocitySliders[i];
        host::configureKnob(velocity, *velocityMetadata[i], 1.0);
        velocity.onValueChange = [this, &velocity, i] {
            sendValue(worldofcake::control::gbloink::noteVelocityUid(static_cast<int>(i)), velocity.getValue());
        };
        addAndMakeVisible(velocity);
    }

    host::configureKnob(noteLength, metadata::kNote_length);
    noteLength.onValueChange = [this] { sendValue(worldofcake::control::gbloink::kNoteLength, noteLength.getValue()); };
    addAndMakeVisible(noteLength);

    const auto& scale = metadata::kScaleselect;
    for (std::size_t i = 0; i < scale.choiceCount; ++i)
        scaleSelect.addItem(scale.choices[i].label, static_cast<int>(i + 1));
    scaleSelect.setTooltip(scale.label);
    scaleSelect.onChange = [this] {
        sendValue(worldofcake::control::gbloink::kScaleSelect,
                  static_cast<double>(scaleSelect.getSelectedItemIndex()));
    };
    addAndMakeVisible(scaleSelect);

    // Toggles display the model's flags (see timerCallback) and ask the model to
    // flip them; they hold no state of their own.
    edgeNotes.onClick = [this] {
        sendValue(worldofcake::control::gbloink::kEdgeNotes, snapshot.edgeNotes ? 0.0 : 1.0);
    };
    reset.onClick = [this] { processor.enqueueGuiCommand(worldofcake::bridge::resetCommand()); };
    pause.onClick = [this] { processor.enqueueGuiCommand(worldofcake::bridge::pauseCommand(!snapshot.paused)); };
    mute.onClick = [this] { processor.enqueueGuiCommand(worldofcake::bridge::muteCommand(!snapshot.muted)); };
    for (auto* button : {&reset, &pause, &mute, &edgeNotes})
        addAndMakeVisible(button);

    // The panel scales with the window; keep the generated layout's proportions.
    setResizable(true, true);
    setResizeLimits(static_cast<int>(layout::kPanelWidth * 0.5), static_cast<int>(layout::kPanelHeight * 0.5),
                    static_cast<int>(layout::kPanelWidth * 3.0), static_cast<int>(layout::kPanelHeight * 3.0));
    if (auto* constrainer = getConstrainer())
        constrainer->setFixedAspectRatio(layout::kPanelWidth / layout::kPanelHeight);
    setSize(static_cast<int>(layout::kPanelWidth), static_cast<int>(layout::kPanelHeight));

    startTimerHz(60);
}

GbloinkAudioProcessorEditor::~GbloinkAudioProcessorEditor()
{
    setLookAndFeel(nullptr);
}

worldofcake::jucehost::WocJuceCoordinateMapper GbloinkAudioProcessorEditor::panelMapper() const
{
    return host::WocJuceCoordinateMapper(layout::kPanelWidth, layout::kPanelHeight, getLocalBounds());
}

void GbloinkAudioProcessorEditor::sendValue(int controlId, double value)
{
    worldofcake::bridge::ControlCommand command;
    command.kind = worldofcake::bridge::CommandKind::setValue;
    command.controlId = controlId;
    command.value = value;
    processor.enqueueGuiCommand(command);
}

void GbloinkAudioProcessorEditor::timerCallback()
{
    auto next = processor.visualSnapshot();
    if (next.generation == displayedGeneration)
        return;
    displayedGeneration = next.generation;
    snapshot = std::move(next);
    // Follow model changes only, so a pending user edit is never overwritten.
    shownEdgeNotes.update(snapshot.edgeNotes, [this](bool v) { edgeNotes.setToggleState(v, juce::dontSendNotification); });
    shownScale.update(snapshot.scaleIndex, [this](int v) { scaleSelect.setSelectedItemIndex(v, juce::dontSendNotification); });
    for (std::size_t i = 0; i < speedSliders.size(); ++i)
        shownSpeeds[i].update(snapshot.ballSpeeds[i], [this, i](double v) { speedSliders[i].setValue(v, juce::dontSendNotification); });
    for (std::size_t i = 0; i < velocitySliders.size(); ++i)
        shownVelocities[i].update(snapshot.ballNoteVelocities[i], [this, i](int v) { velocitySliders[i].setValue(v, juce::dontSendNotification); });
    shownNoteLength.update(snapshot.noteLength, [this](double v) { noteLength.setValue(v, juce::dontSendNotification); });
    shownPaused.update(snapshot.paused, [this](bool v) { pause.setToggleState(v, juce::dontSendNotification); });
    shownMuted.update(snapshot.muted, [this](bool v) { mute.setToggleState(v, juce::dontSendNotification); });
    repaint(playArea);
}

void GbloinkAudioProcessorEditor::paint(juce::Graphics& g)
{
    const auto panel = panelMapper();
    g.fillAll(host::chrome::background);
    host::paintBoxes(g, panel, layout::kBoxes);
    host::paintText(g, host::panelRegion(panel, layout::kSpeed_heading), metadata::kSpeed_heading);
    host::paintText(g, host::panelRegion(panel, layout::kVelocity_heading), metadata::kVelocity_heading);
    host::paintText(g, host::panelRegion(panel, layout::kNote_length_heading), metadata::kNote_length_heading);

    g.setColour(host::chrome::playArea);
    g.fillRoundedRectangle(playArea.toFloat(), host::chrome::corner * 1.5f);

    const host::WocJuceCoordinateMapper map(700.0, 500.0, playArea);
    for (const auto& block : snapshot.blocks) {
        const auto bounds = map.toView(block.left, block.top,
                                       block.right - block.left,
                                       block.bottom - block.top);
        g.setColour(snapshotColour(block.colour, 0.78f));
        g.fillRect(bounds);
    }
    for (const auto& ball : snapshot.balls) {
        const auto centre = map.toView(ball.x, ball.y);
        const auto edge = map.toView(ball.x + ball.radius, ball.y + ball.radius);
        const float radius = std::min(std::abs(edge.x - centre.x),
                                      std::abs(edge.y - centre.y));
        g.setColour(snapshotColour(ball.colour));
        g.fillEllipse(centre.x - radius, centre.y - radius, radius * 2.0f, radius * 2.0f);
    }
}

void GbloinkAudioProcessorEditor::resized()
{
    const auto map = panelMapper();
    auto place = [&map](juce::Component& component, const juce::Rectangle<double>& region) {
        component.setBounds(host::panelRegion(map, region).toNearestInt());
    };
    playArea = host::panelRegion(map, layout::kPlayarea).toNearestInt();
    for (std::size_t i = 0; i < speedSliders.size(); ++i)
    {
        place(speedSliders[i], *speedRegions[i]);
        place(velocitySliders[i], *velocityRegions[i]);
    }
    place(noteLength, layout::kNote_length);
    place(scaleSelect, layout::kScaleselect);
    place(reset, layout::kReset);
    place(pause, layout::kPause);
    place(mute, layout::kMute);
    place(edgeNotes, layout::kEdge_notes);
}

void GbloinkAudioProcessorEditor::mouseDown(const juce::MouseEvent& event)
{
    if (!playArea.contains(event.getPosition()))
        return;

    worldofcake::bridge::ControlCommand command;
    command.kind = worldofcake::bridge::CommandKind::playAreaClick;
    command.controlId = worldofcake::control::gbloink::kPlayArea;
    const host::WocJuceCoordinateMapper map(700.0, 500.0, playArea);
    const auto modelPoint = map.toModel(event.position);
    command.x = modelPoint.x;
    command.y = modelPoint.y;
    processor.enqueueGuiCommand(command);
}
