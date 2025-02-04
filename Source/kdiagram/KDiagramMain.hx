package kdiagram;

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.utils.Timer;
import openfl.events.TimerEvent;
import openfl.events.KeyboardEvent;
import worldofcake.IInstrument;
import platform.MonitorInstrument;
import worldofcake.WindowPoint;

class KDiagramMain extends Sprite {
    private var world:KDiagramWorld;
    private var audioTimer:Timer;
    private var monitor:IInstrument;
    
    // Audio thread runs at 1000Hz (every 1ms)
    private static inline var AUDIO_INTERVAL:Float = 1;
    private var lastAudioTime:Float = 0;
    private var frameCount:Int = 0;

    public function new() {
        super();
        addEventListener(Event.ADDED_TO_STAGE, init);
    }

    private function init(e:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, init);

        world = new KDiagramWorld();
        addChild(cast world.getView());
        
        // Set up the "audio thread" timer
        audioTimer = new Timer(AUDIO_INTERVAL);
        audioTimer.addEventListener(TimerEvent.TIMER, onAudioTick);
        audioTimer.start();
        
        monitor = new MonitorInstrument();
        
        // Set up event listeners
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
            //monitor.send(event);
        }
        lastAudioTime += AUDIO_INTERVAL / 1000;
    }

    private function onMouseDown(e:MouseEvent):Void {
        world.handleMouseDown(new WindowPoint(e.stageX, e.stageY));
    }

    private function onMouseMove(e:MouseEvent):Void {
        if (e.buttonDown) {
            world.handleMouseDrag(new WindowPoint(e.stageX, e.stageY));
        }
    }

    private function onMouseUp(e:MouseEvent):Void {
        world.handleMouseUp(new WindowPoint(e.stageX, e.stageY));
    }

    private function onKeyDown(e:KeyboardEvent):Void {
        world.handleKeyPressed(String.fromCharCode(e.charCode));
    }

    private function onResize(e:Event):Void {
        world.resize(stage.stageWidth, stage.stageHeight);
    }

    private function onEnterFrame(e:Event):Void {
        var view = world.getView();
        
        // Check play area
        if (view.needsRedraw(KDiagramSequencer.PLAY_AREA_UID)) {
            view.redraw(KDiagramSequencer.PLAY_AREA_UID);
        }
        
        // Check UI components
        for (uid in [10, 11, 12, 20]) {  // Speed sliders and channel slider
            if (view.needsRedraw(uid)) {
                view.redraw(uid);
            }
        }
    }
} 