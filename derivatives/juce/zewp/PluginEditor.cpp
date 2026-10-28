#include "PluginEditor.h"

#include "WorldOfCakeControlIds.h"
#include "WocJuceCoordinateMapper.h"
#include "WocJuceEditorSupport.h"
#include "worldofcake/generated/juce/zewp/LayoutGenerated.h"
#include "worldofcake/generated/zewp/ZewpControlMetadataGenerated.h"

#include <cmath>

namespace
{
    namespace layout = worldofcake::juce_layout::zewp;
    namespace metadata = worldofcake::metadata::zewp;
    namespace ids = worldofcake::control::zewp;
    namespace host = worldofcake::jucehost;

    constexpr double kWorldWidth = metadata::model::kWorldWidth;
    constexpr double kWorldHeight = metadata::model::kWorldHeight;
    // As the OpenFL view: white blocks, 4-unit zewp lines, on the dark play area.
    const juce::Colour blockColour{0xfff0f0f0};
    constexpr float zewpLineWidth = 4.0f;
    // The title is the OpenFL panel's (apps/zewp/openfl.edn).
    const char* const kTitle = "GLR : Zewp!";
}

ZewpAudioProcessorEditor::ZewpAudioProcessorEditor(ZewpAudioProcessor& p)
    : AudioProcessorEditor(p), processor(p)
{
    setOpaque(true);
    setLookAndFeel(&lookAndFeel);

    host::configureKnob(population, metadata::kPopulation, 1.0);
    population.onValueChange = [this] { sendValue(ids::kPopulation, population.getValue()); };
    addAndMakeVisible(population);
    host::configureKnob(speed, metadata::kSpeed);
    speed.onValueChange = [this] { sendValue(ids::kSpeed, speed.getValue()); };
    addAndMakeVisible(speed);

    // Pause displays the model's flag and asks the model to flip it; it holds no state of its own.
    reset.onClick = [this] { processor.enqueueGuiCommand(worldofcake::bridge::resetCommand()); };
    pause.onClick = [this] { processor.enqueueGuiCommand(worldofcake::bridge::pauseCommand(!snapshot.paused)); };
    addAndMakeVisible(reset);
    addAndMakeVisible(pause);

    // The panel scales with the window; keep the generated layout's proportions.
    setResizable(true, true);
    setResizeLimits(static_cast<int>(layout::kPanelWidth * 0.5), static_cast<int>(layout::kPanelHeight * 0.5),
                    static_cast<int>(layout::kPanelWidth * 3.0), static_cast<int>(layout::kPanelHeight * 3.0));
    if (auto* constrainer = getConstrainer())
        constrainer->setFixedAspectRatio(layout::kPanelWidth / layout::kPanelHeight);
    setSize(static_cast<int>(layout::kPanelWidth), static_cast<int>(layout::kPanelHeight));

    startTimerHz(60);
}

ZewpAudioProcessorEditor::~ZewpAudioProcessorEditor()
{
    stopTimer();
    setLookAndFeel(nullptr);
}

worldofcake::jucehost::WocJuceCoordinateMapper ZewpAudioProcessorEditor::panelMapper() const
{
    return host::WocJuceCoordinateMapper(layout::kPanelWidth, layout::kPanelHeight, getLocalBounds());
}

juce::Point<float> ZewpAudioProcessorEditor::toView(double x, double y) const
{
    return {world.getX() + static_cast<float>(x / kWorldWidth) * world.getWidth(),
            world.getY() + static_cast<float>(y / kWorldHeight) * world.getHeight()};
}

void ZewpAudioProcessorEditor::sendValue(int controlId, double value)
{
    worldofcake::bridge::ControlCommand command;
    command.kind = worldofcake::bridge::CommandKind::setValue;
    command.controlId = controlId;
    command.value = value;
    processor.enqueueGuiCommand(command);
}

void ZewpAudioProcessorEditor::sendPoint(worldofcake::bridge::CommandKind kind, juce::Point<float> at)
{
    // The model's own space: the world, whatever size it is drawn.
    worldofcake::bridge::ControlCommand command;
    command.kind = kind;
    command.controlId = ids::kPlayArea;
    command.x = juce::jlimit(0.0, kWorldWidth, (at.x - world.getX()) / world.getWidth() * kWorldWidth);
    command.y = juce::jlimit(0.0, kWorldHeight, (at.y - world.getY()) / world.getHeight() * kWorldHeight);
    processor.enqueueGuiCommand(command);
}

