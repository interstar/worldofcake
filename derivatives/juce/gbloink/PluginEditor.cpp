#include "PluginEditor.h"

#include "WorldOfCakeControlIds.h"
#include "WocJuceCoordinateMapper.h"
#include "WocJuceEditorSupport.h"
#include "worldofcake/generated/juce/gbloink/LayoutGenerated.h"
#include "worldofcake/generated/gbloink/GbloinkControlMetadataGenerated.h"

#include <cmath>

namespace
{
    juce::Colour snapshotColour(int rgb, float alpha = 1.0f)
    {
        return juce::Colour(static_cast<juce::uint8>((rgb >> 16) & 0xff),
                            static_cast<juce::uint8>((rgb >> 8) & 0xff),
                            static_cast<juce::uint8>(rgb & 0xff)).withAlpha(alpha);
    }
}

GbloinkAudioProcessorEditor::GbloinkAudioProcessorEditor(GbloinkAudioProcessor& p)
    : AudioProcessorEditor(p), processor(p)
{
    setOpaque(true);
    setSize(static_cast<int>(worldofcake::juce_layout::gbloink::kPanelWidth),
            static_cast<int>(worldofcake::juce_layout::gbloink::kPanelHeight));

    const std::array<juce::Colour, 3> colours{juce::Colours::red,
                                              juce::Colours::lime,
                                              juce::Colours::dodgerblue};
    for (int i = 0; i < 3; ++i)
        configureSpeedSlider(speedSliders[static_cast<std::size_t>(i)], i,
                             colours[static_cast<std::size_t>(i)]);

    const auto& scale = worldofcake::metadata::gbloink::kScaleselect;
    for (std::size_t i = 0; i < scale.choiceCount; ++i)
        scaleSelect.addItem(scale.choices[i].label, static_cast<int>(i + 1));
    scaleSelect.onChange = [this] {
        sendValue(worldofcake::control::gbloink::kScaleSelect,
                  static_cast<double>(scaleSelect.getSelectedItemIndex()));
    };
    addAndMakeVisible(scaleSelect);

    edgeNotes.onClick = [this] {
        sendValue(worldofcake::control::gbloink::kEdgeNotes,
                  edgeNotes.getToggleState() ? 1.0 : 0.0);
    };
    addAndMakeVisible(edgeNotes);

    reset.onClick = [this] {
        sendValue(worldofcake::control::gbloink::kReset, 1.0);
    };
    addAndMakeVisible(reset);
    addAndMakeVisible(mute);
    addAndMakeVisible(pause);
    mute.onClick = [this] { processor.setOutputMuted(mute.getToggleState()); };
    pause.onClick = [this] { sendValue(worldofcake::control::gbloink::kPause, pause.getToggleState() ? 1.0 : 0.0); };

    transportStatus.setJustificationType(juce::Justification::centredLeft);
    transportStatus.setColour(juce::Label::textColourId, juce::Colours::lightgrey);
    addAndMakeVisible(transportStatus);

    diagnosticsLabel.setJustificationType(juce::Justification::topLeft);
    diagnosticsLabel.setColour(juce::Label::textColourId, juce::Colours::lightgrey);
    diagnosticsLabel.setFont(12.0f);
    addAndMakeVisible(diagnosticsLabel);

    startTimerHz(60);
}

void GbloinkAudioProcessorEditor::configureSpeedSlider(juce::Slider& slider, int index,
                                                        juce::Colour colour)
{
    slider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    slider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 62, 20);
    const auto* metadata = std::array<const worldofcake::metadata::gbloink::Knob*, 3>{
        &worldofcake::metadata::gbloink::kRedspeed,
        &worldofcake::metadata::gbloink::kGreenspeed,
        &worldofcake::metadata::gbloink::kBluespeed}[static_cast<std::size_t>(index)];
    slider.setRange(metadata->minimum, metadata->maximum, 0.01);
    slider.setSkewFactorFromMidPoint(std::sqrt(metadata->minimum * metadata->maximum));
    slider.setValue(metadata->defaultValue, juce::dontSendNotification);
    slider.setColour(juce::Slider::rotarySliderFillColourId, colour);
    slider.onValueChange = [this, &slider, index] {
        sendValue(worldofcake::control::gbloink::speedUid(index), slider.getValue());
    };
    addAndMakeVisible(slider);

    auto& label = speedLabels[static_cast<std::size_t>(index)];
    const char* names[] = {"Red speed", "Green speed", "Blue speed"};
    label.setText(names[index], juce::dontSendNotification);
    label.setJustificationType(juce::Justification::centred);
    label.setColour(juce::Label::textColourId, colour.brighter(0.25f));
    addAndMakeVisible(label);
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
    if (next.generation != displayedGeneration) {
        displayedGeneration = next.generation;
        snapshot = std::move(next);
        edgeNotes.setToggleState(snapshot.edgeNotes, juce::dontSendNotification);
        scaleSelect.setSelectedItemIndex(snapshot.scaleIndex, juce::dontSendNotification);
        for (std::size_t i = 0; i < speedSliders.size(); ++i)
            speedSliders[i].setValue(snapshot.ballSpeeds[i], juce::dontSendNotification);
        pause.setToggleState(snapshot.paused, juce::dontSendNotification);
        mute.setToggleState(snapshot.muted, juce::dontSendNotification);
        repaint(playArea);
    }
    const auto diagnostic = processor.diagnostics();
    transportStatus.setText(juce::String("Host: ") + (diagnostic.hostPlaying ? "playing" : "stopped") +
                                " / Model: " + (snapshot.paused ? "paused" : "running"),
                            juce::dontSendNotification);
    diagnosticsLabel.setText(
        "Haxe events: " + juce::String(diagnostic.haxePrepared) +
        "\nBridge received: " + juce::String(diagnostic.bridgeReceived) +
        "\nTriggers queued: " + juce::String(diagnostic.triggersQueued) +
        "\nMIDI emitted: " + juce::String(diagnostic.midiMessagesEmitted) +
        "\nStale events: " + juce::String(diagnostic.staleEvents),
        juce::dontSendNotification);
}

