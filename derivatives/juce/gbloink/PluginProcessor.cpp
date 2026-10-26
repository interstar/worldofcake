#include "PluginProcessor.h"
#include "PluginEditor.h"

#include "HaxeRuntimeBoot.h"

#include <algorithm>
#include <chrono>
#include <cmath>

GbloinkAudioProcessor::GbloinkAudioProcessor()
    : AudioProcessor(BusesProperties())
{
    worldofcake::bridge::bootHaxeRuntime();
    const auto seed = static_cast<int>(std::chrono::high_resolution_clock::now().time_since_epoch().count());
    runner = std::make_unique<worldofcake::bridge::GbloinkControlRunner>(700.0, 500.0, seed);
    runner->start(0.001);
}

GbloinkAudioProcessor::~GbloinkAudioProcessor()
{
    if (runner != nullptr)
        runner->stop();
}

void GbloinkAudioProcessor::prepareToPlay(double sampleRate, int)
{
    currentSampleRate = sampleRate > 0.0 ? sampleRate : 44100.0;
    fallbackSamplePosition = 0;
    ++transportEpoch;
    hostPlaying = false;
    scheduler.clear();
}

void GbloinkAudioProcessor::releaseResources()
{
    scheduler.clear();
}

void GbloinkAudioProcessor::addMidi(juce::MidiBuffer& midi, const worldofcake::bridge::PreparedEvent& event,
                                    int sampleOffset)
{
    const int channel = juce::jlimit(1, 16, event.channel);
    if (event.type == worldofcake::bridge::NoteOutputScheduler::kNoteOn)
        midi.addEvent(juce::MidiMessage::noteOn(channel, event.data2, static_cast<juce::uint8>(event.data3)), sampleOffset);
    else if (event.type == worldofcake::bridge::NoteOutputScheduler::kNoteOff)
        midi.addEvent(juce::MidiMessage::noteOff(channel, event.data2), sampleOffset);
    else
        return;
    diagnosticMidiMessagesEmitted.fetch_add(1, std::memory_order_relaxed);
}

bool GbloinkAudioProcessor::isBusesLayoutSupported(const BusesLayout&) const
{
    return true;
}

template <typename FloatType>
void GbloinkAudioProcessor::process(juce::AudioBuffer<FloatType>& buffer, juce::MidiBuffer& midi)
{
    buffer.clear();
    const auto numSamples = buffer.getNumSamples();

    bool playing = false;
    if (const auto position = getPlayHead() != nullptr ? getPlayHead()->getPosition() : std::nullopt) {
        playing = position->getIsPlaying();
    }
    diagnosticHostPlaying.store(playing, std::memory_order_relaxed);

    if (runner == nullptr)
        return;

    // Publish the transport state even while stopped.  The control runner
    // must suspend physics/event generation rather than continuing from the
    // last clock value while the audio callback is returning early.
    runner->setHostTransportRunning(playing);

    // Host play/stop is a discontinuity the model's note tracking cannot see.
    if (playing != hostPlaying) {
        hostPlaying = playing;
        ++transportEpoch;
        scheduler.releaseAll(0.0, [&](double, const worldofcake::bridge::PreparedEvent& e) { addMidi(midi, e, 0); });
    }
    // Keep Gbloink's existing host-clock model, but gate it on the DAW
    // transport.  Holding the last host time prevents Haxe physics and MIDI
    // events from continuing while a host such as FL Studio is stopped.
    if (!playing)
        return;

    const auto epochBlockStart = fallbackSamplePosition;
    const auto lookAheadSamples = static_cast<std::int64_t>(std::llround(currentSampleRate * lookAheadSeconds));
    const double requestedTime = static_cast<double>(epochBlockStart + numSamples + lookAheadSamples) / currentSampleRate;
    runner->setHostTransportTime(requestedTime, transportEpoch);

    // The model supplies complete notes (note-on plus note-off) and handles
    // pause/mute itself; this shell only places them on the host timeline.
    worldofcake::bridge::PreparedEvent event;
    int drained = 0;
    while (drained++ < 256 && runner->popPreparedEvent(event)) {
        diagnosticBridgeReceived.fetch_add(1, std::memory_order_relaxed);
        const bool staleNoteOn = event.type == worldofcake::bridge::NoteOutputScheduler::kNoteOn &&
                                 event.transportEpoch != transportEpoch;
        if (staleNoteOn) {
            diagnosticStaleEvents.fetch_add(1, std::memory_order_relaxed);
            continue;
        }
        scheduler.schedule(event.timestamp, event);
        if (event.type == worldofcake::bridge::NoteOutputScheduler::kNoteOn)
            diagnosticTriggersQueued.fetch_add(1, std::memory_order_relaxed);
    }
    const double blockEndTime = (static_cast<double>(epochBlockStart + numSamples) - 0.5) / currentSampleRate;
    scheduler.emitDue(blockEndTime, [&](double time, const worldofcake::bridge::PreparedEvent& e) {
        const auto sample = static_cast<std::int64_t>(std::llround(time * currentSampleRate));
        addMidi(midi, e, static_cast<int>(juce::jlimit<std::int64_t>(0, numSamples - 1, sample - epochBlockStart)));
    });

    fallbackSamplePosition += numSamples;
}

