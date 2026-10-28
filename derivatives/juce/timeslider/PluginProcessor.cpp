#include "PluginProcessor.h"
#include "PluginEditor.h"
#include "HaxeRuntimeBoot.h"
#include "NoteOutputScheduler.h"
#include "worldofcake/generated/timeslider/TimesliderControlMetadataGenerated.h"
TimeSliderAudioProcessor::TimeSliderAudioProcessor():AudioProcessor(BusesProperties()) { worldofcake::bridge::bootHaxeRuntime(); runner=std::make_unique<worldofcake::bridge::TimeSliderControlRunner>(); runner->start(.001);
 outputParameters=std::make_unique<worldofcake::jucehost::ControlOutputParameters>(*this, worldofcake::metadata::timeslider::kControlOutputs, [this](int i){ return runner->controlOutputValue(i); }); }
TimeSliderAudioProcessor::~TimeSliderAudioProcessor(){outputParameters.reset(); if(runner)runner->stop();}
void TimeSliderAudioProcessor::prepareToPlay(double r,int){rate=r>0?r:44100;position=0;}
void TimeSliderAudioProcessor::releaseResources(){}
template<class T> void TimeSliderAudioProcessor::process(juce::AudioBuffer<T>& b,juce::MidiBuffer& m){b.clear(); if(!runner)return; worldofcake::bridge::PreparedEvent e; while(runner->popPreparedEvent(e)){int s=(int)std::llround(e.timestamp*rate)-int(position); if(s<0)s=0; if(s>=b.getNumSamples())s=b.getNumSamples()-1; if(e.type==worldofcake::bridge::NoteOutputScheduler::kControlChange)m.addEvent(juce::MidiMessage::controllerEvent(e.channel,e.data2,e.data3),s);} position+=b.getNumSamples();}
void TimeSliderAudioProcessor::processBlock(juce::AudioBuffer<float>&b,juce::MidiBuffer&m){process(b,m);} void TimeSliderAudioProcessor::processBlock(juce::AudioBuffer<double>&b,juce::MidiBuffer&m){process(b,m);}
juce::AudioProcessorEditor* TimeSliderAudioProcessor::createEditor(){return new TimeSliderAudioProcessorEditor(*this);} const juce::String TimeSliderAudioProcessor::getName()const{return JucePlugin_Name;}
bool TimeSliderAudioProcessor::enqueue(const worldofcake::bridge::ControlCommand& c)noexcept{return runner&&runner->enqueueGuiCommand(c);} worldofcake::bridge::TimeSliderControlSnapshot TimeSliderAudioProcessor::snapshot()const{return runner?runner->latestVisualSnapshot():worldofcake::bridge::TimeSliderControlSnapshot{};}
void TimeSliderAudioProcessor::getStateInformation(juce::MemoryBlock& d){if(runner){auto s=runner->exportStateJson();d.replaceAll(s.data(),s.size());}} void TimeSliderAudioProcessor::setStateInformation(const void*p,int n){if(runner&&p&&n>0)runner->importStateJson(std::string((const char*)p,(size_t)n));}
juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter(){return new TimeSliderAudioProcessor();}
