#include "PluginProcessor.h"
#include "PluginEditor.h"

#include "HaxeRuntimeBoot.h"
#include "worldofcake/generated/kdiagram/KdiagramControlMetadataGenerated.h"

#include <chrono>

KDiagramAudioProcessor::KDiagramAudioProcessor()
    : AudioProcessor(BusesProperties())
{
    worldofcake::bridge::bootHaxeRuntime();
    const auto seed = static_cast<int>(std::chrono::high_resolution_clock::now().time_since_epoch().count());
    runner = std::make_unique<worldofcake::bridge::KDiagramControlRunner>(seed);
    runner->start(0.001);
    outputParameters = std::make_unique<worldofcake::jucehost::ControlOutputParameters>(
        *this, worldofcake::metadata::kdiagram::kControlOutputs, [this](int i) { return runner->controlOutputValue(i); });
}

KDiagramAudioProcessor::~KDiagramAudioProcessor()
{
    outputParameters.reset();
    if (runner != nullptr)
        runner->stop();
}

void KDiagramAudioProcessor::prepareToPlay(double, int)
{
    hostPlaying = false;
    scheduler.clear();
}

void KDiagramAudioProcessor::releaseResources()
{
    scheduler.clear();
}

void KDiagramAudioProcessor::addMidi(juce::MidiBuffer& midi, const worldofcake::bridge::PreparedEvent& event,
                                     int sampleOffset)
{
    using Scheduler = worldofcake::bridge::NoteOutputScheduler;
    const int channel = juce::jlimit(1, 16, event.channel);
    if (event.type == Scheduler::kNoteOn)
        midi.addEvent(juce::MidiMessage::noteOn(channel, event.data2, static_cast<juce::uint8>(event.data3)), sampleOffset);
    else if (event.type == Scheduler::kNoteOff)
        midi.addEvent(juce::MidiMessage::noteOff(channel, event.data2), sampleOffset);
    else if (event.type == Scheduler::kControlChange)
        midi.addEvent(juce::MidiMessage::controllerEvent(channel, event.data2, event.data3), sampleOffset);
}

template <typename FloatType>
void KDiagramAudioProcessor::process(juce::AudioBuffer<FloatType>& buffer, juce::MidiBuffer& midi)
{
    buffer.clear();
    if (runner == nullptr)
        return;

    // The standalone has no DAW transport: let it run under its own pause control.
    bool playing = juce::JUCEApplicationBase::isStandaloneApp();
    if (const auto position = getPlayHead() != nullptr ? getPlayHead()->getPosition() : std::nullopt)
        playing = position->getIsPlaying();
    // The model stops with the host transport and releases its own notes;
    // anything still scheduled here is released too.
    runner->setHostTransportRunning(playing);
    if (playing != hostPlaying) {
        hostPlaying = playing;
        scheduler.releaseAll(0.0, [&](double, const worldofcake::bridge::PreparedEvent& e) { addMidi(midi, e, 0); });
    }

    // The runner releases events in real time as model time reaches them, so
    // they are due on arrival: play them at the start of this block (as Rack does).
    worldofcake::bridge::PreparedEvent event;
    int drained = 0;
    while (drained++ < 256 && runner->popPreparedEvent(event))
        scheduler.schedule(0.0, event);
    scheduler.emitDue(0.0, [&](double, const worldofcake::bridge::PreparedEvent& e) { addMidi(midi, e, 0); });
}

void KDiagramAudioProcessor::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi)
{
    process(buffer, midi);
}

void KDiagramAudioProcessor::processBlock(juce::AudioBuffer<double>& buffer, juce::MidiBuffer& midi)
{
    process(buffer, midi);
}

juce::AudioProcessorEditor* KDiagramAudioProcessor::createEditor()
{
    return new KDiagramAudioProcessorEditor(*this);
}

worldofcake::bridge::KDiagramVisualSnapshot KDiagramAudioProcessor::visualSnapshot() const
{
    return runner != nullptr ? runner->latestVisualSnapshot() : worldofcake::bridge::KDiagramVisualSnapshot{};
}

bool KDiagramAudioProcessor::enqueueGuiCommand(const worldofcake::bridge::ControlCommand& command) noexcept
{
    return runner != nullptr && runner->enqueueGuiCommand(command);
}

void KDiagramAudioProcessor::getStateInformation(juce::MemoryBlock& destination)
{
    if (runner == nullptr)
        return;
    const auto state = runner->exportStateJson();
    destination.replaceAll(state.data(), state.size());
}

void KDiagramAudioProcessor::setStateInformation(const void* data, int size)
{
    if (runner == nullptr || data == nullptr || size <= 0)
        return;
    runner->importStateJson(std::string(static_cast<const char*>(data), static_cast<std::size_t>(size)));
}

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new KDiagramAudioProcessor();
}
