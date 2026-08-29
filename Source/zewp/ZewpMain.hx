package zewp;

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.events.TimerEvent;
import openfl.utils.Timer;
import platform.MonitorInstrument;
import worldofcake.IInstrument;
import worldofcake.WindowPoint;
import worldofcake.ui.ResponsivePanelHost;

class ZewpMain extends Sprite {
    private var world:ZewpWorld;
    private var audioTimer:Timer;
    private var panelHost:ResponsivePanelHost;
    private var monitor:IInstrument;

    private static inline var AUDIO_INTERVAL:Float = 1;
    private var lastAudioTime:Float = 0;
    private var frameCount:Int = 0;

    public function new() {
        super();
        addEventListener(Event.ADDED_TO_STAGE, init);
    }

    private function init(e:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, init);

        world = new ZewpWorld();
        var panel:Sprite = cast world.getView();
        addChild(panel);
        panelHost = new ResponsivePanelHost(stage, panel, ZewpLayout.PANEL_WIDTH, ZewpLayout.PANEL_HEIGHT);

        audioTimer = new Timer(AUDIO_INTERVAL);
        audioTimer.addEventListener(TimerEvent.TIMER, onAudioTick);
        audioTimer.start();

        stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
        stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
        stage.addEventListener(Event.RESIZE, onResize);
        stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);

        #if !woc_preview
        monitor = new MonitorInstrument();
        #end
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

    private function onResize(e:Event):Void {
        panelHost.resize(stage.stageWidth, stage.stageHeight);
    }

    private function onAudioTick(e:TimerEvent):Void {
        var sequencer = world.getSequencer();
        if (frameCount % 100 == 0) {
            trace('Audio tick: ${frameCount}');
        }

        sequencer.advanceTime(AUDIO_INTERVAL / 1000);
        while (sequencer.hasEventBefore(lastAudioTime + (AUDIO_INTERVAL / 1000))) {
            var event = sequencer.getNextEvent();
            #if !woc_preview
            monitor.send(event);
            #end
        }
        lastAudioTime += AUDIO_INTERVAL / 1000;
        frameCount++;
    }

    private function onEnterFrame(e:Event):Void {
        if (frameCount % 60 == 0) {
            trace('Enter frame: ${frameCount}');
        }

        var view = world.getView();
        if (view.needsRedraw(ZewpSequencer.PLAY_AREA_UID)) {
            view.redraw(ZewpSequencer.PLAY_AREA_UID);
        }
        for (uid in [ZewpSequencer.POPULATION_UID, ZewpSequencer.SPEED_UID]) {
            if (view.needsRedraw(uid)) view.redraw(uid);
        }
    }
}
