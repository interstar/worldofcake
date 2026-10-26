#pragma once

#include "WocJuceCoordinateMapper.h"

#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <functional>
#include <vector>

namespace worldofcake::jucehost {

/**
    Shows a model value in a widget only when the model's value changes.

    Editors refresh from snapshots many times a second. Re-applying an unchanged
    model value would overwrite a user edit that has not reached the model yet
    (JUCE combo boxes report changes asynchronously, and sliders are mid-drag),
    so the edit would be lost. Following changes only keeps the widget in step
    with the model without fighting the user.
*/
template <typename T>
struct ModelMirror
{
    template <typename Apply>
    void update(const T& modelValue, Apply&& apply)
    {
        if (!shown || !(modelValue == last)) {
            shown = true;
            last = modelValue;
            apply(modelValue);
        }
    }

  private:
    bool shown = false;
    T last{};
};

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

/** Colours shared by the panel widgets (light chrome around a dark play area); mirrors OpenFL's `Chrome`. */
namespace chrome {
inline const juce::Colour background{0xfff1efea};
inline const juce::Colour playArea{0xff13161c};
inline const juce::Colour face{0xffffffff};
inline const juce::Colour faceActive{0xffe3e6eb};
inline const juce::Colour facePressed{0xffd3d7de};
inline const juce::Colour border{0xffc9cdd4};
inline const juce::Colour borderActive{0xff8a93a3};
inline const juce::Colour text{0xff3a3f48};
inline const juce::Colour track{0xffd3d6dc};
constexpr float corner = 4.0f;
} // namespace chrome

inline juce::Colour rgb(std::uint32_t colour) { return juce::Colour(0xff000000u | colour); }

/** Paints the generated `kBoxes` table (`:box` components on labelled Layla containers). */
template <typename Boxes>
void paintBoxes(juce::Graphics& g, const WocJuceCoordinateMapper& mapper, const Boxes& boxes)
{
    for (const auto& box : boxes) {
        const auto bounds = panelRegion(mapper, box.bounds).reduced(0.5f);
        g.setColour(juce::Colour(box.fill));
        g.fillRoundedRectangle(bounds, chrome::corner * 1.5f);
        if (juce::Colour(box.border).getAlpha() > 0) {
            g.setColour(juce::Colour(box.border));
            g.drawRoundedRectangle(bounds, chrome::corner * 1.5f, 1.0f);
        }
    }
}

/**
    Draws an icon from the shared icon set (generated op lists; see laylagen's icons.clj):
    0 x y move, 1 x y line, 2 cx cy r start end arc (degrees, clockwise), 3 cx cy r dot.
    Coordinates are in a 16x16 box, scaled into `area`.
*/
inline void drawIcon(juce::Graphics& g, const float* ops, std::size_t length,
                     juce::Rectangle<float> area, juce::Colour colour)
{
    const float k = juce::jmin(area.getWidth(), area.getHeight()) / 16.0f;
    const auto origin = area.getCentre() - juce::Point<float>(8.0f * k, 8.0f * k);
    auto at = [&](float x, float y) { return origin + juce::Point<float>(x * k, y * k); };
    juce::Path stroke;
    g.setColour(colour);
    for (std::size_t i = 0; i < length;) {
        switch (static_cast<int>(ops[i])) {
            case 0: stroke.startNewSubPath(at(ops[i + 1], ops[i + 2])); i += 3; break;
            case 1: stroke.lineTo(at(ops[i + 1], ops[i + 2])); i += 3; break;
            case 2: {
                const float cx = ops[i + 1], cy = ops[i + 2], r = ops[i + 3], start = ops[i + 4], end = ops[i + 5];
                const int steps = juce::jmax(2, static_cast<int>(std::ceil(std::abs(end - start) / 15.0f)));
                for (int step = 0; step <= steps; ++step) {
                    const float a = juce::degreesToRadians(start + (end - start) * static_cast<float>(step) / static_cast<float>(steps));
                    const auto p = at(cx + r * std::cos(a), cy + r * std::sin(a));
                    if (step == 0) stroke.startNewSubPath(p); else stroke.lineTo(p);
                }
                i += 6;
                break;
            }
            case 3: {
                const auto c = at(ops[i + 1], ops[i + 2]);
                const float r = ops[i + 3] * k;
                g.fillEllipse(c.x - r, c.y - r, 2.0f * r, 2.0f * r);
                i += 4;
                break;
            }
            default: jassertfalse; return;
        }
    }
    g.strokePath(stroke, juce::PathStrokeType(1.6f * k, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));
}

inline juce::String tooltipFor(const char* tooltip, const char* label)
{
    return (tooltip != nullptr && *tooltip != 0) ? juce::String(tooltip) : juce::String(label);
}

/** A light-chrome button that shows a generated icon. Toggle state is shown, never owned: see the editors. */
class IconButton final : public juce::Button
{
  public:
    template <typename ButtonMetadata>
    explicit IconButton(const ButtonMetadata& metadata)
        : juce::Button(metadata.label), ops(metadata.icon), length(metadata.iconLength),
          content(rgb(metadata.colour))
    {
        setTooltip(tooltipFor(metadata.tooltip, metadata.label));
    }

