cmake_minimum_required(VERSION 3.22)
project(WorldOfCakePlugins VERSION 0.1.1 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
# hxcpp 4.3.2 emits /MT objects for both optimized and debug-symbol builds.
# Every JUCE wrapper target must use the same CRT ABI.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")

set(WOC_JUCE_DIR "" CACHE PATH "Path to a JUCE source checkout")
set(WOC_HXCPP_ROOT "" CACHE PATH "Path to the installed hxcpp library")
set(WOC_GBLOINK_HXCPP_DIR "" CACHE PATH "Gbloink hxcpp output directory")
set(WOC_GBLOINK_HXCPP_OBJECT_DIR "" CACHE PATH "Directory containing compiled Gbloink hxcpp .obj files")
set(WOC_TIMESLIDER_HXCPP_DIR "" CACHE PATH "TimeSlider hxcpp output directory")
set(WOC_TIMESLIDER_HXCPP_OBJECT_DIR "" CACHE PATH "Directory containing compiled TimeSlider hxcpp .obj files")
set(WOC_GOLDENPOND_HXCPP_DIR "" CACHE PATH "Goldenpond hxcpp output directory")
set(WOC_GOLDENPOND_HXCPP_OBJECT_DIR "" CACHE PATH "Directory containing compiled Goldenpond hxcpp .obj files")
set(WOC_KDIAGRAM_HXCPP_DIR "" CACHE PATH "K-Diagram hxcpp output directory")
set(WOC_KDIAGRAM_HXCPP_OBJECT_DIR "" CACHE PATH "Directory containing compiled K-Diagram hxcpp .obj files")

foreach(required WOC_JUCE_DIR WOC_HXCPP_ROOT WOC_GBLOINK_HXCPP_DIR WOC_GBLOINK_HXCPP_OBJECT_DIR)
    if(NOT ${required})
        message(FATAL_ERROR "${required} must be supplied")
    endif()
endforeach()

if(NOT EXISTS "${WOC_JUCE_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "WOC_JUCE_DIR is not a JUCE source checkout: ${WOC_JUCE_DIR}")
endif()

file(GLOB_RECURSE WOC_GBLOINK_HXCPP_OBJECTS CONFIGURE_DEPENDS
    "${WOC_GBLOINK_HXCPP_OBJECT_DIR}/*.obj")
if(NOT WOC_GBLOINK_HXCPP_OBJECTS)
    message(FATAL_ERROR "No compiled hxcpp objects found in ${WOC_GBLOINK_HXCPP_OBJECT_DIR}")
endif()
set_source_files_properties(${WOC_GBLOINK_HXCPP_OBJECTS}
    PROPERTIES EXTERNAL_OBJECT TRUE GENERATED TRUE)
file(GLOB_RECURSE WOC_TIMESLIDER_HXCPP_OBJECTS CONFIGURE_DEPENDS "${WOC_TIMESLIDER_HXCPP_OBJECT_DIR}/*.obj")
set_source_files_properties(${WOC_TIMESLIDER_HXCPP_OBJECTS} PROPERTIES EXTERNAL_OBJECT TRUE GENERATED TRUE)
file(GLOB_RECURSE WOC_GOLDENPOND_HXCPP_OBJECTS CONFIGURE_DEPENDS "${WOC_GOLDENPOND_HXCPP_OBJECT_DIR}/*.obj")
set_source_files_properties(${WOC_GOLDENPOND_HXCPP_OBJECTS} PROPERTIES EXTERNAL_OBJECT TRUE GENERATED TRUE)
file(GLOB_RECURSE WOC_KDIAGRAM_HXCPP_OBJECTS CONFIGURE_DEPENDS "${WOC_KDIAGRAM_HXCPP_OBJECT_DIR}/*.obj")
set_source_files_properties(${WOC_KDIAGRAM_HXCPP_OBJECTS} PROPERTIES EXTERNAL_OBJECT TRUE GENERATED TRUE)

add_subdirectory("${WOC_JUCE_DIR}" "${CMAKE_BINARY_DIR}/JUCE")

juce_add_plugin(WorldOfCakeGbloink
    COMPANY_NAME "GLR"
    BUNDLE_ID "net.glr.worldofcake.gbloink"
    PLUGIN_MANUFACTURER_CODE GlrW
    PLUGIN_CODE Gblk
    FORMATS VST3 Standalone
    PRODUCT_NAME "WorldOfCake Gbloink"
    DESCRIPTION "Experimental MIDI sequencer"
    IS_SYNTH TRUE
    NEEDS_MIDI_INPUT TRUE
    NEEDS_MIDI_OUTPUT TRUE
    IS_MIDI_EFFECT TRUE
    EDITOR_WANTS_KEYBOARD_FOCUS TRUE
    COPY_PLUGIN_AFTER_BUILD FALSE
    NEEDS_WEB_BROWSER FALSE
    NEEDS_CURL FALSE)

set(WOC_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../..")
target_sources(WorldOfCakeGbloink PRIVATE
    gbloink/PluginProcessor.cpp
    gbloink/PluginProcessor.h
    gbloink/PluginEditor.cpp
    gbloink/PluginEditor.h
    "${WOC_ROOT}/bridge/native/ControlThread.cpp"
    "${WOC_ROOT}/bridge/native/GbloinkControlRunner.cpp"
    ${WOC_GBLOINK_HXCPP_OBJECTS})

target_include_directories(WorldOfCakeGbloink PRIVATE
    common
    gbloink
    "${WOC_ROOT}/bridge/native"
    "${WOC_GBLOINK_HXCPP_DIR}/include"
    "${WOC_HXCPP_ROOT}/include")

target_compile_definitions(WorldOfCakeGbloink PUBLIC
    JUCE_WEB_BROWSER=0
    JUCE_USE_CURL=0
    JUCE_VST3_CAN_REPLACE_VST2=0
    JUCE_DISPLAY_SPLASH_SCREEN=0
    HX_WINDOWS
    HXCPP_M64
    HXCPP_VISIT_ALLOCS
    HX_SMART_STRINGS
    HXCPP_API_LEVEL=430)

target_link_libraries(WorldOfCakeGbloink PRIVATE
    juce::juce_audio_utils
    PUBLIC
    juce::juce_recommended_config_flags
    juce::juce_recommended_lto_flags
    juce::juce_recommended_warning_flags)

if(WIN32)
    target_link_libraries(WorldOfCakeGbloink PRIVATE ws2_32 winmm)
endif()

juce_add_plugin(WorldOfCakeTimeSliders COMPANY_NAME "GLR" BUNDLE_ID "net.glr.worldofcake.timesliders" PLUGIN_MANUFACTURER_CODE GlrW PLUGIN_CODE TmSl FORMATS VST3 Standalone PRODUCT_NAME "WorldOfCake TimeSliders" DESCRIPTION "Experimental MIDI CC sequencer" IS_SYNTH TRUE NEEDS_MIDI_OUTPUT TRUE IS_MIDI_EFFECT TRUE EDITOR_WANTS_KEYBOARD_FOCUS TRUE COPY_PLUGIN_AFTER_BUILD FALSE)
target_sources(WorldOfCakeTimeSliders PRIVATE timeslider/PluginProcessor.cpp timeslider/PluginProcessor.h timeslider/PluginEditor.cpp timeslider/PluginEditor.h "${WOC_ROOT}/bridge/native/ControlThread.cpp" "${WOC_ROOT}/bridge/native/TimeSliderControlRunner.cpp" ${WOC_TIMESLIDER_HXCPP_OBJECTS})
target_include_directories(WorldOfCakeTimeSliders PRIVATE common timeslider "${WOC_ROOT}/bridge/native" "${WOC_ROOT}/bridge/haxe" "${WOC_TIMESLIDER_HXCPP_DIR}" "${WOC_TIMESLIDER_HXCPP_DIR}/include" "${WOC_HXCPP_ROOT}/include")
target_compile_definitions(WorldOfCakeTimeSliders PUBLIC JUCE_WEB_BROWSER=0 JUCE_USE_CURL=0 JUCE_VST3_CAN_REPLACE_VST2=0 JUCE_DISPLAY_SPLASH_SCREEN=0 HX_WINDOWS HXCPP_M64 HXCPP_VISIT_ALLOCS HX_SMART_STRINGS HXCPP_API_LEVEL=430)
target_link_libraries(WorldOfCakeTimeSliders PRIVATE juce::juce_audio_utils PUBLIC juce::juce_recommended_config_flags juce::juce_recommended_lto_flags juce::juce_recommended_warning_flags)
if(WIN32)
 target_link_libraries(WorldOfCakeTimeSliders PRIVATE ws2_32 winmm)
endif()

juce_add_plugin(WorldOfCakeGoldenpond COMPANY_NAME "GLR" BUNDLE_ID "net.glr.worldofcake.goldenpond" PLUGIN_MANUFACTURER_CODE GlrW PLUGIN_CODE GldP FORMATS VST3 Standalone PRODUCT_NAME "WorldOfCake Goldenpond" DESCRIPTION "Experimental MIDI score sequencer" IS_SYNTH TRUE NEEDS_MIDI_INPUT TRUE NEEDS_MIDI_OUTPUT TRUE IS_MIDI_EFFECT TRUE EDITOR_WANTS_KEYBOARD_FOCUS TRUE COPY_PLUGIN_AFTER_BUILD FALSE)
target_sources(WorldOfCakeGoldenpond PRIVATE goldenpond/PluginProcessor.cpp goldenpond/PluginProcessor.h goldenpond/PluginEditor.cpp goldenpond/PluginEditor.h "${WOC_ROOT}/bridge/native/ControlThread.cpp" "${WOC_ROOT}/bridge/native/GoldenpondControlRunner.cpp" ${WOC_GOLDENPOND_HXCPP_OBJECTS})
target_include_directories(WorldOfCakeGoldenpond PRIVATE common goldenpond "${WOC_ROOT}/bridge/native" "${WOC_ROOT}/bridge/haxe" "${WOC_GOLDENPOND_HXCPP_DIR}" "${WOC_GOLDENPOND_HXCPP_DIR}/include" "${WOC_HXCPP_ROOT}/include")
target_compile_definitions(WorldOfCakeGoldenpond PUBLIC JUCE_WEB_BROWSER=0 JUCE_USE_CURL=0 JUCE_VST3_CAN_REPLACE_VST2=0 JUCE_DISPLAY_SPLASH_SCREEN=0 HX_WINDOWS HXCPP_M64 HXCPP_VISIT_ALLOCS HX_SMART_STRINGS HXCPP_API_LEVEL=430)
target_link_libraries(WorldOfCakeGoldenpond PRIVATE juce::juce_audio_utils PUBLIC juce::juce_recommended_config_flags juce::juce_recommended_lto_flags juce::juce_recommended_warning_flags)
if(WIN32)
 target_link_libraries(WorldOfCakeGoldenpond PRIVATE ws2_32 winmm)
endif()

juce_add_plugin(WorldOfCakeKDiagram COMPANY_NAME "GLR" BUNDLE_ID "net.glr.worldofcake.kdiagram" PLUGIN_MANUFACTURER_CODE GlrW PLUGIN_CODE KDgm FORMATS VST3 Standalone PRODUCT_NAME "WorldOfCake K-Diagram" DESCRIPTION "Experimental MIDI note and control sequencer" IS_SYNTH TRUE NEEDS_MIDI_INPUT TRUE NEEDS_MIDI_OUTPUT TRUE IS_MIDI_EFFECT TRUE EDITOR_WANTS_KEYBOARD_FOCUS TRUE COPY_PLUGIN_AFTER_BUILD FALSE)
target_sources(WorldOfCakeKDiagram PRIVATE kdiagram/PluginProcessor.cpp kdiagram/PluginProcessor.h kdiagram/PluginEditor.cpp kdiagram/PluginEditor.h "${WOC_ROOT}/bridge/native/ControlThread.cpp" "${WOC_ROOT}/bridge/native/KDiagramControlRunner.cpp" ${WOC_KDIAGRAM_HXCPP_OBJECTS})
target_include_directories(WorldOfCakeKDiagram PRIVATE common kdiagram "${WOC_ROOT}/bridge/native" "${WOC_ROOT}/bridge/haxe" "${WOC_KDIAGRAM_HXCPP_DIR}" "${WOC_KDIAGRAM_HXCPP_DIR}/include" "${WOC_HXCPP_ROOT}/include")
target_compile_definitions(WorldOfCakeKDiagram PUBLIC JUCE_WEB_BROWSER=0 JUCE_USE_CURL=0 JUCE_VST3_CAN_REPLACE_VST2=0 JUCE_DISPLAY_SPLASH_SCREEN=0 HX_WINDOWS HXCPP_M64 HXCPP_VISIT_ALLOCS HX_SMART_STRINGS HXCPP_API_LEVEL=430)
target_link_libraries(WorldOfCakeKDiagram PRIVATE juce::juce_audio_utils PUBLIC juce::juce_recommended_config_flags juce::juce_recommended_lto_flags juce::juce_recommended_warning_flags)
if(WIN32)
 target_link_libraries(WorldOfCakeKDiagram PRIVATE ws2_32 winmm)
endif()

# Shared native note scheduler used by every host adapter; plain C++, no JUCE.
add_executable(NoteOutputSchedulerTest "${WOC_ROOT}/bridge/native/tests/NoteOutputScheduler_test.cpp")
target_include_directories(NoteOutputSchedulerTest PRIVATE "${WOC_ROOT}/bridge/native")
target_compile_features(NoteOutputSchedulerTest PRIVATE cxx_std_17)
