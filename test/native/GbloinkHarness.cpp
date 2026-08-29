#include <hxcpp.h>
#include "GbloinkControlRunner.h"
#include "TimeSliderControlRunner.h"
#include "TileLandControlRunner.h"
#include "KDiagramControlRunner.h"
#include "ZewpControlRunner.h"

#include <cmath>
#include <atomic>
#include <chrono>
#include <iostream>
#include <thread>

void __boot_all();

extern "C" void __hxcpp_lib_main()
{
    HX_TOP_OF_STACK
    ::hx::Boot();
    __boot_all();
}

namespace
{
    // This is the simulated Rack/JUCE audio consumer. It has no Haxe API access.
    bool consumeAudioBlock (worldofcake::bridge::GbloinkControlRunner& runner,
                            worldofcake::bridge::PreparedEvent& received)
    {
        return runner.popPreparedEvent (received);
    }

    bool consumeLatestControls (worldofcake::bridge::TimeSliderControlRunner& runner,
                                worldofcake::bridge::TimeSliderControlSnapshot& latest)
    {
        bool received = false;
        worldofcake::bridge::TimeSliderControlSnapshot next;
        while (runner.popControlSnapshot (next))
        {
            latest = next;
            received = true;
        }
        return received;
    }

    bool consumeLatestTileLandControls (worldofcake::bridge::TileLandControlRunner& runner,
                                        worldofcake::bridge::TileLandControlSnapshot& latest)
    {
        bool received = false;
        worldofcake::bridge::TileLandControlSnapshot next;
        while (runner.popControlSnapshot (next))
        {
            latest = next;
            received = true;
        }
        return received;
    }

    bool consumeLatestKDiagramControls (worldofcake::bridge::KDiagramControlRunner& runner,
                                        worldofcake::bridge::KDiagramControlSnapshot& latest)
    {
        bool received = false;
        worldofcake::bridge::KDiagramControlSnapshot next;
        while (runner.popControlSnapshot (next)) { latest = next; received = true; }
        return received;
    }

    bool consumeLatestZewpControls(worldofcake::bridge::ZewpControlRunner& runner,
                                   worldofcake::bridge::ZewpControlSnapshot& latest) {
        bool received=false; worldofcake::bridge::ZewpControlSnapshot next;
        while(runner.popControlSnapshot(next)){latest=next;received=true;} return received;
    }
}