void ZewpAudioProcessorEditor::timerCallback()
{
    auto next = processor.visualSnapshot();
    if (next.generation == displayedGeneration)
        return;
    displayedGeneration = next.generation;
    snapshot = std::move(next);
    // Follow model changes only, so a knob being turned is never overwritten.
    shownPopulation.update(snapshot.population, [this](int v) { population.setValue(v, juce::dontSendNotification); });
    shownSpeed.update(snapshot.speedMultiplier, [this](double v) { speed.setValue(v, juce::dontSendNotification); });
    shownPaused.update(snapshot.paused, [this](bool v) { pause.setToggleState(v, juce::dontSendNotification); });
    repaint(playCell.getSmallestIntegerContainer());
}

void ZewpAudioProcessorEditor::resized()
{
    const auto map = panelMapper();
    playCell = host::panelRegion(map, layout::kPlayarea);
    // Show the whole world undistorted, centred in its cell.
    const float scale = juce::jmin(playCell.getWidth() / static_cast<float>(kWorldWidth),
                                   playCell.getHeight() / static_cast<float>(kWorldHeight));
    world = juce::Rectangle<float>(static_cast<float>(kWorldWidth) * scale, static_cast<float>(kWorldHeight) * scale)
                .withCentre(playCell.getCentre());
    population.setBounds(host::knobBounds(host::panelRegion(map, layout::kPopulation), metadata::kPopulation));
    speed.setBounds(host::knobBounds(host::panelRegion(map, layout::kSpeed), metadata::kSpeed));
    reset.setBounds(host::panelRegion(map, layout::kReset).toNearestInt());
    pause.setBounds(host::panelRegion(map, layout::kPause).toNearestInt());
}

void ZewpAudioProcessorEditor::paint(juce::Graphics& g)
{
    const auto map = panelMapper();
    g.fillAll(host::chrome::background);
    g.setColour(host::chrome::text);
    g.setFont(juce::Font(host::panelRegion(map, layout::kTitle).getHeight() * 0.8f, juce::Font::bold));
    g.drawText(kTitle, host::panelRegion(map, layout::kTitle).toNearestInt(), juce::Justification::centredLeft, false);
    host::paintKnobLabel(g, host::panelRegion(map, layout::kPopulation), metadata::kPopulation);
    host::paintKnobLabel(g, host::panelRegion(map, layout::kSpeed), metadata::kSpeed);

    g.setColour(host::chrome::playArea);
    g.fillRoundedRectangle(world, host::chrome::corner * 1.5f);
    juce::Graphics::ScopedSaveState clip(g);
    g.reduceClipRegion(world.toNearestInt());
    const float unit = world.getWidth() / static_cast<float>(kWorldWidth);

    g.setColour(blockColour);
    for (const auto& b : snapshot.blocks) {
        const auto centre = toView(b.x, b.y);
        g.fillRect(juce::Rectangle<float>(static_cast<float>(b.width) * unit, static_cast<float>(b.height) * unit)
                       .withCentre(centre));
    }
    for (const auto& z : snapshot.agents) {
        const auto dx = std::cos(z.angle) * z.length, dy = std::sin(z.angle) * z.length;
        g.setColour(host::rgb(static_cast<std::uint32_t>(z.colour)));
        g.drawLine(juce::Line<float>(toView(z.x - dx, z.y - dy), toView(z.x + dx, z.y + dy)), zewpLineWidth * unit);
    }
}

void ZewpAudioProcessorEditor::mouseDown(const juce::MouseEvent& event)
{
    dragging = world.contains(event.position);
    if (dragging)
        sendPoint(worldofcake::bridge::CommandKind::playAreaClick, event.position);
}

void ZewpAudioProcessorEditor::mouseDrag(const juce::MouseEvent& event)
{
    if (dragging)
        sendPoint(worldofcake::bridge::CommandKind::playAreaDrag, event.position);
}

void ZewpAudioProcessorEditor::mouseUp(const juce::MouseEvent& event)
{
    if (dragging)
        sendPoint(worldofcake::bridge::CommandKind::playAreaRelease, event.position);
    dragging = false;
}
