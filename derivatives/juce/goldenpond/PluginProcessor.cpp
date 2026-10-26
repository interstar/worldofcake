#include "PluginProcessor.h"
#include "PluginEditor.h"
#include "HaxeRuntimeBoot.h"
GoldenpondAudioProcessor::GoldenpondAudioProcessor():AudioProcessor(BusesProperties()){worldofcake::bridge::bootHaxeRuntime();runner=std::make_unique<worldofcake::bridge::GoldenpondControlRunner>();runner->start(.001);}
GoldenpondAudioProcessor::~GoldenpondAudioProcessor(){if(runner)runner->stop();}
void GoldenpondAudioProcessor::prepareToPlay(double r,int){rate=r>0?r:44100;position=0;++epoch;hostPlaying=false;hostPositionKnown=false;lastHostTime=0.0;notes.clear();}
template<class T>void GoldenpondAudioProcessor::process(juce::AudioBuffer<T>&b,juce::MidiBuffer&m){
    b.clear();
    if(!runner)return;
    const auto input = m;
    m.clear();
    // MIDI channel 1 is the keyboard/correction input (JUCE uses 1..16).
    // Corrected keyboard notes are emitted on channel 5, leaving channels 1..4
    // for Goldenpond's four generated parts.
    const bool muted = runner->isModelMuted();
    for(const auto metadata : input){
        if (muted) break; // corrected keyboard notes are musical output too
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
        // A host jump or play/stop is a discontinuity the model's note tracking cannot see.
        notes.releaseAll(0.0, [&](double, const worldofcake::bridge::PreparedEvent& e) {
            m.addEvent(juce::MidiMessage::noteOff(juce::jlimit(1, 16, e.channel + 1), e.data2), 0);
        });
        ++epoch;
        hostEpochSample = static_cast<std::int64_t>(std::llround(hostTime * rate));
        position = hostEpochSample;
    }
    hostPositionKnown = true; hostPlaying = playing; lastHostTime = hostTime;
    runner->setHostTransportTime(hostTime,epoch);
    runner->setHostTransportRunning(playing);
    // Model event times are seconds since this host epoch began. Late events
    // (including note-offs) are delivered at the start of the block, never dropped.
    worldofcake::bridge::PreparedEvent e; int n=0;
    while(n++<512 && runner->popPreparedEvent(e)) notes.schedule(e.timestamp, e);
    const double blockEndTime = (double(position + b.getNumSamples() - hostEpochSample) - 0.5) / rate;
    notes.emitDue(blockEndTime, [&](double time, const worldofcake::bridge::PreparedEvent& ev) {
        const auto eventSample = hostEpochSample + (std::int64_t)std::llround(time * rate);
        const int offset = (int)juce::jlimit<std::int64_t>(0, b.getNumSamples() - 1, eventSample - position);
        const int channel = juce::jlimit(1, 16, ev.channel + 1);
        if(ev.type == worldofcake::bridge::NoteOutputScheduler::kNoteOn) m.addEvent(juce::MidiMessage::noteOn(channel, ev.data2, (juce::uint8)ev.data3), offset);
        else if(ev.type == worldofcake::bridge::NoteOutputScheduler::kNoteOff) m.addEvent(juce::MidiMessage::noteOff(channel, ev.data2, (juce::uint8)ev.data3), offset);
    });
    position += b.getNumSamples();}
void GoldenpondAudioProcessor::processBlock(juce::AudioBuffer<float>&b,juce::MidiBuffer&m){process(b,m);}void GoldenpondAudioProcessor::processBlock(juce::AudioBuffer<double>&b,juce::MidiBuffer&m){process(b,m);}juce::AudioProcessorEditor*GoldenpondAudioProcessor::createEditor(){return new GoldenpondAudioProcessorEditor(*this);}const juce::String GoldenpondAudioProcessor::getName()const{return JucePlugin_Name;}void GoldenpondAudioProcessor::getStateInformation(juce::MemoryBlock&d){if(runner){auto s=runner->exportStateJson();d.replaceAll(s.data(),s.size());}}void GoldenpondAudioProcessor::setStateInformation(const void*p,int n){if(runner&&p&&n>0){runner->importStateJson(std::string((const char*)p,(size_t)n));runner->requestVisualSnapshot();}}juce::AudioProcessor*JUCE_CALLTYPE createPluginFilter(){return new GoldenpondAudioProcessor();}
void GoldenpondAudioProcessor::sendValue(int id,double value)noexcept{if(!runner)return;worldofcake::bridge::ControlCommand c;c.kind=worldofcake::bridge::CommandKind::setValue;c.controlId=id;c.value=value;runner->enqueueGuiCommand(c);}
void GoldenpondAudioProcessor::sendText(int id,const juce::String& value)noexcept{if(!runner)return;worldofcake::bridge::ControlCommand c;c.kind=worldofcake::bridge::CommandKind::textSubmitted;c.controlId=id;value.copyToUTF8(c.text,sizeof(c.text));runner->enqueueGuiCommand(c);}
