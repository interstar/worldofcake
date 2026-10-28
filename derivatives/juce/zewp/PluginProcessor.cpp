#include "PluginProcessor.h"
#include "PluginEditor.h"

#include "HaxeRuntimeBoot.h"

#include <chrono>

ZewpAudioProcessor::ZewpAudioProcessor()
    : AudioProcessor(BusesProperties())
{
    worldofcake::bridge::bootHaxeRuntime();
    const auto seed = static_cast<int>(std::chrono::high_resolution_clock::now().time_since_epoch().count());
    runner = std::make_unique<worldofcake::bridge::ZewpControlRunner>(seed);
    runner->start(0.001);
}

ZewpAudioProcessor::~ZewpAudioProcessor()
{
    if (runner != nullptr)
        runner->stop();
}

void ZewpAudioProcessor::prepareToPlay(double, int) {}

void ZewpAudioProcessor::releaseResources() {}

void ZewpAudioProcessor::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer&)
{
    buffer.clear();
}

void ZewpAudioProcessor::processBlock(juce::AudioBuffer<double>& buffer, juce::MidiBuffer&)
{
    buffer.clear();
}

juce::AudioProcessorEditor* ZewpAudioProcessor::createEditor()
{
    return new ZewpAudioProcessorEditor(*this);
}

worldofcake::bridge::ZewpVisualSnapshot ZewpAudioProcessor::visualSnapshot() const
{
    return runner != nullptr ? runner->latestVisualSnapshot() : worldofcake::bridge::ZewpVisualSnapshot{};
}

bool ZewpAudioProcessor::enqueueGuiCommand(const worldofcake::bridge::ControlCommand& command) noexcept
{
    return runner != nullptr && runner->enqueueGuiCommand(command);
}

void ZewpAudioProcessor::getStateInformation(juce::MemoryBlock& destination)
{
    if (runner == nullptr)
        return;
    const auto state = runner->exportStateJson();
    destination.replaceAll(state.data(), state.size());
}

void ZewpAudioProcessor::setStateInformation(const void* data, int size)
{
    if (runner == nullptr || data == nullptr || size <= 0)
        return;
    runner->importStateJson(std::string(static_cast<const char*>(data), static_cast<std::size_t>(size)));
}

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new ZewpAudioProcessor();
}
