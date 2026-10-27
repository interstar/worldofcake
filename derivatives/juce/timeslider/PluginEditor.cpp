#include "PluginEditor.h"
#include "WorldOfCakeControlIds.h"
#include "WocJuceCoordinateMapper.h"
#include "WocJuceEditorSupport.h"
#include "worldofcake/generated/juce/timeslider/LayoutGenerated.h"
#include "worldofcake/generated/timeslider/TimeSliderControlIdsGenerated.h"
#include "worldofcake/generated/timeslider/TimesliderControlMetadataGenerated.h"

#include <cstring>

namespace
{
    namespace layout = worldofcake::juce_layout::timeslider;
    namespace metadata = worldofcake::metadata::timeslider;
    namespace host = worldofcake::jucehost;

    constexpr std::size_t kLanes = 4;
    const std::array<const metadata::Track*, kLanes> trackMetadata{&metadata::kLane1track, &metadata::kLane2track,
                                                                   &metadata::kLane3track, &metadata::kLane4track};
    const std::array<const metadata::TextInput*, kLanes> labelMetadata{&metadata::kLane1label, &metadata::kLane2label,
                                                                       &metadata::kLane3label, &metadata::kLane4label};
    const std::array<const juce::Rectangle<double>*, kLanes> labelRegions{&layout::kLane1label, &layout::kLane2label,
                                                                          &layout::kLane3label, &layout::kLane4label};
    const std::array<const metadata::SemanticSelect*, kLanes> channelMetadata{
        &metadata::kLane1channel, &metadata::kLane2channel, &metadata::kLane3channel, &metadata::kLane4channel};
    const std::array<const juce::Rectangle<double>*, kLanes> channelRegions{
        &layout::kLane1channel, &layout::kLane2channel, &layout::kLane3channel, &layout::kLane4channel};
    const std::array<const metadata::SemanticSelect*, kLanes> ccMetadata{
        &metadata::kLane1cc, &metadata::kLane2cc, &metadata::kLane3cc, &metadata::kLane4cc};
    const std::array<const juce::Rectangle<double>*, kLanes> ccRegions{
        &layout::kLane1cc, &layout::kLane2cc, &layout::kLane3cc, &layout::kLane4cc};
    // Matches the OpenFL TimeSliderView.
    const juce::Colour laneColour{0xff13161c};
    constexpr float fillAlpha = 0.35f;

    /** Fills a dropdown from a generated select; each choice's value is the number it stands for. */
    void fillChoices(juce::ComboBox& box, const metadata::SemanticSelect& select)
    {
        for (std::size_t j = 0; j < select.choiceCount; ++j)
            box.addItem(select.choices[j].label, static_cast<int>(j + 1));
        box.setTooltip(host::tooltipFor(select.tooltip, select.label));
    }

    /** Index of the choice whose value is `value` (choices run in steps of one from the first). */
    int choiceIndex(const metadata::SemanticSelect& select, int value)
    {
        return value - static_cast<int>(select.choices[0].value);
    }
}

TimeSliderAudioProcessorEditor::TimeSliderAudioProcessorEditor(TimeSliderAudioProcessor& p)
    : AudioProcessorEditor(p), processor(p)
{
    setOpaque(true);
    setLookAndFeel(&lookAndFeel);

    for (std::size_t i = 0; i < kLanes; ++i) {
        auto& label = labels[i];
        label.setMultiLine(false);
        label.setTooltip(host::tooltipFor(labelMetadata[i]->tooltip, labelMetadata[i]->label));
        auto commit = [this, i] { sendText(labelMetadata[i]->controlId, labels[i].getText()); };
        label.onReturnKey = commit;
        label.onFocusLostCallback = commit;
        addAndMakeVisible(label);

        fillChoices(channelSelects[i], *channelMetadata[i]);
        channelSelects[i].onChange = [this, i] {
            const int index = channelSelects[i].getSelectedItemIndex();
            if (index >= 0)
                sendValue(channelMetadata[i]->controlId, channelMetadata[i]->choices[static_cast<std::size_t>(index)].value);
        };
        addAndMakeVisible(channelSelects[i]);

        fillChoices(ccSelects[i], *ccMetadata[i]);
        ccSelects[i].onChange = [this, i] {
            const int index = ccSelects[i].getSelectedItemIndex();
            if (index >= 0)
                sendValue(ccMetadata[i]->controlId, ccMetadata[i]->choices[static_cast<std::size_t>(index)].value);
        };
        addAndMakeVisible(ccSelects[i]);
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
    stopTimer();
    for (auto& label : labels) {
        label.onReturnKey = {};
        label.onFocusLostCallback = {};
    }
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

void TimeSliderAudioProcessorEditor::sendText(int controlId, const juce::String& text)
{
    worldofcake::bridge::ControlCommand command;
    command.kind = worldofcake::bridge::CommandKind::textSubmitted;
    command.controlId = controlId;
    std::strncpy(command.text, text.toRawUTF8(), sizeof(command.text) - 1);
    processor.enqueue(command);
}

void TimeSliderAudioProcessorEditor::resized()
{
    const auto map = panelMapper();
    for (std::size_t i = 0; i < kLanes; ++i) {
        labels[i].setBounds(host::textFieldBounds(host::panelRegion(map, *labelRegions[i])));
        channelSelects[i].setBounds(host::panelRegion(map, *channelRegions[i]).toNearestInt());
        ccSelects[i].setBounds(host::panelRegion(map, *ccRegions[i]).toNearestInt());
    }
    reset.setBounds(host::panelRegion(map, layout::kReset).toNearestInt());
    pause.setBounds(host::panelRegion(map, layout::kPause).toNearestInt());
}

void TimeSliderAudioProcessorEditor::paint(juce::Graphics& g)
{
    const auto map = panelMapper();
    g.fillAll(host::chrome::background);
    for (std::size_t i = 0; i < kLanes; ++i) {
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
    for (std::size_t i = 0; i < kLanes; ++i) {
        const auto& s = snap.sliders[i];
        shownChannels[i].update(s.channel, [this, i](int channel) {
            channelSelects[i].setSelectedItemIndex(choiceIndex(*channelMetadata[i], channel), juce::dontSendNotification);
        });
        shownCcNumbers[i].update(s.ccNumber, [this, i](int cc) {
            ccSelects[i].setSelectedItemIndex(choiceIndex(*ccMetadata[i], cc), juce::dontSendNotification);
        });
        shownLabels[i].update(s.label, [this, i](const std::string& text) {
            labels[i].setText(juce::String::fromUTF8(text.c_str()), juce::dontSendNotification);
        });
    }
    shownPaused.update(snap.paused, [this](bool v) { pause.setToggleState(v, juce::dontSendNotification); });
    repaint();
}
