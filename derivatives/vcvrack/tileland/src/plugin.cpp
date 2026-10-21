#include "plugin.hpp"
#include "TileLand.hpp"
#include <HaxeRuntimeBoot.h>
#include <asset.hpp>
#include <helpers.hpp>
#include <logger.hpp>

Plugin* pluginInstance;
Model* modelTileLand;

#ifdef _WIN32
extern "C"
    __declspec(dllexport)
#endif
    void
    init(Plugin* p)
{
    pluginInstance = p;
    worldofcake::bridge::bootHaxeRuntime();
    INFO("WorldOfCake-TileLand: hxcpp runtime initialized and loader thread detached");
    modelTileLand = createModel<TileLand, TileLandWidget>("TileLand");
    p->addModel(modelTileLand);
}
