#pragma once

#include <hxcpp.h>

#include <exception>
#include <mutex>
#include <thread>

extern "C" void __hxcpp_lib_main();

namespace worldofcake::bridge
{
    /**
        Boot the hxcpp library once, on a short-lived thread of its own.

        Booting registers per-thread hxcpp state (stack registration and a
        thread_local thread-info root). Left on the host's loader thread (Rack's
        main thread, a DAW's UI thread), that state outlives the plugin and is
        torn down during DLL unload or process exit, after hxcpp's GC has been
        destroyed, which crashes the host on quit. A dedicated boot thread
        releases its registration and runs its thread_local cleanup when it
        exits, while the runtime is fully alive. Haxe then runs only on the
        runners' control threads.
    */
    inline void bootHaxeRuntime()
    {
        static std::once_flag once;
        std::call_once(once, [] {
            std::exception_ptr failure;
            std::thread boot([&failure] {
                try {
                    ::__hxcpp_lib_main();
                } catch (...) {
                    failure = std::current_exception();
                }
                hx::SetTopOfStack(nullptr, true);
            });
            boot.join();
            if (failure)
                std::rethrow_exception(failure);
        });
    }
} // namespace worldofcake::bridge
