#pragma once

#include "WocJuceCoordinateMapper.h"

namespace worldofcake::jucehost {

inline void drawPanelTitle(juce::Graphics& g, juce::String text, juce::Rectangle<int> bounds)
{
    g.setColour(juce::Colours::white);
    g.drawText(text, bounds, juce::Justification::centredLeft, false);
}

inline void drawPanelLabel(juce::Graphics& g, juce::String text,
                           juce::Rectangle<float> bounds,
                           juce::Colour colour = juce::Colours::white)
{
    g.setColour(colour);
    g.drawText(text, bounds.toNearestInt(), juce::Justification::centred, false);
}

inline juce::Rectangle<int> panelViewBounds(juce::Component& component, int topInset = 0)
{
    return {0, topInset, component.getWidth(), juce::jmax(1, component.getHeight() - topInset)};
}

inline juce::Rectangle<float> panelRegion(const WocJuceCoordinateMapper& mapper,
                                          const juce::Rectangle<double>& region)
{
    return mapper.toView(region.getX(), region.getY(), region.getWidth(), region.getHeight());
}

} // namespace worldofcake::jucehost
