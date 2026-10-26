#include "PluginEditor.h"
#include "WorldOfCakeControlIds.h"
#include "WocJuceCoordinateMapper.h"
#include "WocJuceEditorSupport.h"
#include "worldofcake/generated/juce/timeslider/LayoutGenerated.h"
#include "worldofcake/generated/timeslider/TimeSliderControlIdsGenerated.h"
#include "worldofcake/generated/timeslider/TimeSliderControlMetadataGenerated.h"

namespace
{
    namespace layout = worldofcake::juce_layout::timeslider;
    namespace metadata = worldofcake::metadata::timeslider;
    namespace host = worldofcake::jucehost;

    constexpr std::size_t kLanes = 4;
    const std::array<const metadata::Track*, kLanes> trackMetadata{&metadata::kCc1track, &metadata::kCc2track,
                                                                   &metadata::kCc3track, &metadata::kCc4track};
    const std::array<const metadata::Text*, kLanes> headingMetadata{&metadata::kCc1label, &metadata::kCc2label,
                                                                    &metadata::kCc3label, &metadata::kCc4label};
    const std::array<const juce::Rectangle<double>*, kLanes> headingRegions{&layout::kCc1label, &layout::kCc2label,
                                                                            &layout::kCc3label, &layout::kCc4label};
    const std::array<const metadata::SemanticSelect*, kLanes> channelMetadata{
        &metadata::kCc1channel, &metadata::kCc2channel, &metadata::kCc3channel, &metadata::kCc4channel};
    const std::array<const juce::Rectangle<double>*, kLanes> channelRegions{
        &layout::kCc1channel, &layout::kCc2channel, &layout::kCc3channel, &layout::kCc4channel};
    // Matches the OpenFL TimeSliderView.
    const juce::Colour laneColour{0xff13161c};
    constexpr float fillAlpha = 0.35f;
}

TimeSliderAudioProcessorEditor::TimeSliderAudioProcessorEditor(TimeSliderAudioProcessor& p)
    : AudioProcessorEditor(p), processor(p)
{
    setOpaque(true);
    setLookAndFeel(&lookAndFeel);

    for (std::size_t i = 0; i < kLanes; ++i) {
        auto& select = channelSelects[i];
        const auto& m = *channelMetadata[i];
        for (std::size_t j = 0; j < m.choiceCount; ++j)
            select.addItem(m.choices[j].label, static_cast<int>(j + 1));
        select.setTooltip(host::tooltipFor(m.tooltip, m.label));
        select.setSelectedItemIndex(metadata::kControlOutputs[i].channel - 1, juce::dontSendNotification);
        // The choice index is the channel's offset from 1, as the model expects.
        select.onChange = [this, i] {
            sendValue(channelMetadata[i]->controlId, static_cast<double>(channelSelects[i].getSelectedItemIndex()));
        };
        addAndMakeVisible(select);
    }

    // Pause displays the model's flag and asks the model to flip it; it holds no state of its own.
    reset.onClick = [this] { processor.enqueue(worldofcake::bridge::resetCommand()); };
    pause.onClick = [this] { processor.enqueue(worldofcake::bridge::pauseCommand(!snap.paused)); };
    addAndMakeVisible(reset);
    addAndMakeVisible(pause);

    // The panel scales with the window; keep the generated layout's proportions.
    setResizable(true, true);
    setResizeLimits(static_cast<int>(layout::kPanelWidth * 0.5), static_cast<int>(layout::kPanelHeight * 0.5),
                    static_cast<int>(layout::kPanelWidth * 3.0), static_cast<int>(layout::kPanelHeight * 3.0));
    if (auto* constrainer = getConstrainer())
        constrainer->setFixedAspectRatio(layout::kPanelWidth / layout::kPanelHeight);
    setSize(static_cast<int>(layout::kPanelWidth), static_cast<int>(layout::kPanelHeight));
    startTimerHz(30);
}

