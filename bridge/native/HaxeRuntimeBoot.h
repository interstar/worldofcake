#pragma once

#include <hxcpp.h>

#include <mutex>

extern "C" void __hxcpp_lib_main();

namespace worldofcake::bridge
{
    /**
        Boot the hxcpp library once, then release the host thread registered by
        HX_TOP_OF_STACK inside __hxcpp_lib_main(). Rack's plugin-loading thread
        does not execute Haxe after init(), so leaving it registered prevents a
        worker-owned Haxe runtime from completing stop-the-world collection.
    */
    inline void bootHaxeRuntime()
    {
        static std::once_flag once;
        std::call_once(once, [] {
            try {
                ::__hxcpp_lib_main();
            } catch (...) {
                hx::SetTopOfStack(nullptr, true);
                throw;
            }
            hx::SetTopOfStack(nullptr, true);
        });
    }
} // namespace worldofcake::bridge
