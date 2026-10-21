#include "plugin.hpp"
#include "Zewp.hpp"
#include <HaxeRuntimeBoot.h>
Plugin* pluginInstance;
Model* modelZewp;
#ifdef _WIN32
extern "C"
    __declspec(dllexport)
#endif
    void
    init(Plugin* p)
{
    pluginInstance = p;
    worldofcake::bridge::bootHaxeRuntime();
    modelZewp = createModel<ZewpModule, ZewpWidget>("Zewp");
    p->addModel(modelZewp);
}
