#include "PluginEditor.h"
#include "WorldOfCakeControlIds.h"
#include "WocJuceCoordinateMapper.h"
#include "WocJuceEditorSupport.h"
#include "worldofcake/generated/juce/timeslider/LayoutGenerated.h"
#include "worldofcake/generated/timeslider/TimeSliderControlIdsGenerated.h"
TimeSliderAudioProcessorEditor::TimeSliderAudioProcessorEditor(TimeSliderAudioProcessor&p):AudioProcessorEditor(p),processor(p){setSize(800,600);startTimerHz(30);}
void TimeSliderAudioProcessorEditor::paint(juce::Graphics&g){g.fillAll(juce::Colour(0xff101218));worldofcake::jucehost::drawPanelTitle(g,"WorldOfCake - TimeSliders",{20,12,500,30});worldofcake::jucehost::WocJuceCoordinateMapper map(worldofcake::juce_layout::timeslider::kPanelWidth,worldofcake::juce_layout::timeslider::kPanelHeight,worldofcake::jucehost::panelViewBounds(*this,40));const juce::Rectangle<double> regions[]={worldofcake::juce_layout::timeslider::kCc1track,worldofcake::juce_layout::timeslider::kCc2track,worldofcake::juce_layout::timeslider::kCc3track,worldofcake::juce_layout::timeslider::kCc4track};for(int i=0;i<4;i++){auto&s=snap.sliders[i];auto r=worldofcake::jucehost::panelRegion(map,regions[i]);g.setColour(juce::Colours::darkgrey);g.fillRect(r);g.setColour(juce::Colours::cyan);g.fillRect(r.withY(map.toView(regions[i].getX(),regions[i].getY()+s.current).y).withHeight(8));worldofcake::jucehost::drawPanelLabel(g,"CC "+juce::String(20+i),r);}if(lastClick.x>=0){g.setColour(juce::Colours::yellow);g.fillEllipse(lastClick.x-6,lastClick.y-6,12,12);}}
void TimeSliderAudioProcessorEditor::mouseDown(const juce::MouseEvent&e){
    lastClick=e.position;
    repaint();
    worldofcake::jucehost::WocJuceCoordinateMapper map(worldofcake::juce_layout::timeslider::kPanelWidth,worldofcake::juce_layout::timeslider::kPanelHeight,worldofcake::jucehost::panelViewBounds(*this,40));
    const auto modelPoint = map.toModel(e.position);
    int i = 0; for (; i < 4; ++i) { auto&s=snap.sliders[static_cast<std::size_t>(i)]; if (map.toView(s.x,s.y,s.width,s.height).contains(e.position)) break; }
    if (i >= 4) return;
    const auto&s = snap.sliders[static_cast<std::size_t>(i)];
    worldofcake::bridge::ControlCommand c;
    c.kind=worldofcake::bridge::CommandKind::playAreaClick;
    c.controlId=worldofcake::control::timeslider::trackUid(i);
    // The shared Haxe component contract receives coordinates local to the
    // selected track, not panel coordinates. OpenFL/Rack perform this
    // panel-to-local conversion in ComponentCommon before dispatching
    // mouseDown; mirror that conversion in the JUCE adapter.
    c.x=modelPoint.x - s.x;
    c.y=modelPoint.y - s.y;
    processor.enqueue(c);
}
void TimeSliderAudioProcessorEditor::timerCallback(){snap=processor.snapshot();repaint();}
