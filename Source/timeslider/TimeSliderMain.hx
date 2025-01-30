package timeslider;

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.utils.Timer;
import openfl.events.TimerEvent;
import worldofcake.IInstrument;
import platform.MonitorInstrument;

class TimeSliderMain extends Sprite {
    private var sequencer:TimeSliderSequencer;
    private var view:TimeSliderView;
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

        // Initialize sequencer with speed range
        // minSpeed = 0.1 (slow), maxSpeed = 0.5 (fast)
        sequencer = new TimeSliderSequencer(800, 600, 1, 0.0001);
        view = new TimeSliderView(sequencer);
        addChild(view);

        // Set up the "audio thread" timer (100Hz)
        audioTimer = new Timer(AUDIO_INTERVAL);
        audioTimer.addEventListener(TimerEvent.TIMER, onAudioTick);
        audioTimer.start();

        // Set up the GUI thread
        addEventListener(Event.ENTER_FRAME, onEnterFrame);

        // Set up mouse handling
        stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);

        // Only create monitor
        monitor = new MonitorInstrument();
    }

    private function onMouseDown(e:MouseEvent):Void {
        sequencer.mouseDown(TimeSliderSequencer.PLAY_AREA_UID, 
                          Std.int(e.localX), Std.int(e.localY));
    }

    private function onAudioTick(e:TimerEvent):Void {
        // Debug print every 100 ticks
        if (frameCount % 100 == 0) {
            trace('Audio tick: ${frameCount}');
        }
        
        sequencer.advanceTime(AUDIO_INTERVAL / 1000);

        // Check for and process any events
        while (sequencer.hasEventBefore(lastAudioTime + (AUDIO_INTERVAL / 1000))) {
            var event = sequencer.getNextEvent();
            monitor.send(event);
        }
        lastAudioTime += AUDIO_INTERVAL / 1000;
        frameCount++;
    }

    private function onEnterFrame(e:Event):Void {
        // Debug print every 60 frames
        if (frameCount % 60 == 0) {
            trace('Enter frame: ${frameCount}');
        }
        
        if (view.needsRedraw(TimeSliderSequencer.PLAY_AREA_UID)) {
            view.redraw(TimeSliderSequencer.PLAY_AREA_UID);
        }
    }
} 