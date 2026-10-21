#pragma once
#include <juce_gui_basics/juce_gui_basics.h>
#include "WorldOfCakeBridgeTypes.h"

namespace worldofcake::jucehost {
/** Maps target-neutral WorldOfCake model coordinates into a JUCE editor. */
class WocJuceCoordinateMapper {
public:
    WocJuceCoordinateMapper(double modelWidth, double modelHeight, juce::Rectangle<int> bounds)
        : panelToView(worldofcake::PanelPoint(0.0, 0.0),
                      worldofcake::PanelPoint(modelWidth, modelHeight),
                      worldofcake::ScreenPoint(static_cast<double>(bounds.getX()),
                                               static_cast<double>(bounds.getY())),
                      worldofcake::ScreenPoint(static_cast<double>(bounds.getRight()),
                                               static_cast<double>(bounds.getBottom()))) {}
    juce::Point<float> toView(double x, double y) const noexcept {
        const auto p = panelToView.forward(x, y);
        return {static_cast<float>(p.x), static_cast<float>(p.y)};
    }
    juce::Rectangle<float> toView(double x, double y, double w, double h) const noexcept {
        auto p = toView(x, y);
        const auto q = toView(x + w, y + h);
        return {p.x, p.y, q.x - p.x, q.y - p.y};
    }
    juce::Point<float> toModel(juce::Point<float> p) const noexcept {
        const auto q = panelToView.backward(p.x, p.y);
        return {static_cast<float>(q.x), static_cast<float>(q.y)};
    }
private:
    worldofcake::CoordinateMapper panelToView;
};
}
