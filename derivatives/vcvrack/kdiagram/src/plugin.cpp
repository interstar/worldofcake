#include "plugin.hpp"
#include "KDiagram.hpp"
#include <HaxeRuntimeBoot.h>
#include <asset.hpp>
#include <helpers.hpp>
#include <logger.hpp>

Plugin* pluginInstance;
Model* modelKDiagram;

#ifdef _WIN32
extern "C"
    __declspec(dllexport)
#endif
    void
    init(Plugin* p)
{
    pluginInstance = p;
    worldofcake::bridge::bootHaxeRuntime();
    INFO("WorldOfCake-KDiagram: hxcpp runtime initialized and loader thread detached");
    modelKDiagram = createModel<KDiagram, KDiagramWidget>("KDiagram");
    p->addModel(modelKDiagram);
}
