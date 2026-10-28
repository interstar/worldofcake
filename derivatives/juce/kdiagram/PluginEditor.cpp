#include "PluginEditor.h"

#include "WorldOfCakeControlIds.h"
#include "WocJuceCoordinateMapper.h"
#include "WocJuceEditorSupport.h"
#include "worldofcake/generated/juce/kdiagram/LayoutGenerated.h"
#include "worldofcake/generated/kdiagram/KdiagramControlMetadataGenerated.h"

namespace
{
    namespace layout = worldofcake::juce_layout::kdiagram;
    namespace metadata = worldofcake::metadata::kdiagram;
    namespace ids = worldofcake::control::kdiagram;
    namespace host = worldofcake::jucehost;

    const std::array<const metadata::Knob*, 3> speedMetadata{&metadata::kRedspeed, &metadata::kGreenspeed, &metadata::kBluespeed};
    const std::array<const juce::Rectangle<double>*, 3> speedRegions{&layout::kRedspeed, &layout::kGreenspeed, &layout::kBluespeed};
    // Network colours, as the OpenFL view and Rack.
    const juce::Colour networkColour{0xffa7a298};
    const juce::Colour arcColour{0xff35332e};
    const juce::Colour nodeColour{0xff292722};
    constexpr float nodeRadius = 0.04f; // Node.HIT_RADIUS, in network units

    juce::Colour snapshotColour(int rgb)
    {
        return juce::Colour(0xff000000u | static_cast<juce::uint32>(rgb));
    }
}

