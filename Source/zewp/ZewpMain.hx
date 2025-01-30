package zewp;

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.utils.Timer;
import openfl.events.TimerEvent;
import worldofcake.IInstrument;
import platform.MonitorInstrument;

class ZewpMain extends Sprite {
    private var sequencer:ZewpSequencer;
    private var view:ZewpView;
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
        sequencer = new ZewpSequencer(800, 600);
        view = new ZewpView(sequencer);
        addChild(view);

        // Set up the "audio thread" timer (1000Hz)
        audioTimer = new Timer(AUDIO_INTERVAL);
        audioTimer.addEventListener(TimerEvent.TIMER, onAudioTick);
        audioTimer.start();

        // Set up the GUI thread (display refresh)
        addEventListener(Event.ENTER_FRAME, onEnterFrame);

        // Set up mouse handling
        stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
        stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);

        // Only create monitor
        monitor = new MonitorInstrument();
    }

    private function onMouseDown(e:MouseEvent):Void {
        sequencer.mouseDown(ZewpSequencer.PLAY_AREA_UID, Std.int(e.localX), Std.int(e.localY));
    }

    private function onMouseMove(e:MouseEvent):Void {
        if (e.buttonDown) {
            sequencer.mouseDragged(ZewpSequencer.PLAY_AREA_UID, Std.int(e.localX), Std.int(e.localY));
        }
    }

    private function onMouseUp(e:MouseEvent):Void {
        sequencer.mouseUp(ZewpSequencer.PLAY_AREA_UID, Std.int(e.localX), Std.int(e.localY));
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
        
        // GUI thread just handles redraw
        if (view.needsRedraw(ZewpSequencer.PLAY_AREA_UID)) {
            view.redraw(ZewpSequencer.PLAY_AREA_UID);
        }
    }
} 