    void paintButton(juce::Graphics& g, bool highlighted, bool down) override
    {
        const auto bounds = getLocalBounds().toFloat().reduced(0.5f);
        const bool active = getToggleState();
        g.setColour(down ? chrome::facePressed : (active ? chrome::faceActive : chrome::face));
        g.fillRoundedRectangle(bounds, chrome::corner);
        g.setColour(active || highlighted ? chrome::borderActive : chrome::border);
        g.drawRoundedRectangle(bounds, chrome::corner, 1.0f);
        const float size = juce::jmin(bounds.getWidth(), bounds.getHeight()) * 0.55f;
        if (ops != nullptr)
            drawIcon(g, ops, length, bounds.withSizeKeepingCentre(size, size), content);
        else {
            g.setColour(content);
            g.drawText(getButtonText(), getLocalBounds(), juce::Justification::centred, false);
        }
    }

  private:
    const float* ops;
    std::size_t length;
    juce::Colour content;
};

/** Arc-style rotary knobs, a light combo box and tooltips, matching the OpenFL widgets. */
class ChromeLookAndFeel final : public juce::LookAndFeel_V4
{
  public:
    ChromeLookAndFeel()
    {
        setColour(juce::ComboBox::backgroundColourId, chrome::face);
        setColour(juce::ComboBox::outlineColourId, chrome::border);
        setColour(juce::ComboBox::textColourId, chrome::text);
        setColour(juce::ComboBox::arrowColourId, chrome::text);
        setColour(juce::PopupMenu::backgroundColourId, chrome::face);
        setColour(juce::PopupMenu::textColourId, chrome::text);
        setColour(juce::PopupMenu::highlightedBackgroundColourId, chrome::faceActive);
        setColour(juce::PopupMenu::highlightedTextColourId, chrome::text);
        setColour(juce::TooltipWindow::backgroundColourId, chrome::face);
        setColour(juce::TooltipWindow::textColourId, chrome::text);
        setColour(juce::TooltipWindow::outlineColourId, chrome::border);
        setColour(juce::TextEditor::backgroundColourId, chrome::face);
        setColour(juce::TextEditor::textColourId, chrome::text);
        setColour(juce::TextEditor::outlineColourId, chrome::border);
        setColour(juce::TextEditor::focusedOutlineColourId, chrome::borderActive);
        setColour(juce::TextEditor::highlightColourId, chrome::faceActive);
        setColour(juce::CaretComponent::caretColourId, chrome::text);
    }

