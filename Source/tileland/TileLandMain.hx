package tileland;

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.events.TimerEvent;
import openfl.utils.Timer;
import worldofcake.WindowPoint;
import worldofcake.ui.ResponsivePanelHost;
#if !woc_preview
import platform.MonitorInstrument;
import worldofcake.IInstrument;
#end

class TileLandMain extends Sprite {
    private var world:TileLandWorld;
    private var audioTimer:Timer;
    private var panelHost:ResponsivePanelHost;
    #if !woc_preview
    private var monitor:IInstrument;
    #end

    private static inline var AUDIO_INTERVAL:Float = 1;
    private var lastAudioTime:Float = 0;

    public function new() {
        super();
        addEventListener(Event.ADDED_TO_STAGE, init);
    }

    private function init(e:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, init);

        world = new TileLandWorld();
        var panel:Sprite = cast world.getView();
        addChild(panel);
        panelHost = new ResponsivePanelHost(stage, panel, TileLandLayout.PANEL_WIDTH, TileLandLayout.PANEL_HEIGHT);

        audioTimer = new Timer(AUDIO_INTERVAL);
        audioTimer.addEventListener(TimerEvent.TIMER, onAudioTick);
        audioTimer.start();

        #if !woc_preview
        monitor = new MonitorInstrument();
        #end

        stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
        stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
        stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
        stage.addEventListener(Event.RESIZE, onResize);
        stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
    }

    private function onAudioTick(e:TimerEvent):Void {
        var sequencer = world.getSequencer();
        sequencer.advanceTime(AUDIO_INTERVAL / 1000);

        while (sequencer.hasEventBefore(lastAudioTime + (AUDIO_INTERVAL / 1000))) {
            var event = sequencer.getNextEvent();
            #if !woc_preview
            monitor.send(event);
            #end
        }
        lastAudioTime += AUDIO_INTERVAL / 1000;
    }

    private function onMouseDown(e:MouseEvent):Void {
        world.handleMouseDown(panelHost.stageToDesign(e.stageX, e.stageY));
    }

    private function onMouseMove(e:MouseEvent):Void {
        if (e.buttonDown) {
            world.handleMouseDrag(panelHost.stageToDesign(e.stageX, e.stageY));
        }
    }

    private function onMouseUp(e:MouseEvent):Void {
        world.handleMouseUp(panelHost.stageToDesign(e.stageX, e.stageY));
    }

    private function onKeyDown(e:KeyboardEvent):Void {
        world.handleKeyPressed(String.fromCharCode(e.charCode));
    }

    private function onResize(e:Event):Void {
        panelHost.resize(stage.stageWidth, stage.stageHeight);
    }

    private function onEnterFrame(e:Event):Void {
        if (world.getView().needsRedraw(TileLandSequencer.PLAY_AREA_UID)) {
            world.getView().redraw(TileLandSequencer.PLAY_AREA_UID);
        }

        for (uid in [10, 11, 12, 20]) {
            if (world.getView().needsRedraw(uid)) {
                world.getView().redraw(uid);
            }
        }
    }
}
