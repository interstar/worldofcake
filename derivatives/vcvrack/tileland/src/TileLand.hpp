#pragma once
#include <rack.hpp>
#include <atomic>
#include <memory>
#include <TileLandControlRunner.h>
using namespace rack;
struct TileLand : Module
{
    enum ParamIds
    {
        SPEED_CURSOR1_PARAM,
        SPEED_CURSOR2_PARAM,
        SPEED_CURSOR3_PARAM,
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
        CV_CH1_X_OUTPUT,
        CV_CH1_Y_OUTPUT,
        CV_CH2_X_OUTPUT,
        CV_CH2_Y_OUTPUT,
        CV_CH3_X_OUTPUT,
        CV_CH3_Y_OUTPUT,
        NUM_OUTPUTS
    };
    enum LightIds
    {
        NUM_LIGHTS
    };
    std::unique_ptr<worldofcake::bridge::TileLandControlRunner> runner;
    std::atomic<std::uint64_t> guiSequence{1};
    std::uint64_t hostSequence = 1;
    float cvV[6] = {}, lastSpeed[3] = {-1, -1, -1}, lastReset = 0;
    int lastPause = -1;
    TileLand();
    ~TileLand() override;
    json_t* dataToJson() override;
    void dataFromJson(json_t*) override;
    void process(const ProcessArgs&) override;
    void playAreaClick(float, float);
    void send(int, double);
};
struct TileLandWidget : ModuleWidget
{
    explicit TileLandWidget(TileLand*);
};