    void drawRotarySlider(juce::Graphics& g, int x, int y, int width, int height, float position,
                          float startAngle, float endAngle, juce::Slider& slider) override
    {
        const float diameter = juce::jmax(4.0f, static_cast<float>(juce::jmin(width, height)) - 4.0f);
        const float thickness = juce::jmax(2.0f, diameter * 0.09f);
        const float radius = (diameter - thickness) * 0.5f;
        const auto centre = juce::Rectangle<int>(x, y, width, height).toFloat().getCentre();
        const juce::PathStrokeType stroke(thickness, juce::PathStrokeType::curved, juce::PathStrokeType::rounded);
        juce::Path track;
        track.addCentredArc(centre.x, centre.y, radius, radius, 0.0f, startAngle, endAngle, true);
        g.setColour(chrome::track);
        g.strokePath(track, stroke);
        juce::Path value;
        value.addCentredArc(centre.x, centre.y, radius, radius, 0.0f, startAngle,
                            startAngle + position * (endAngle - startAngle), true);
        g.setColour(slider.findColour(juce::Slider::rotarySliderFillColourId));
        g.strokePath(value, stroke);
        const float inner = radius * 0.55f;
        g.setColour(chrome::face);
        g.fillEllipse(centre.x - inner, centre.y - inner, 2.0f * inner, 2.0f * inner);
        g.setColour(chrome::border);
        g.drawEllipse(centre.x - inner, centre.y - inner, 2.0f * inner, 2.0f * inner, 1.0f);
    }
};

/**
    An arc knob driven by generated knob metadata (range, log mapping, colour, tooltip); no text box.
    `interval` quantises the value (e.g. 1 for octaves and MIDI velocity); 0 is continuous.
*/
template <typename KnobMetadata>
void configureKnob(juce::Slider& slider, const KnobMetadata& metadata, double interval = 0.0)
{
    slider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    slider.setTextBoxStyle(juce::Slider::NoTextBox, false, 0, 0);
    slider.setRotaryParameters(juce::degreesToRadians(225.0f), juce::degreesToRadians(495.0f), true);
    slider.setRange(metadata.minimum, metadata.maximum, interval);
    if (std::strcmp(metadata.mapping, "logarithmic") == 0)
        slider.setSkewFactorFromMidPoint(std::sqrt(metadata.minimum * metadata.maximum));
    slider.setValue(metadata.defaultValue, juce::dontSendNotification);
    slider.setColour(juce::Slider::rotarySliderFillColourId, rgb(metadata.colour));
    slider.setTooltip(tooltipFor(metadata.tooltip, metadata.label));
}

constexpr float knobLabelHeight = 16.0f;

/** Where a knob goes in its layout cell: the whole cell, less a strip at the bottom if its label is shown. */
template <typename KnobMetadata>
juce::Rectangle<int> knobBounds(juce::Rectangle<float> cell, const KnobMetadata& metadata)
{
    return (metadata.showLabel ? cell.withTrimmedBottom(knobLabelHeight) : cell).toNearestInt();
}

/** Draws a knob's label under it, when its metadata says to show one (`:show-label`). */
template <typename KnobMetadata>
void paintKnobLabel(juce::Graphics& g, juce::Rectangle<float> cell, const KnobMetadata& metadata)
{
    if (!metadata.showLabel)
        return;
    g.setColour(chrome::text);
    g.setFont(12.0f);
    g.drawText(metadata.label, cell.removeFromBottom(knobLabelHeight).toNearestInt(), juce::Justification::centred, false);
}

/** Draws a generated `:text` component (e.g. a column heading) centred in its layout cell. */
template <typename TextMetadata>
void paintText(juce::Graphics& g, juce::Rectangle<float> cell, const TextMetadata& text)
{
    g.setColour(rgb(text.colour));
    g.setFont(13.0f);
    g.drawText(text.text, cell.toNearestInt(), juce::Justification::centred, false);
}

/**
    A generated `:semantic-select` with the "segmented" presentation: one segment
    per choice in its colour, solid when selected (as OpenFL's SemanticSelect).
    It shows the model's choice and reports clicks; it holds no state of its own.
*/
class SegmentedChoice final : public juce::Component, public juce::SettableTooltipClient
{
  public:
    template <typename SelectMetadata>
    explicit SegmentedChoice(const SelectMetadata& metadata)
    {
        for (std::size_t i = 0; i < metadata.choiceCount; ++i)
            choices.push_back({metadata.choices[i].label, rgb(metadata.choices[i].colour)});
        setTooltip(tooltipFor(metadata.tooltip, metadata.label));
    }

    /** Called with the clicked choice's index. */
    std::function<void(int)> onChoose;

    void setSelectedIndex(int index)
    {
        if (index != selected) {
            selected = index;
            repaint();
        }
    }

    void paint(juce::Graphics& g) override
    {
        const auto width = static_cast<float>(getWidth()) / static_cast<float>(juce::jmax<std::size_t>(1, choices.size()));
        for (std::size_t i = 0; i < choices.size(); ++i) {
            const bool on = static_cast<int>(i) == selected;
            const auto segment = juce::Rectangle<float>(width * static_cast<float>(i), 0.0f, width, static_cast<float>(getHeight()))
                                     .reduced(1.0f, 0.5f);
            g.setColour(choices[i].colour.withAlpha(on ? 1.0f : 0.16f));
            g.fillRoundedRectangle(segment, chrome::corner);
            g.setColour(choices[i].colour.withAlpha(on ? 1.0f : 0.55f));
            g.drawRoundedRectangle(segment, chrome::corner, 1.0f);
            g.setColour(on ? juce::Colours::white : chrome::text);
            g.setFont(juce::FontOptions(12.0f, on ? juce::Font::bold : juce::Font::plain));
            g.drawText(choices[i].label, segment.toNearestInt(), juce::Justification::centred, false);
        }
    }

    void mouseDown(const juce::MouseEvent& event) override
    {
        if (choices.empty() || !onChoose)
            return;
        const int index = juce::jlimit(0, static_cast<int>(choices.size()) - 1,
                                       static_cast<int>(event.position.x / static_cast<float>(getWidth()) * static_cast<float>(choices.size())));
        onChoose(index);
    }

  private:
    struct Choice
    {
        juce::String label;
        juce::Colour colour;
    };
    std::vector<Choice> choices;
    int selected = -1;
};

} // namespace worldofcake::jucehost
