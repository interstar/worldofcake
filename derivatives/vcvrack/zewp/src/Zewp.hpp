#pragma once
#include <rack.hpp>
#include <memory>
#include <atomic>
#include <ZewpControlRunner.h>
using namespace rack;
struct ZewpModule : Module
{
    enum ParamIds
    {
        POPULATION_PARAM,
        SPEED_PARAM,
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
        X1_OUTPUT,
        Y1_OUTPUT,
        GATE1_OUTPUT,
        X2_OUTPUT,
        Y2_OUTPUT,
        GATE2_OUTPUT,
        X3_OUTPUT,
        Y3_OUTPUT,
        GATE3_OUTPUT,
        X4_OUTPUT,
        Y4_OUTPUT,
        GATE4_OUTPUT,
        X5_OUTPUT,
        Y5_OUTPUT,
        GATE5_OUTPUT,
        X6_OUTPUT,
        Y6_OUTPUT,
        GATE6_OUTPUT,
        NUM_OUTPUTS
    };
    enum LightIds
    {
        NUM_LIGHTS
    };
    std::unique_ptr<worldofcake::bridge::ZewpControlRunner> runner;
    std::atomic<std::uint64_t> guiSequence{1};
    std::uint64_t hostSequence = 1;
    float cv[18] = {};
    float lastPop = -1, lastSpeed = -1, lastReset = 0;
    int lastPause = -1;
    ZewpModule();
    ~ZewpModule() override;
    void process(const ProcessArgs&) override;
    json_t* dataToJson() override;
    void dataFromJson(json_t*) override;
    void click(float, float);
    void drag(float, float);
    void release(float, float);
    void send(int, double);
};
struct ZewpWidget : ModuleWidget
{
    explicit ZewpWidget(ZewpModule*);
};
