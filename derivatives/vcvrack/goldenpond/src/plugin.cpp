#include "plugin.hpp"
#include "Goldenpond.hpp"
#include <HaxeRuntimeBoot.h>
Plugin* pluginInstance;
Model* modelGoldenpond;
#ifdef _WIN32
extern "C" __declspec(dllexport)
#endif
void init(Plugin* p) { pluginInstance = p; worldofcake::bridge::bootHaxeRuntime(); modelGoldenpond = createModel<Goldenpond, GoldenpondWidget>("Goldenpond"); p->addModel(modelGoldenpond); }
