#include "PluginProcessor.h"
#include "PluginEditor.h"
#include "HaxeRuntimeBoot.h"
#include <worldofcake/generated/goldenpond/GoldenpondControlIdsGenerated.h>
GoldenpondAudioProcessor::GoldenpondAudioProcessor():AudioProcessor(BusesProperties()){worldofcake::bridge::bootHaxeRuntime();runner=std::make_unique<worldofcake::bridge::GoldenpondControlRunner>();runner->start(.001);}
GoldenpondAudioProcessor::~GoldenpondAudioProcessor(){if(runner)runner->stop();}
void GoldenpondAudioProcessor::setOutputMuted(bool value) noexcept {
    sendValue(worldofcake::control::goldenpond::kMute, value ? 1.0 : 0.0);
}
void GoldenpondAudioProcessor::prepareToPlay(double r,int){rate=r>0?r:44100;position=0;++epoch;hostPlaying=false;hostPositionKnown=false;lastHostTime=0.0;}
template<class T>void GoldenpondAudioProcessor::process(juce::AudioBuffer<T>&b,juce::MidiBuffer&m){
    b.clear();
    if(!runner)return;
    const auto input = m;
    m.clear();
    // MIDI channel 1 is the keyboard/correction input (JUCE uses 1..16).
    // Corrected keyboard notes are emitted on channel 5, leaving channels 1..4
    // for Goldenpond's four generated parts.
    for(const auto metadata : input){
        const auto message = metadata.getMessage();
        if(message.getChannel()!=1 || !(message.isNoteOn() || message.isNoteOff())) continue;
        const auto corrected = runner->correctedNote(message.getNoteNumber(), 0);
        auto output = message.isNoteOn()
            ? juce::MidiMessage::noteOn(5, corrected, message.getVelocity())
            : juce::MidiMessage::noteOff(5, corrected, message.getVelocity());
        m.addEvent(output, metadata.samplePosition);
    }
    double hostTime = double(position + b.getNumSamples()) / rate;
    bool playing = true;
    if (auto* playHead = getPlayHead()) {
        if (auto info = playHead->getPosition()) {
            playing = info->getIsPlaying();
            if (auto seconds = info->getTimeInSeconds()) hostTime = std::max(0.0, *seconds);
            if (auto bpm = info->getBpm()) runner->setHostTransportBpm(*bpm);
        }
    }
    const bool discontinuity = hostPositionKnown && (hostTime + 0.25 < lastHostTime || std::abs(hostTime - lastHostTime) > 2.0);
    if (!hostPositionKnown || playing != hostPlaying || discontinuity) {
        ++epoch;
        hostEpochSample = static_cast<std::int64_t>(std::llround(hostTime * rate));
        position = hostEpochSample;
    }
    hostPositionKnown = true; hostPlaying = playing; lastHostTime = hostTime;
    runner->setHostTransportTime(hostTime,epoch);
    runner->setHostTransportRunning(playing);
    worldofcake::bridge::PreparedEvent e; int n=0;
    while(n++<512 && runner->popPreparedEvent(e)) {
        const auto eventSample = hostEpochSample + (std::int64_t)std::llround(e.timestamp * rate);
        const int offset = (int)(eventSample - position);
        if(offset < 0 || offset >= b.getNumSamples()) continue;
        const int channel = juce::jlimit(1, 16, e.channel + 1);
        if(e.type == 0) m.addEvent(juce::MidiMessage::noteOn(channel, e.data2, (juce::uint8)e.data3), offset);
        else if(e.type == 2) m.addEvent(juce::MidiMessage::noteOff(channel, e.data2, (juce::uint8)e.data3), offset);
    }
    position += b.getNumSamples();}
void GoldenpondAudioProcessor::processBlock(juce::AudioBuffer<float>&b,juce::MidiBuffer&m){process(b,m);}void GoldenpondAudioProcessor::processBlock(juce::AudioBuffer<double>&b,juce::MidiBuffer&m){process(b,m);}juce::AudioProcessorEditor*GoldenpondAudioProcessor::createEditor(){return new GoldenpondAudioProcessorEditor(*this);}const juce::String GoldenpondAudioProcessor::getName()const{return JucePlugin_Name;}void GoldenpondAudioProcessor::getStateInformation(juce::MemoryBlock&d){if(runner){auto s=runner->exportStateJson();d.replaceAll(s.data(),s.size());}}void GoldenpondAudioProcessor::setStateInformation(const void*p,int n){if(runner&&p&&n>0){const std::string state((const char*)p,(size_t)n);outputMuted.store(state.find("\"muted\":true")!=std::string::npos,std::memory_order_relaxed);runner->importStateJson(state);runner->requestVisualSnapshot();}}juce::AudioProcessor*JUCE_CALLTYPE createPluginFilter(){return new GoldenpondAudioProcessor();}
void GoldenpondAudioProcessor::sendValue(int id,double value)noexcept{if(!runner)return;worldofcake::bridge::ControlCommand c;c.kind=worldofcake::bridge::CommandKind::setValue;c.controlId=id;c.value=value;runner->enqueueGuiCommand(c);}
void GoldenpondAudioProcessor::sendText(int id,const juce::String& value)noexcept{if(!runner)return;worldofcake::bridge::ControlCommand c;c.kind=worldofcake::bridge::CommandKind::textSubmitted;c.controlId=id;value.copyToUTF8(c.text,sizeof(c.text));runner->enqueueGuiCommand(c);}
