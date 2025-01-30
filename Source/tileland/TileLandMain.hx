package tileland;

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.utils.Timer;
import openfl.events.TimerEvent;
import worldofcake.IInstrument;
import platform.MonitorInstrument;

class TileLandMain extends Sprite {
    private var sequencer:TileLandSequencer;
    private var view:TileLandView;
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
        
        // Initialize sequencer and view
        sequencer = new TileLandSequencer(800, 600);
        view = new TileLandView(sequencer);
        addChild(view);
        
        // Set up the "audio thread" timer (1000Hz)
        audioTimer = new Timer(AUDIO_INTERVAL);
        audioTimer.addEventListener(TimerEvent.TIMER, onAudioTick);
        audioTimer.start();
        
        // Set up the GUI thread
        addEventListener(Event.ENTER_FRAME, onEnterFrame);
        
        // Set up mouse handling
        stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        
        monitor = new MonitorInstrument();
    }
    
    private function onMouseDown(e:MouseEvent):Void {
        sequencer.mouseDown(TileLandSequencer.PLAY_AREA_UID, 
                          Std.int(e.localX), Std.int(e.localY));
    }
    
    private function onAudioTick(e:TimerEvent):Void {
        sequencer.advanceTime(AUDIO_INTERVAL / 1000);
        
        while (sequencer.hasEventBefore(lastAudioTime + (AUDIO_INTERVAL / 1000))) {
            var event = sequencer.getNextEvent();
            monitor.send(event);
        }
        lastAudioTime += AUDIO_INTERVAL / 1000;
        frameCount++;
    }
    
    private function onEnterFrame(e:Event):Void {
        if (view.needsRedraw(TileLandSequencer.PLAY_AREA_UID)) {
            view.redraw(TileLandSequencer.PLAY_AREA_UID);
        }
    }
} 