int main()
{
    int stackAnchor = 0;
    hx::SetTopOfStack (&stackAnchor, true);
    __hxcpp_lib_main();

    bool manualOk = false;
    {
        worldofcake::bridge::GbloinkControlRunner runner (700.0, 500.0, 12345);
        const auto initial = runner.latestVisualSnapshot();
        worldofcake::bridge::ControlCommand click;
        click.kind = worldofcake::bridge::CommandKind::playAreaClick;
        click.sequence = 1;
        click.x = 105.0;
        click.y = 85.0;
        const bool queued = runner.enqueueGuiCommand (click);
        runner.pump (0.001);

        worldofcake::bridge::PreparedEvent received;
        const bool gotEvent = consumeAudioBlock (runner, received);
        const auto final = runner.latestVisualSnapshot();

        const bool moved = std::abs (final.balls[0].x - initial.balls[0].x) > 0.000001;
        const bool validEvent = gotEvent && received.type == 0 && received.channel == 1;
        const bool noDropsDuringNormalUse = runner.droppedCommands() == 0 && runner.droppedEvents() == 0;
        for (std::uint64_t i = 0; i < 70; ++i)
        {
            click.sequence = i + 2;
            runner.enqueueGuiCommand (click);
        }
        for (std::uint64_t i = 0; i < 70; ++i)
        {
            click.sequence = i + 72;
            runner.enqueueHostCommand (click);
        }
        const bool boundedCommandQueue = runner.droppedGuiCommands() > 0
                                         && runner.droppedHostCommands() > 0
                                         && runner.peakGuiCommandDepth() > 0
                                         && runner.peakHostCommandDepth() > 0;
        manualOk = queued && moved && final.blocks.size() == 1 && validEvent
                   && noDropsDuringNormalUse && boundedCommandQueue;

        std::cout << (manualOk ? "PASS" : "FAIL")
                  << " manual C++ consumer: moved=" << moved
                  << " blocks=" << final.blocks.size()
                  << " event=" << gotEvent
                  << " type=" << received.type
                  << " channel=" << received.channel
                  << " boundedQueue=" << boundedCommandQueue << '\n';
    }

    bool backgroundOk = false;
    {
        worldofcake::bridge::GbloinkControlRunner runner (700.0, 500.0, 12345);
        const auto initial = runner.latestVisualSnapshot();
        worldofcake::bridge::ControlCommand click;
        click.kind = worldofcake::bridge::CommandKind::playAreaClick;
        click.sequence = 1;
        click.x = 105.0;
        click.y = 85.0;
        const bool queued = runner.enqueueGuiCommand (click);
        const bool started = runner.start (0.001);

        worldofcake::bridge::GbloinkVisualSnapshot current;
        worldofcake::bridge::PreparedEvent received;
        bool gotEvent = false;
        for (int attempt = 0; attempt < 200; ++attempt)
        {
            current = runner.latestVisualSnapshot();
            gotEvent = consumeAudioBlock (runner, received) || gotEvent;
            if (current.generation > initial.generation && current.blocks.size() == 1 && gotEvent)
                break;
            std::this_thread::sleep_for (std::chrono::milliseconds (1));
        }
        runner.stop();
        const bool stopped = ! runner.isRunning();
        backgroundOk = queued && started && stopped && current.generation > initial.generation
                       && current.blocks.size() == 1 && gotEvent && received.type == 0
                       && received.channel == 1 && runner.droppedEvents() == 0;
        std::cout << (backgroundOk ? "PASS" : "FAIL")
                  << " background runner: generation=" << current.generation
                  << " blocks=" << current.blocks.size()
                  << " event=" << gotEvent
                  << " stopped=" << stopped << '\n';
    }

    bool unboundedVisualOk = false;
    {
        worldofcake::bridge::GbloinkControlRunner runner (700.0, 500.0, 12345);
        worldofcake::bridge::ControlCommand click;
        click.kind = worldofcake::bridge::CommandKind::playAreaClick;
        for (std::uint64_t i = 0; i < 70; ++i)
        {
            click.sequence = i + 1;
            click.x = 20.0 + (double) (i % 10) * 65.0;
            click.y = 20.0 + (double) (i / 10) * 65.0;
            runner.enqueueGuiCommand (click);
            runner.pump (0.001);
        }
        const auto visual = runner.latestVisualSnapshot();
        unboundedVisualOk = visual.blocks.size() == 70;
        std::cout << (unboundedVisualOk ? "PASS" : "FAIL")
                  << " dynamic Gbloink visual snapshot: blocks=" << visual.blocks.size() << '\n';
    }

    bool dualProducerOk = false;
    {
        worldofcake::bridge::GbloinkControlRunner runner (700.0, 500.0, 12345);
        std::atomic<int> ready { 0 };
        std::atomic<bool> release { false };
        bool guiQueued = false;
        bool hostQueued = false;

        const bool started = runner.start (0.001);
        std::thread guiProducer ([&]
        {
            worldofcake::bridge::ControlCommand command;
            command.kind = worldofcake::bridge::CommandKind::playAreaClick;
            command.sequence = 1;
            command.x = 105.0;
            command.y = 85.0;
            ready.fetch_add (1, std::memory_order_release);
            while (! release.load (std::memory_order_acquire)) {}
            guiQueued = runner.enqueueGuiCommand (command);
        });
        std::thread hostProducer ([&]
        {
            worldofcake::bridge::ControlCommand command;
            command.kind = worldofcake::bridge::CommandKind::playAreaClick;
            command.sequence = 2;
            command.x = 500.0;
            command.y = 350.0;
            ready.fetch_add (1, std::memory_order_release);
            while (! release.load (std::memory_order_acquire)) {}
            hostQueued = runner.enqueueHostCommand (command);
        });
        while (ready.load (std::memory_order_acquire) != 2) {}
        release.store (true, std::memory_order_release);
        guiProducer.join();
        hostProducer.join();

        worldofcake::bridge::GbloinkVisualSnapshot current;
        for (int attempt = 0; attempt < 200; ++attempt)
        {
            current = runner.latestVisualSnapshot();
            if (current.blocks.size() == 2)
                break;
            std::this_thread::sleep_for (std::chrono::milliseconds (1));
        }
        runner.stop();
        dualProducerOk = started && guiQueued && hostQueued && current.blocks.size() == 2
                         && runner.droppedGuiCommands() == 0
                         && runner.droppedHostCommands() == 0
                         && runner.peakGuiCommandDepth() > 0
                         && runner.peakHostCommandDepth() > 0;
        std::cout << (dualProducerOk ? "PASS" : "FAIL")
                  << " dual SPSC producers: gui=" << guiQueued
                  << " host=" << hostQueued
                  << " blocks=" << current.blocks.size() << '\n';
    }

    bool timeSliderManualOk = false;
    {
        worldofcake::bridge::TimeSliderControlRunner runner (800, 600, 120.0, 0.5);
        const auto initial = runner.latestVisualSnapshot();
        worldofcake::bridge::ControlCommand click;
        click.kind = worldofcake::bridge::CommandKind::playAreaClick;
        click.sequence = 1;
        click.x = 200.0;
        click.y = 100.0;
        const bool queued = runner.enqueueGuiCommand (click);
        runner.pump (0.1);
        worldofcake::bridge::TimeSliderControlSnapshot consumed;
        const bool gotSnapshot = consumeLatestControls (runner, consumed);
        timeSliderManualOk = queued && gotSnapshot
                             && consumed.generation > initial.generation
                             && consumed.sliders[0].current < initial.sliders[0].current
                             && consumed.sliders[0].midiValue > initial.sliders[0].midiValue
                             && runner.droppedCommands() == 0 && runner.droppedSnapshots() == 0;
        std::cout << (timeSliderManualOk ? "PASS" : "FAIL")
                  << " TimeSlider manual: generation=" << consumed.generation
                  << " current=" << consumed.sliders[0].current
                  << " midi=" << consumed.sliders[0].midiValue << '\n';
    }

    bool timeSliderBackgroundOk = false;
    {
        worldofcake::bridge::TimeSliderControlRunner runner (800, 600, 120.0, 0.5);
        const auto initial = runner.latestVisualSnapshot();
        worldofcake::bridge::ControlCommand click;
        click.kind = worldofcake::bridge::CommandKind::playAreaClick;
        click.sequence = 1;
        click.x = 200.0;
        click.y = 100.0;
        const bool queued = runner.enqueueHostCommand (click);
        const bool started = runner.start (0.005);
        worldofcake::bridge::TimeSliderControlSnapshot consumed;
        bool gotSnapshot = false;
        for (int attempt = 0; attempt < 200; ++attempt)
        {
            gotSnapshot = consumeLatestControls (runner, consumed) || gotSnapshot;
            if (gotSnapshot && consumed.generation > initial.generation
                && consumed.sliders[0].current < initial.sliders[0].current)
                break;
            std::this_thread::sleep_for (std::chrono::milliseconds (1));
        }
        runner.stop();
        timeSliderBackgroundOk = queued && started && ! runner.isRunning() && gotSnapshot
                                 && consumed.generation > initial.generation
                                 && consumed.sliders[0].current < initial.sliders[0].current
                                 && runner.droppedSnapshots() == 0;
        std::cout << (timeSliderBackgroundOk ? "PASS" : "FAIL")
                  << " TimeSlider background: generation=" << consumed.generation
                  << " current=" << consumed.sliders[0].current
                  << " stopped=" << ! runner.isRunning() << '\n';
    }

    bool tileLandOk = false;
    {
        worldofcake::bridge::TileLandControlRunner runner (12345);
        const auto initial = runner.latestVisualSnapshot();
        const int initialTile = initial.tileTypes[0];
        std::atomic<int> ready { 0 };
        std::atomic<bool> release { false };
        bool guiQueued = false;
        bool hostQueued = false;
        const bool started = runner.start (0.001);

        std::thread guiProducer ([&]
        {
            worldofcake::bridge::ControlCommand click;
            click.kind = worldofcake::bridge::CommandKind::playAreaClick;
            click.sequence = 1;
            click.x = 10.0;
            click.y = 10.0;
            ready.fetch_add (1, std::memory_order_release);
            while (! release.load (std::memory_order_acquire)) {}
            guiQueued = runner.enqueueGuiCommand (click);
        });
        std::thread hostProducer ([&]
        {
            worldofcake::bridge::ControlCommand speed;
            speed.kind = worldofcake::bridge::CommandKind::setValue;
            speed.sequence = 2;
            speed.controlId = 10;
            speed.value = 8.0;
            ready.fetch_add (1, std::memory_order_release);
            while (! release.load (std::memory_order_acquire)) {}
            hostQueued = runner.enqueueHostCommand (speed);
        });
        while (ready.load (std::memory_order_acquire) != 2) {}
        release.store (true, std::memory_order_release);
        guiProducer.join();
        hostProducer.join();

        worldofcake::bridge::TileLandVisualSnapshot visual;
        worldofcake::bridge::TileLandControlSnapshot controls;
        bool gotControls = false;
        for (int attempt = 0; attempt < 200; ++attempt)
        {
            visual = runner.latestVisualSnapshot();
            gotControls = consumeLatestTileLandControls (runner, controls) || gotControls;
            if (visual.generation > initial.generation
                && visual.tileTypes[0] != initialTile
                && std::abs (visual.cursors[0].speed - 8.0) < 0.000001
                && gotControls)
                break;
            std::this_thread::sleep_for (std::chrono::milliseconds (1));
        }
        runner.stop();
        bool outputsInRange = true;
        for (const auto value : controls.values)
            outputsInRange = outputsInRange && value >= 0 && value <= 127;
        tileLandOk = started && ! runner.isRunning() && guiQueued && hostQueued
                     && visual.rows == 12 && visual.cols == 12
                     && visual.tileTypes[0] != initialTile
                     && std::abs (visual.cursors[0].speed - 8.0) < 0.000001
                     && gotControls && outputsInRange
                     && runner.droppedGuiCommands() == 0
                     && runner.droppedHostCommands() == 0
                     && runner.droppedSnapshots() == 0;
        std::cout << (tileLandOk ? "PASS" : "FAIL")
                  << " TileLand dual-input runner: generation=" << visual.generation
                  << " tileFlipped=" << (visual.tileTypes[0] != initialTile)
                  << " speed=" << visual.cursors[0].speed
                  << " outputs=" << gotControls
                  << " stopped=" << ! runner.isRunning() << '\n';
    }

    bool kdiagOk = false;
    {
        worldofcake::bridge::KDiagramControlRunner runner (12345);
        worldofcake::bridge::ControlCommand speed;
        speed.kind = worldofcake::bridge::CommandKind::setValue;
        speed.controlId = 10; speed.value = 8.0;
        worldofcake::bridge::ControlCommand channel;
        channel.kind = worldofcake::bridge::CommandKind::setValue;
        channel.controlId = 20; channel.value = 7.0;
        const bool guiQueued = runner.enqueueGuiCommand (speed);
        const bool hostQueued = runner.enqueueHostCommand (channel);
        runner.pump (1.0);
        const auto visual = runner.latestVisualSnapshot();
        worldofcake::bridge::KDiagramControlSnapshot controls;
        const bool gotControls = consumeLatestKDiagramControls (runner, controls);
        worldofcake::bridge::PreparedEvent event;
        const bool gotArrival = runner.popPreparedEvent (event);
        bool outputsInRange = true;
        for (const auto value : controls.values)
            outputsInRange = outputsInRange && value >= 0 && value <= 127;
        kdiagOk = guiQueued && hostQueued && visual.nodes.size() == 12 && !visual.arcs.empty()
                  && std::abs (visual.cursors[0].speed - 8.0) < 0.000001
                  && visual.cursors[0].channel == 7 && gotControls && outputsInRange
                  && gotArrival && event.type == 0 && event.channel >= 7 && event.channel <= 9
                  && runner.droppedEvents() == 0 && runner.droppedSnapshots() == 0;
        std::cout << (kdiagOk ? "PASS" : "FAIL")
                  << " K-Diag mixed runner: nodes=" << visual.nodes.size()
                  << " arcs=" << visual.arcs.size() << " controls=" << gotControls
                  << " arrival=" << gotArrival << " channel=" << event.channel << '\n';
    }

    bool zewpOk=false;
    {
        worldofcake::bridge::ZewpControlRunner runner(600,560,12345);
        const auto initial=runner.latestVisualSnapshot(); const auto b=initial.blocks[0];
        worldofcake::bridge::ControlCommand down; down.kind=worldofcake::bridge::CommandKind::playAreaClick;down.x=b.x;down.y=b.y;
        auto drag=down;drag.kind=worldofcake::bridge::CommandKind::playAreaDrag;drag.x=b.x+20;drag.y=b.y+15;
        auto up=drag;up.kind=worldofcake::bridge::CommandKind::playAreaRelease;
        const bool queued=runner.enqueueGuiCommand(down)&&runner.enqueueGuiCommand(drag)&&runner.enqueueGuiCommand(up);
        runner.pump(0.001); const auto visual=runner.latestVisualSnapshot();
        worldofcake::bridge::ZewpControlSnapshot controls; const bool got=consumeLatestZewpControls(runner,controls);
        bool range=true;for(auto v:controls.values)range=range&&v>=0&&v<=127;
        zewpOk=queued&&visual.agents.size()==10&&visual.blocks.size()==20
            &&std::abs(visual.blocks[0].x-(b.x+20))<0.000001&&std::abs(visual.blocks[0].y-(b.y+15))<0.000001
            &&got&&range&&runner.droppedGuiCommands()==0&&runner.droppedSnapshots()==0;
        std::cout<<(zewpOk?"PASS":"FAIL")<<" Zewp continuous runner: agents="<<visual.agents.size()
                 <<" blocks="<<visual.blocks.size()<<" dragged="<<(visual.blocks[0].x!=b.x)<<" outputs="<<got<<'\n';
    }

    const bool ok = manualOk && backgroundOk && unboundedVisualOk && dualProducerOk
                    && timeSliderManualOk && timeSliderBackgroundOk && tileLandOk && kdiagOk && zewpOk;
    return ok ? 0 : 1;
}