void GbloinkAudioProcessorEditor::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff20232b));
    g.setColour(juce::Colour(0xff12141a));
    g.fillRoundedRectangle(playArea.toFloat(), 5.0f);
    g.setColour(juce::Colour(0xff404754));
    g.drawRoundedRectangle(playArea.toFloat(), 5.0f, 1.0f);

    const worldofcake::jucehost::WocJuceCoordinateMapper map(700.0, 500.0, playArea);
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
        const float cx = centre.x;
        const float cy = centre.y;
        g.setColour(snapshotColour(ball.colour));
        g.fillEllipse(cx - radius, cy - radius, radius * 2.0f, radius * 2.0f);
    }

    g.setColour(juce::Colours::white);
    g.setFont(22.0f);
    g.drawText("WorldOfCake - Gbloink!", 18, 8, 700, 32,
               juce::Justification::centredLeft);
    g.setColour(juce::Colours::lightgrey);
    g.setFont(13.0f);
    g.drawText("Click the field to add or remove note blocks", playArea.getX(),
               playArea.getBottom() + 5, playArea.getWidth(), 22,
               juce::Justification::centredLeft);
}

void GbloinkAudioProcessorEditor::resized()
{
    const worldofcake::jucehost::WocJuceCoordinateMapper map(
        worldofcake::juce_layout::gbloink::kPanelWidth,
        worldofcake::juce_layout::gbloink::kPanelHeight,
        getLocalBounds());
    playArea = worldofcake::jucehost::panelRegion(map, worldofcake::juce_layout::gbloink::kPlayarea).toNearestInt();
    const juce::Rectangle<double> speedRegions[] = {worldofcake::juce_layout::gbloink::kRedspeed, worldofcake::juce_layout::gbloink::kGreenspeed, worldofcake::juce_layout::gbloink::kBluespeed};
    for (int i = 0; i < 3; ++i) {
        auto region = worldofcake::jucehost::panelRegion(map, speedRegions[i]).toNearestInt();
        speedLabels[static_cast<std::size_t>(i)].setBounds(region.removeFromTop(20));
        speedSliders[static_cast<std::size_t>(i)].setBounds(region);
    }
    scaleSelect.setBounds(worldofcake::jucehost::panelRegion(map, worldofcake::juce_layout::gbloink::kScaleselect).toNearestInt());
    edgeNotes.setBounds(worldofcake::jucehost::panelRegion(map, worldofcake::juce_layout::gbloink::kEdge_notes).toNearestInt());
    reset.setBounds(worldofcake::jucehost::panelRegion(map, worldofcake::juce_layout::gbloink::kReset).toNearestInt());
    mute.setBounds(worldofcake::jucehost::panelRegion(map, worldofcake::juce_layout::gbloink::kMute).toNearestInt());
    pause.setBounds(worldofcake::jucehost::panelRegion(map, worldofcake::juce_layout::gbloink::kPause).toNearestInt());
    transportStatus.setBounds(worldofcake::jucehost::panelRegion(map, worldofcake::juce_layout::gbloink::kControltop).toNearestInt());
    diagnosticsLabel.setBounds(worldofcake::jucehost::panelRegion(map, worldofcake::juce_layout::gbloink::kControlbottom).toNearestInt());
}

void GbloinkAudioProcessorEditor::mouseDown(const juce::MouseEvent& event)
{
    if (!playArea.contains(event.getPosition()))
        return;

    worldofcake::bridge::ControlCommand command;
    command.kind = worldofcake::bridge::CommandKind::playAreaClick;
    command.controlId = worldofcake::control::gbloink::kPlayArea;
    const worldofcake::jucehost::WocJuceCoordinateMapper map(700.0, 500.0, playArea);
    const auto modelPoint = map.toModel(event.position);
    command.x = modelPoint.x;
    command.y = modelPoint.y;
    processor.enqueueGuiCommand(command);
}
