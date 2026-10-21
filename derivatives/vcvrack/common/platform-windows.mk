# Windows policy for the shared WorldOfCake Rack build.
WOC_HOST_PLATFORM := windows
RACK_DIR ?= ../../Rack-SDK-2.6.4-win-x64/Rack-SDK
HXCPP_OBJDIR := mingw64
HXCPP_PLATFORM_FLAGS := -DHX_WINDOWS -DHXCPP_M64
HAXE_PLATFORM_FLAGS := -D HXCPP_MINGW

# Rack already requests a static C++ runtime. Keep libgcc and winpthread static
# as well so the plugin can load without MSYS2 runtime DLLs beside Rack.exe.
WOC_POST_DEP_LDFLAGS := -static-libgcc -Wl,--whole-archive -Wl,/mingw64/lib/libwinpthread.a -Wl,--no-whole-archive
