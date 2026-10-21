#include "plugin.hpp"
#include "Gbloink.hpp"
#include <HaxeRuntimeBoot.h>
#include <asset.hpp>
#include <helpers.hpp>
#include <logger.hpp>

Plugin* pluginInstance;
Model* modelGbloink;

#ifdef _WIN32
extern "C"
    __declspec(dllexport)
#endif
    void
    init(Plugin* p)
{
    pluginInstance = p;
    worldofcake::bridge::bootHaxeRuntime();
    INFO("WorldOfCake-Gbloink: hxcpp runtime initialized and loader thread detached");
    modelGbloink = createModel<Gbloink, GbloinkWidget>("Gbloink");
    p->addModel(modelGbloink);
}
