# World of Cake - Gbloink (VCV Rack 2 plugin)
# Always run `make` from this directory.
#
# RACK_DIR must be a path with no spaces because GNU Make include/linker handling is fragile around spaces.

WOC_MODULE := gbloink
WOC_HXML := haxe/gbloink.hxml
WOC_RUNNER_CPP := GbloinkControlRunner.cpp
WOC_PANEL_SVG := generated/Gbloink.svg
# The generator already bakes the title and labels into the panel SVG as paths.
WOC_PANEL_TITLE := 0
DISTRIBUTABLES += generated

include ../common/plugin.mk

# Direct GL drawing is local to this module; NanoVG-only modules need no change.
ifdef ARCH_WIN
LDFLAGS += -lopengl32
endif
ifdef ARCH_LIN
LDFLAGS += -lGL
endif
ifdef ARCH_MAC
LDFLAGS += -framework OpenGL
endif
