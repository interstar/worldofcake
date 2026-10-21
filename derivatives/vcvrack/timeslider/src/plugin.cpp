#include "plugin.hpp"
#include "TimeSlider.hpp"
#include <HaxeRuntimeBoot.h>
#include <asset.hpp>
#include <helpers.hpp>
#include <logger.hpp>

Plugin* pluginInstance;
Model* modelTimeSlider;

#ifdef _WIN32
extern "C"
    __declspec(dllexport)
#endif
    void
    init(Plugin* p)
{
    pluginInstance = p;
    worldofcake::bridge::bootHaxeRuntime();
    INFO("WorldOfCake-TimeSlider: hxcpp runtime initialized and loader thread detached");
    modelTimeSlider = createModel<TimeSlider, TimeSliderWidget>("TimeSlider");
    p->addModel(modelTimeSlider);
}
