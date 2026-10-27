# Shared World of Cake VCV Rack module build rules.
# Include from derivatives/vcvrack/<module>/Makefile after setting WOC_* variables.

ifndef WOC_MODULE
$(error WOC_MODULE is required)
endif
ifndef WOC_HXML
$(error WOC_HXML is required)
endif
ifndef WOC_RUNNER_CPP
$(error WOC_RUNNER_CPP is required)
endif

PLUGIN_ROOT := $(CURDIR)
WOC_REPO_ROOT := $(abspath $(PLUGIN_ROOT)/../../..)

ifeq ($(OS),Windows_NT)
include $(PLUGIN_ROOT)/../common/platform-windows.mk
else
include $(PLUGIN_ROOT)/../common/platform-linux.mk
endif

WOC_ARTIFACT_ROOT := $(WOC_REPO_ROOT)/build/vcvrack/$(WOC_MODULE)/$(WOC_HOST_PLATFORM)
WOC_RACK_BUILD := $(WOC_ARTIFACT_ROOT)/rack-build
WOC_DIST := $(WOC_ARTIFACT_ROOT)/dist

FLAGS +=
CFLAGS +=
CXXFLAGS +=
LDFLAGS +=

NATIVE := $(WOC_ARTIFACT_ROOT)/native
# `haxelib path` prints the root on line 1 and -D flags on line 2; use line 1 only.
HXCPP := $(shell haxelib path hxcpp 2>/dev/null | sed -n '1p' | tr -d '\r')

$(shell mkdir -p "$(WOC_ARTIFACT_ROOT)")