void GbloinkAudioProcessor::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi)
{
    process(buffer, midi);
}

void GbloinkAudioProcessor::processBlock(juce::AudioBuffer<double>& buffer, juce::MidiBuffer& midi)
{
    process(buffer, midi);
}

juce::AudioProcessorEditor* GbloinkAudioProcessor::createEditor()
{
    return new GbloinkAudioProcessorEditor(*this);
}

worldofcake::bridge::GbloinkVisualSnapshot GbloinkAudioProcessor::visualSnapshot() const
{
    return runner != nullptr ? runner->latestVisualSnapshot()
                             : worldofcake::bridge::GbloinkVisualSnapshot{};
}

bool GbloinkAudioProcessor::enqueueGuiCommand(
    const worldofcake::bridge::ControlCommand& command) noexcept
{
    return runner != nullptr && runner->enqueueGuiCommand(command);
}

GbloinkPluginDiagnostics GbloinkAudioProcessor::diagnostics() const noexcept
{
    GbloinkPluginDiagnostics result;
    result.hostPlaying = diagnosticHostPlaying.load(std::memory_order_relaxed);
    result.haxePrepared = runner != nullptr ? runner->preparedEventCount() : 0;
    result.bridgeReceived = diagnosticBridgeReceived.load(std::memory_order_relaxed);
    result.triggersQueued = diagnosticTriggersQueued.load(std::memory_order_relaxed);
    result.midiMessagesEmitted = diagnosticMidiMessagesEmitted.load(std::memory_order_relaxed);
    result.staleEvents = diagnosticStaleEvents.load(std::memory_order_relaxed);
    return result;
}

bool GbloinkAudioProcessor::hasEditor() const { return true; }
const juce::String GbloinkAudioProcessor::getName() const { return JucePlugin_Name; }
bool GbloinkAudioProcessor::acceptsMidi() const { return true; }
bool GbloinkAudioProcessor::producesMidi() const { return true; }
bool GbloinkAudioProcessor::isMidiEffect() const { return true; }
double GbloinkAudioProcessor::getTailLengthSeconds() const { return 0.0; }
int GbloinkAudioProcessor::getNumPrograms() { return 1; }
int GbloinkAudioProcessor::getCurrentProgram() { return 0; }
void GbloinkAudioProcessor::setCurrentProgram(int) {}
const juce::String GbloinkAudioProcessor::getProgramName(int) { return {}; }
void GbloinkAudioProcessor::changeProgramName(int, const juce::String&) {}

void GbloinkAudioProcessor::getStateInformation(juce::MemoryBlock& destination)
{
    if (runner == nullptr)
        return;
    const auto state = runner->exportStateJson();
    destination.replaceAll(state.data(), state.size());
}

void GbloinkAudioProcessor::setStateInformation(const void* data, int size)
{
    if (runner == nullptr || data == nullptr || size <= 0)
        return;
    runner->importStateJson(std::string(static_cast<const char*>(data), static_cast<std::size_t>(size)));
}

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new GbloinkAudioProcessor();
}
