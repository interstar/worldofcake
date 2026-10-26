#pragma once
#include <rack.hpp>
#include <atomic>
#include <memory>
#include <TimeSliderControlRunner.h>
using namespace rack;
struct TimeSlider : Module
{
    enum ParamIds
    {
        SIM_RATE_PARAM,
        RESET_PARAM,
        PAUSE_PARAM,
        NUM_PARAMS
    };
    enum InputIds
    {
        NUM_INPUTS
    };
    enum OutputIds
    {
        CV_SLIDER1_OUTPUT,
        CV_SLIDER2_OUTPUT,
        CV_SLIDER3_OUTPUT,
        CV_SLIDER4_OUTPUT,
        NUM_OUTPUTS
    };
    enum LightIds
    {
        NUM_LIGHTS
    };
    std::unique_ptr<worldofcake::bridge::TimeSliderControlRunner> runner;
    std::atomic<std::uint64_t> guiSequence{1};
    std::uint64_t hostSequence = 1;
    float lastReset = 0.f;
    int lastPause = -1;
    TimeSlider();
    ~TimeSlider() override;
    json_t* dataToJson() override;
    void dataFromJson(json_t*) override;
    void process(const ProcessArgs&) override;
    void trackClick(int, float, float);
    void enqueueHostValue(int, double);
};
struct TimeSliderWidget : ModuleWidget
{
    explicit TimeSliderWidget(TimeSlider*);
};
