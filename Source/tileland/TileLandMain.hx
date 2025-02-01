package tileland;

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.events.KeyboardEvent;
import openfl.utils.Timer;
import openfl.events.TimerEvent;
import platform.MonitorInstrument;
import worldofcake.IInstrument;

class TileLandMain extends Sprite {
    private var world:TileLandWorld;
    private var audioTimer:Timer;
    private var monitor:IInstrument;
    
    // Audio thread runs at 1000Hz (every 1ms)
    private static inline var AUDIO_INTERVAL:Float = 1;
    private var lastAudioTime:Float = 0;
    
    public function new() {
        super();
        
        world = new TileLandWorld(800, 700);
        addChild(cast world.getView());  // Cast to DisplayObject
        
        // Set up the "audio thread" timer (1000Hz)
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
            ///monitor.send(event);
        }
        lastAudioTime += AUDIO_INTERVAL / 1000;
    }
    
    private function onMouseDown(e:MouseEvent):Void {
        world.handleMouseDown(e.stageX, e.stageY);
    }
    
    private function onMouseMove(e:MouseEvent):Void {
        if (e.buttonDown) {
            world.handleMouseDrag(e.stageX, e.stageY);
        }
    }
    
    private function onMouseUp(e:MouseEvent):Void {
        world.handleMouseUp(e.stageX, e.stageY);
    }
    
    private function onKeyDown(e:KeyboardEvent):Void {
        world.handleKeyPressed(String.fromCharCode(e.charCode));
    }
    
    private function onResize(e:Event):Void {
        world.resize(stage.stageWidth, stage.stageHeight);
    }
    
    private function onEnterFrame(e:Event):Void {
        // Check play area
        if (world.getView().needsRedraw(TileLandSequencer.PLAY_AREA_UID)) {
            world.getView().redraw(TileLandSequencer.PLAY_AREA_UID);
        }
        
        // Check UI components
        for (uid in [10, 11, 12, 20]) {  // Speed sliders and channel slider
            if (world.getView().needsRedraw(uid)) {
                world.getView().redraw(uid);
            }
        }
    }
} 