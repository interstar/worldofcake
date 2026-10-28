#include "PluginEditor.h"
#include "WocJuceCoordinateMapper.h"
#include "WocJuceEditorSupport.h"
#include "worldofcake/generated/juce/timeslider/LayoutGenerated.h"
#include "worldofcake/generated/timeslider/TimesliderControlMetadataGenerated.h"

#include <cstring>

namespace
{
    namespace layout = worldofcake::juce_layout::timeslider;
    namespace metadata = worldofcake::metadata::timeslider;
    namespace host = worldofcake::jucehost;

    // Each lane's controls (metadata::kLanes) and where they go (layout::kLaneRegions), in lane order.
    static_assert(metadata::kLaneCount == std::tuple_size<std::remove_cv_t<decltype(layout::kLaneRegions)>>::value,
                  "metadata and layout must agree on the lanes");

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
        const auto& lane = metadata::kLanes[i];
        auto& label = labels[i];
        label.setMultiLine(false);
        label.setTooltip(host::tooltipFor(lane.label->tooltip, lane.label->label));
        auto commit = [this, i] { sendText(metadata::kLanes[i].label->controlId, labels[i].getText()); };
        label.onReturnKey = commit;
        label.onFocusLostCallback = commit;
        addAndMakeVisible(label);

        fillChoices(channelSelects[i], *lane.channel);
        channelSelects[i].onChange = [this, i] {
            const auto& select = *metadata::kLanes[i].channel;
            const int index = channelSelects[i].getSelectedItemIndex();
            if (index >= 0)
                sendValue(select.controlId, select.choices[static_cast<std::size_t>(index)].value);
        };
        addAndMakeVisible(channelSelects[i]);

        fillChoices(ccSelects[i], *lane.cc);
        ccSelects[i].onChange = [this, i] {
            const auto& select = *metadata::kLanes[i].cc;
            const int index = ccSelects[i].getSelectedItemIndex();
            if (index >= 0)
                sendValue(select.controlId, select.choices[static_cast<std::size_t>(index)].value);
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
        const auto& regions = layout::kLaneRegions[i];
        labels[i].setBounds(host::textFieldBounds(host::panelRegion(map, regions.label)));
        channelSelects[i].setBounds(host::panelRegion(map, regions.channel).toNearestInt());
        ccSelects[i].setBounds(host::panelRegion(map, regions.cc).toNearestInt());
    }
    reset.setBounds(host::panelRegion(map, layout::kReset).toNearestInt());
    pause.setBounds(host::panelRegion(map, layout::kPause).toNearestInt());
}

void TimeSliderAudioProcessorEditor::paint(juce::Graphics& g)
{
    const auto map = panelMapper();
    g.fillAll(host::chrome::background);
    for (std::size_t i = 0; i < kLanes && i < snap.sliders.size(); ++i) {
        // The lane's place comes from the generated layout; its value (0 bottom .. 1 top) from the model.
        const auto& s = snap.sliders[i];
        const auto lane = host::panelRegion(map, layout::kLaneRegions[i].track);
        const auto colour = host::rgb(metadata::kLanes[i].track->colour);
        g.setColour(laneColour);
        g.fillRoundedRectangle(lane, host::chrome::corner * 1.5f);
        const float valueY = lane.getY() + static_cast<float>(1.0 - s.value) * lane.getHeight();
        g.setColour(colour.withAlpha(fillAlpha));
        g.fillRect(lane.withTop(valueY));
        g.setColour(colour);
        g.drawLine(lane.getX(), valueY, lane.getRight(), valueY, 2.0f);
        if (s.moving) {
            const float targetY = lane.getY() + static_cast<float>(1.0 - s.target) * lane.getHeight();
            g.setColour(juce::Colours::white.withAlpha(0.7f));
            g.drawLine(lane.getX(), targetY, lane.getRight(), targetY, 1.0f);
        }
    }
}

void TimeSliderAudioProcessorEditor::mouseDown(const juce::MouseEvent& e)
{
    const auto map = panelMapper();
    for (std::size_t i = 0; i < kLanes; ++i) {
        const auto lane = host::panelRegion(map, layout::kLaneRegions[i].track);
        if (!lane.contains(e.position))
            continue;
        // The lane's own space (as OpenFL's lane component): x is the travel-time fraction,
        // y the target value, 0 at the bottom to 1 at the top.
        worldofcake::bridge::ControlCommand c;
        c.kind = worldofcake::bridge::CommandKind::playAreaClick;
        c.controlId = metadata::kLanes[i].track->controlId;
        c.x = (e.position.x - lane.getX()) / lane.getWidth();
        c.y = 1.0 - (e.position.y - lane.getY()) / lane.getHeight();
        processor.enqueue(c);
        return;
    }
}

void TimeSliderAudioProcessorEditor::timerCallback()
{
    snap = processor.snapshot();
    // Follow model changes only, so a pending user edit is never overwritten.
    for (std::size_t i = 0; i < kLanes && i < snap.sliders.size(); ++i) {
        const auto& s = snap.sliders[i];
        shownChannels[i].update(s.channel, [this, i](int channel) {
            channelSelects[i].setSelectedItemIndex(choiceIndex(*metadata::kLanes[i].channel, channel), juce::dontSendNotification);
        });
        shownCcNumbers[i].update(s.ccNumber, [this, i](int cc) {
            ccSelects[i].setSelectedItemIndex(choiceIndex(*metadata::kLanes[i].cc, cc), juce::dontSendNotification);
        });
        shownLabels[i].update(s.label, [this, i](const std::string& text) {
            labels[i].setText(juce::String::fromUTF8(text.c_str()), juce::dontSendNotification);
        });
    }
    shownPaused.update(snap.paused, [this](bool v) { pause.setToggleState(v, juce::dontSendNotification); });
    repaint();
}