KDiagramAudioProcessorEditor::KDiagramAudioProcessorEditor(KDiagramAudioProcessor& p)
    : AudioProcessorEditor(p), processor(p)
{
    setOpaque(true);
    setLookAndFeel(&lookAndFeel);

    for (std::size_t i = 0; i < speedKnobs.size(); ++i) {
        auto& knob = speedKnobs[i];
        host::configureKnob(knob, *speedMetadata[i]);
        knob.onValueChange = [this, &knob, i] { sendValue(ids::speedUid(static_cast<int>(i)), knob.getValue()); };
        addAndMakeVisible(knob);
    }
    host::configureKnob(noteLength, metadata::kNote_length);
    noteLength.onValueChange = [this] { sendValue(ids::kNoteLength, noteLength.getValue()); };
    addAndMakeVisible(noteLength);

    cursorSelect.onChoose = [this](int index) { sendValue(ids::kCursorSelect, index); };
    addAndMakeVisible(cursorSelect);

    for (std::size_t i = 0; i < metadata::kScaleselect.choiceCount; ++i)
        scaleSelect.addItem(metadata::kScaleselect.choices[i].label, static_cast<int>(i + 1));
    scaleSelect.setTooltip(host::tooltipFor(metadata::kScaleselect.tooltip, metadata::kScaleselect.label));
    scaleSelect.onChange = [this] { sendValue(ids::kScaleSelect, scaleSelect.getSelectedItemIndex()); };
    addAndMakeVisible(scaleSelect);

    // Each choice's value is the first of the cursors' three MIDI channels.
    for (std::size_t i = 0; i < metadata::kChannel.choiceCount; ++i)
        channelSelect.addItem(metadata::kChannel.choices[i].label, static_cast<int>(i + 1));
    channelSelect.setTooltip(host::tooltipFor(metadata::kChannel.tooltip, metadata::kChannel.label));
    channelSelect.onChange = [this] {
        const int index = channelSelect.getSelectedItemIndex();
        if (index >= 0)
            sendValue(ids::kChannel, metadata::kChannel.choices[static_cast<std::size_t>(index)].value);
    };
    addAndMakeVisible(channelSelect);

    // Pause displays the model's flag and asks the model to flip it; it holds no state of its own.
    reset.onClick = [this] { processor.enqueueGuiCommand(worldofcake::bridge::resetCommand()); };
    terminus.onClick = [this] { sendValue(ids::kTerminus, snapshot.terminusEnabled ? 0.0 : 1.0); };
    addAndMakeVisible(terminus);
    pause.onClick = [this] { processor.enqueueGuiCommand(worldofcake::bridge::pauseCommand(!snapshot.paused)); };
    rotateLeft.onClick = [this] { sendValue(ids::kRotateLeft, 1.0); };
    rotateRight.onClick = [this] { sendValue(ids::kRotateRight, 1.0); };
    for (auto* button : {&reset, &pause, &rotateLeft, &rotateRight})
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

KDiagramAudioProcessorEditor::~KDiagramAudioProcessorEditor()
{
    setLookAndFeel(nullptr);
}

worldofcake::jucehost::WocJuceCoordinateMapper KDiagramAudioProcessorEditor::panelMapper() const
{
    return host::WocJuceCoordinateMapper(layout::kPanelWidth, layout::kPanelHeight, getLocalBounds());
}

juce::Point<float> KDiagramAudioProcessorEditor::toView(double x, double y) const
{
    return {playArea.getX() + static_cast<float>((x + 1.0) * 0.5) * playArea.getWidth(),
            playArea.getY() + static_cast<float>((1.0 - y) * 0.5) * playArea.getHeight()};
}

void KDiagramAudioProcessorEditor::sendValue(int controlId, double value)
{
    worldofcake::bridge::ControlCommand command;
    command.kind = worldofcake::bridge::CommandKind::setValue;
    command.controlId = controlId;
    command.value = value;
    processor.enqueueGuiCommand(command);
}

void KDiagramAudioProcessorEditor::timerCallback()
{
    auto next = processor.visualSnapshot();
    if (next.generation == displayedGeneration)
        return;
    displayedGeneration = next.generation;
    snapshot = std::move(next);
    // Follow model changes only, so a pending user edit is never overwritten.
    for (std::size_t i = 0; i < speedKnobs.size(); ++i)
        shownSpeeds[i].update(snapshot.cursors[i].speed, [this, i](double v) { speedKnobs[i].setValue(v, juce::dontSendNotification); });
    shownNoteLength.update(snapshot.noteLength, [this](double v) { noteLength.setValue(v, juce::dontSendNotification); });
    shownScale.update(snapshot.scaleIndex, [this](int v) { scaleSelect.setSelectedItemIndex(v, juce::dontSendNotification); });
    shownChannel.update(snapshot.cursors[0].channel, [this](int base) { channelSelect.setSelectedItemIndex(base - 1, juce::dontSendNotification); });
    shownPaused.update(snapshot.paused, [this](bool v) { pause.setToggleState(v, juce::dontSendNotification); });
    terminus.setToggleState(snapshot.terminusEnabled, juce::dontSendNotification);
    cursorSelect.setSelectedIndex(snapshot.selectedCursor);
    repaint(playArea.getSmallestIntegerContainer());
}

void KDiagramAudioProcessorEditor::resized()
{
    const auto map = panelMapper();
    auto place = [&map](juce::Component& component, const juce::Rectangle<double>& region) {
        component.setBounds(host::panelRegion(map, region).toNearestInt());
    };
    playArea = host::panelRegion(map, layout::kPlayarea);
    for (std::size_t i = 0; i < speedKnobs.size(); ++i)
        place(speedKnobs[i], *speedRegions[i]);
    place(noteLength, layout::kNote_length);
    place(cursorSelect, layout::kSelectcursor);
    place(scaleSelect, layout::kScaleselect);
    place(channelSelect, layout::kChannel);
    place(reset, layout::kReset);
    place(pause, layout::kPause);
    place(terminus, layout::kTerminus);
    place(rotateLeft, layout::kRotate_left);
    place(rotateRight, layout::kRotate_right);
}

void KDiagramAudioProcessorEditor::paint(juce::Graphics& g)
{
    const auto map = panelMapper();
    g.fillAll(host::chrome::background);
    host::paintBoxes(g, map, layout::kBoxes);
    host::paintText(g, host::panelRegion(map, layout::kSpeed_heading), metadata::kSpeed_heading);
    host::paintText(g, host::panelRegion(map, layout::kNote_length_heading), metadata::kNote_length_heading);
    paintNetwork(g);
}

void KDiagramAudioProcessorEditor::paintNetwork(juce::Graphics& g)
{
    g.setColour(juce::Colour(0xfff6f3ea));
    g.fillRoundedRectangle(playArea, host::chrome::corner * 1.5f);
    juce::Graphics::ScopedSaveState clip(g);
    g.reduceClipRegion(playArea.toNearestInt());

    const auto centre = toView(0.0, 0.0);
    const float scale = playArea.getWidth() * 0.5f;
    g.setColour(networkColour);
    const float radius = static_cast<float>(snapshot.radius) * scale;
    g.drawEllipse(centre.x - radius, centre.y - radius, radius * 2.0f, radius * 2.0f, 1.0f);

    g.setColour(arcColour);
    for (const auto& arc : snapshot.arcs) {
        if (arc.source < 0 || arc.destination < 0 || static_cast<std::size_t>(arc.source) >= snapshot.nodes.size() ||
            static_cast<std::size_t>(arc.destination) >= snapshot.nodes.size())
            continue;
        const auto& from = snapshot.nodes[static_cast<std::size_t>(arc.source)];
        const auto& to = snapshot.nodes[static_cast<std::size_t>(arc.destination)];
        g.drawLine(juce::Line<float>(toView(from.x, from.y), toView(to.x, to.y)), 1.0f);
    }
    g.setColour(nodeColour);
    const float nodeSize = nodeRadius * scale;
    for (const auto& node : snapshot.nodes) {
        const auto at = toView(node.x, node.y);
        juce::Path symbol;
        if (node.type == 3) {
            symbol.startNewSubPath(at.x-nodeSize*1.35f, at.y);
            symbol.lineTo(at.x, at.y-nodeSize*0.65f);
            symbol.lineTo(at.x+nodeSize*1.35f, at.y);
            symbol.lineTo(at.x, at.y+nodeSize*0.65f);
            symbol.closeSubPath();
        } else if (node.type == 2)
            symbol.addRectangle(at.x-nodeSize, at.y-nodeSize, nodeSize*2, nodeSize*2);
        else if (node.type == 1)
            symbol.addTriangle(at.x, at.y-nodeSize, at.x+nodeSize, at.y+nodeSize, at.x-nodeSize, at.y+nodeSize);
        else
            symbol.addEllipse(at.x-nodeSize, at.y-nodeSize, nodeSize*2, nodeSize*2);
        g.setColour(juce::Colour(0xfff6f3ea));
        g.fillPath(symbol);
        g.setColour(nodeColour);
        g.strokePath(symbol, juce::PathStrokeType(1.3f));
    }

    for (std::size_t i = 0; i < snapshot.cursors.size(); ++i) {
        const auto& cursor = snapshot.cursors[i];
        const auto at = toView(cursor.x, cursor.y);
        const auto colour = snapshotColour(cursor.colour);
        if (cursor.moving) {
            g.setColour(colour);
            g.drawLine(juce::Line<float>(at, toView(cursor.targetX, cursor.targetY)), 1.0f);
        }
        const bool selected = static_cast<int>(i) == snapshot.selectedCursor;
        const float size = selected ? 5.0f : 4.0f;
        g.setColour(colour);
        g.fillEllipse(at.x - size, at.y - size, size * 2.0f, size * 2.0f);
        if (selected) {
            g.setColour(nodeColour);
            g.drawEllipse(at.x - size - 3.0f, at.y - size - 3.0f, (size + 3.0f) * 2.0f, (size + 3.0f) * 2.0f, 2.0f);
        }
    }
}

void KDiagramAudioProcessorEditor::mouseDown(const juce::MouseEvent& event)
{
    if (!playArea.contains(event.position))
        return;
    worldofcake::bridge::ControlCommand command;
    command.kind = worldofcake::bridge::CommandKind::playAreaClick;
    command.controlId = ids::kPlayArea;
    command.x = (event.position.x - playArea.getX()) / playArea.getWidth() * 2.0 - 1.0;
    command.y = 1.0 - (event.position.y - playArea.getY()) / playArea.getHeight() * 2.0;
    processor.enqueueGuiCommand(command);
}