TimeSliderAudioProcessorEditor::~TimeSliderAudioProcessorEditor()
{
    setLookAndFeel(nullptr);
}

worldofcake::jucehost::WocJuceCoordinateMapper TimeSliderAudioProcessorEditor::panelMapper() const
{
    return host::WocJuceCoordinateMapper(layout::kPanelWidth, layout::kPanelHeight, getLocalBounds());
}

void TimeSliderAudioProcessorEditor::sendValue(int controlId, double value)
{
    worldofcake::bridge::ControlCommand command;
    command.kind = worldofcake::bridge::CommandKind::setValue;
    command.controlId = controlId;
    command.value = value;
    processor.enqueue(command);
}

void TimeSliderAudioProcessorEditor::resized()
{
    const auto map = panelMapper();
    for (std::size_t i = 0; i < kLanes; ++i)
        channelSelects[i].setBounds(host::panelRegion(map, *channelRegions[i]).toNearestInt());
    reset.setBounds(host::panelRegion(map, layout::kReset).toNearestInt());
    pause.setBounds(host::panelRegion(map, layout::kPause).toNearestInt());
}

void TimeSliderAudioProcessorEditor::paint(juce::Graphics& g)
{
    const auto map = panelMapper();
    g.fillAll(host::chrome::background);
    for (std::size_t i = 0; i < kLanes; ++i) {
        host::paintText(g, host::panelRegion(map, *headingRegions[i]), *headingMetadata[i]);
        // Track geometry is in panel coordinates (the model's area is the panel).
        const auto& s = snap.sliders[i];
        const auto lane = map.toView(s.x, s.y, s.width, s.height);
        const auto colour = host::rgb(trackMetadata[i]->colour);
        g.setColour(laneColour);
        g.fillRoundedRectangle(lane, host::chrome::corner * 1.5f);
        const float current = map.toView(s.x, s.y + s.current).y;
        g.setColour(colour.withAlpha(fillAlpha));
        g.fillRect(lane.withTop(current));
        g.setColour(colour);
        g.drawLine(lane.getX(), current, lane.getRight(), current, 2.0f);
        if (s.destination != s.current) {
            const float target = map.toView(s.x, s.y + s.destination).y;
            g.setColour(juce::Colours::white.withAlpha(0.7f));
            g.drawLine(lane.getX(), target, lane.getRight(), target, 1.0f);
        }
    }
}

void TimeSliderAudioProcessorEditor::mouseDown(const juce::MouseEvent& e)
{
    const auto map = panelMapper();
    const auto modelPoint = map.toModel(e.position);
    for (std::size_t i = 0; i < kLanes; ++i) {
        const auto& s = snap.sliders[i];
        if (!map.toView(s.x, s.y, s.width, s.height).contains(e.position))
            continue;
        worldofcake::bridge::ControlCommand c;
        c.kind = worldofcake::bridge::CommandKind::playAreaClick;
        c.controlId = worldofcake::control::timeslider::trackUid(static_cast<int>(i));
        // The shared Haxe component contract receives coordinates local to the
        // selected track, not panel coordinates. OpenFL/Rack perform this
        // panel-to-local conversion in ComponentCommon before dispatching
        // mouseDown; mirror that conversion in the JUCE adapter.
        c.x = modelPoint.x - s.x;
        c.y = modelPoint.y - s.y;
        processor.enqueue(c);
        return;
    }
}

void TimeSliderAudioProcessorEditor::timerCallback()
{
    snap = processor.snapshot();
    // Follow model changes only, so a pending user edit is never overwritten.
    for (std::size_t i = 0; i < kLanes; ++i)
        shownChannels[i].update(snap.sliders[i].channel, [this, i](int channel) {
            channelSelects[i].setSelectedItemIndex(channel - 1, juce::dontSendNotification);
        });
    shownPaused.update(snap.paused, [this](bool v) { pause.setToggleState(v, juce::dontSendNotification); });
    repaint();
}