# Only Rack glue sources; Haxe output is linked via hxcpp's object files below.
LOCAL_SOURCES := $(wildcard src/*.cpp)
BRIDGE_NATIVE := ../../../bridge/native
BRIDGE_SOURCES := $(BRIDGE_NATIVE)/$(WOC_RUNNER_CPP) $(BRIDGE_NATIVE)/ControlThread.cpp
SOURCES := $(LOCAL_SOURCES) $(BRIDGE_SOURCES)

CXXFLAGS += -I"$(NATIVE)/include"
CXXFLAGS += -I"$(PLUGIN_ROOT)/../../../bridge/native"
CXXFLAGS += -I"$(PLUGIN_ROOT)/../common"
ifneq ($(strip $(HXCPP)),)
CXXFLAGS += -I"$(HXCPP)/include"
endif
CXXFLAGS += $(HXCPP_PLATFORM_FLAGS) -DHXCPP_VISIT_ALLOCS -DHX_SMART_STRINGS -DHXCPP_API_LEVEL=430

DISTRIBUTABLES += plugin.json
DISTRIBUTABLES += res
DISTRIBUTABLES += $(wildcard LICENSE*)
DISTRIBUTABLES += $(wildcard presets)

HAXE ?= haxe
WOC_SKIP_CODEGEN ?= 0
VENV_ACTIVATE ?= $(HOME)/.main_python_venv/bin/activate
PANEL_TITLE_SCRIPT := ../inject_panel_title.py
PANEL_TITLE_CONFIG := ../panel_titles.json
WOC_PANEL_TITLE ?= 1

.PHONY: panel_title
panel_title:
ifeq ($(WOC_PANEL_TITLE),1)
	@test -n "$(strip $(WOC_PANEL_SVG))" || (echo "WOC_PANEL_SVG is required when WOC_PANEL_TITLE=1" >&2; exit 1)
	@test -f "$(PANEL_TITLE_SCRIPT)" || (echo "Missing panel title script: $(PANEL_TITLE_SCRIPT)" >&2; exit 1)
	@/bin/bash -lc 'source "$(VENV_ACTIVATE)" && python "$(PANEL_TITLE_SCRIPT)" --module $(WOC_MODULE) --config "$(PANEL_TITLE_CONFIG)" --svg "$(WOC_PANEL_SVG)"'
else
	@true
endif

.PHONY: codegen
ifeq ($(WOC_SKIP_CODEGEN),1)
codegen:
	@test -d "$(NATIVE)/obj/$(HXCPP_OBJDIR)" || (echo "Missing pre-generated hxcpp objects: $(NATIVE)/obj/$(HXCPP_OBJDIR)" >&2; exit 1)
else
codegen: panel_title
	@test -n "$(strip $(HXCPP))" || (echo "hxcpp not found: install with  haxelib install hxcpp" >&2; exit 1)
	cd "$(PLUGIN_ROOT)" && $(HAXE) $(WOC_HXML) -cpp "$(NATIVE)" $(HAXE_PLATFORM_FLAGS)
endif

FLAGS += -fPIC
FLAGS += -I$(RACK_DIR)/include -I$(RACK_DIR)/dep/include
LDFLAGS += -shared
# Plugins must link to libRack because Rack may be used as a plugin of another application.
LDFLAGS += -L$(RACK_DIR) -lRack

include $(RACK_DIR)/arch.mk

TARGET_NAME := plugin
ifdef ARCH_LIN
	TARGET_NAME := $(TARGET_NAME).so
	FLAGS += -fno-gnu-unique
	LDFLAGS += -Wl,-rpath=/tmp/Rack2
	LDFLAGS += -static-libstdc++ -static-libgcc
	XDG_DATA_HOME ?= $(HOME)/.local/share
	RACK_USER_DIR ?= $(XDG_DATA_HOME)/Rack2
endif
ifdef ARCH_MAC
	TARGET_NAME := $(TARGET_NAME).dylib
	LDFLAGS += -undefined dynamic_lookup
	RACK_USER_DIR ?= $(HOME)/Library/Application Support/Rack2
	CODESIGN ?= codesign -f -s -
endif
ifdef ARCH_WIN
	TARGET_NAME := $(TARGET_NAME).dll
	LDFLAGS += -static-libstdc++
	RACK_USER_DIR ?= $(LOCALAPPDATA)/Rack2
endif

TARGET := $(WOC_ARTIFACT_ROOT)/$(TARGET_NAME)
SLUG := $(shell jq -r .slug plugin.json)
VERSION := $(shell jq -r .version plugin.json)
PLUGINS_DIR := $(RACK_USER_DIR)/plugins-$(ARCH_OS)-$(ARCH_CPU)

ifndef SLUG
$(error SLUG could not be found in manifest)
endif
ifndef VERSION
$(error VERSION could not be found in manifest)
endif

OBJCOPY ?= objcopy
STRIP ?= strip
INSTALL_NAME_TOOL ?= install_name_tool
OTOOL ?= otool
DEP_FLAGS += -fPIC
include $(RACK_DIR)/dep.mk

# Platform link policy must follow Rack's dep.mk defaults. On Windows this
# ordering ensures libstdc++ pthread references resolve against the static archive.
LDFLAGS += $(WOC_POST_DEP_LDFLAGS)

FLAGS += -MMD -MP
FLAGS += -g
FLAGS += -O3 -funsafe-math-optimizations -fno-omit-frame-pointer
FLAGS += -Wall -Wextra -Wno-unused-parameter -Wno-vla-extension
CXXFLAGS += -std=c++11

ifdef CROSS_COMPILE
	FLAGS += --target=$(MACHINE)
endif
ifdef ARCH_X64
	FLAGS += -march=nehalem
endif
ifdef ARCH_ARM64
	FLAGS += -march=armv8-a+fp+simd
endif
ifdef ARCH_LIN
	CXXFLAGS += -Wsuggest-override
endif
ifdef ARCH_MAC
	CXXFLAGS += -stdlib=libc++
	MAC_SDK_FLAGS := -mmacosx-version-min=10.9
	FLAGS += $(MAC_SDK_FLAGS)
endif
ifdef ARCH_WIN
	FLAGS += -D_USE_MATH_DEFINES
	FLAGS += -municode
	CXXFLAGS += -Wsuggest-override
endif

FLAGS += $(EXTRA_FLAGS)
CFLAGS += $(EXTRA_CFLAGS)
CXXFLAGS += $(EXTRA_CXXFLAGS)
LDFLAGS += $(EXTRA_LDFLAGS)

CFLAGS += $(FLAGS)
CXXFLAGS += $(FLAGS)

# hxcpp leaves the full runtime as *.o under native/obj/<platform>/.
# `___main__` defines `__hxcpp_lib_main`; do not also compile native/src/__main__.cpp.
HXCPP_LINK_OBJS = $(shell find "$(NATIVE)/obj/$(HXCPP_OBJDIR)" -maxdepth 1 -name '*.o' 2>/dev/null | sort)
LOCAL_OBJECTS := $(patsubst %.cpp,$(WOC_RACK_BUILD)/%.cpp.o,$(LOCAL_SOURCES))
BRIDGE_OBJECTS := $(patsubst $(BRIDGE_NATIVE)/%.cpp,$(WOC_RACK_BUILD)/bridge/native/%.cpp.o,$(BRIDGE_SOURCES))
OBJECTS := $(LOCAL_OBJECTS) $(BRIDGE_OBJECTS) $(OBJECTS)
OBJECTS += $(patsubst %, $(WOC_RACK_BUILD)/%.bin.o, $(BINARIES))
LOCAL_DEPENDENCIES := $(patsubst %.cpp,$(WOC_RACK_BUILD)/%.cpp.d,$(LOCAL_SOURCES))
BRIDGE_DEPENDENCIES := $(patsubst $(BRIDGE_NATIVE)/%.cpp,$(WOC_RACK_BUILD)/bridge/native/%.cpp.d,$(BRIDGE_SOURCES))
DEPENDENCIES := $(LOCAL_DEPENDENCIES) $(BRIDGE_DEPENDENCIES)

ifeq ($(WOC_HOST_PLATFORM),windows)
# MinGW emits G:/... targets, while MSYS make builds /g/... targets. Without
# normalization they are distinct rules and header changes miss existing objects.
# Remade include files also repair dependency files from earlier builds.
$(WOC_RACK_BUILD)/%.d.posix: $(WOC_RACK_BUILD)/%.d
	@sed -E 's@([A-Za-z]):/@/\L\1/@g' "$<" > "$@"
DEPENDENCIES := $(addsuffix .posix,$(DEPENDENCIES))
endif

$(TARGET): $(OBJECTS) $(HXCPP_LINK_OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

-include $(DEPENDENCIES)

$(WOC_RACK_BUILD)/%.c.o: %.c
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -c -o $@ $<

$(WOC_RACK_BUILD)/bridge/native/%.cpp.o: $(BRIDGE_NATIVE)/%.cpp
	@mkdir -p $(@D)
	$(CXX) $(CXXFLAGS) -c -o $@ $<

$(WOC_RACK_BUILD)/%.cpp.o: %.cpp
	@mkdir -p $(@D)
	$(CXX) $(CXXFLAGS) -c -o $@ $<

$(WOC_RACK_BUILD)/%.cc.o: %.cc
	@mkdir -p $(@D)
	$(CXX) $(CXXFLAGS) -c -o $@ $<

$(WOC_RACK_BUILD)/%.m.o: %.m
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -c -o $@ $<

$(WOC_RACK_BUILD)/%.mm.o: %.mm
	@mkdir -p $(@D)
	$(CXX) $(CXXFLAGS) -c -o $@ $<

$(WOC_RACK_BUILD)/%.bin.o: %
	@mkdir -p $(@D)
	xxd -i $< | $(CC) $(CFLAGS) -c -o $@ -xc -

.PHONY: clean
clean:
	rm -rfv "$(WOC_ARTIFACT_ROOT)"

.PHONY: cleandist
cleandist:
	rm -rfv "$(WOC_DIST)"

ZSTD_COMPRESSION_LEVEL ?= 19

.PHONY: dist
dist: build
	rm -rf "$(WOC_DIST)"
	mkdir -p "$(WOC_DIST)/$(SLUG)"
	cp "$(TARGET)" "$(WOC_DIST)/$(SLUG)/"
ifdef ARCH_MAC
	$(STRIP) -S "$(WOC_DIST)/$(SLUG)/$(TARGET_NAME)"
	$(INSTALL_NAME_TOOL) -change libRack.dylib /tmp/Rack2/libRack.dylib "$(WOC_DIST)/$(SLUG)/$(TARGET_NAME)"
	$(OTOOL) -L "$(WOC_DIST)/$(SLUG)/$(TARGET_NAME)"
else
	$(STRIP) -s "$(WOC_DIST)/$(SLUG)/$(TARGET_NAME)"
endif
ifdef CODESIGN
	$(CODESIGN) "$(WOC_DIST)/$(SLUG)/$(TARGET_NAME)"
endif
	cd "$(PLUGIN_ROOT)" && cp -r --parents $(DISTRIBUTABLES) "$(WOC_DIST)/$(SLUG)/"
	cd "$(WOC_DIST)" && tar --no-xattrs -c "$(SLUG)" | zstd -$(ZSTD_COMPRESSION_LEVEL) -o "$(SLUG)-$(VERSION)-$(ARCH_NAME).vcvplugin"

.PHONY: install
install: dist
	mkdir -p "$(PLUGINS_DIR)"
	cp "$(WOC_DIST)"/*.vcvplugin "$(PLUGINS_DIR)"/

.PHONY: build
build: codegen
	+@$(MAKE) --no-print-directory RACK_DIR="$(RACK_DIR)" $(TARGET)

.DEFAULT_GOAL := build
