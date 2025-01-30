package kdiagram;

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.utils.Timer;
import openfl.events.TimerEvent;
import openfl.events.KeyboardEvent;
import worldofcake.IInstrument;
import platform.MonitorInstrument;

class KDiagramMain extends Sprite {
    private var sequencer:KDiagramSequencer;
    private var view:KDiagramView;
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
        sequencer = new KDiagramSequencer(800, 600);
        view = new KDiagramView(sequencer);
        addChild(view);

        // Set up the "audio thread" timer (100Hz)
        audioTimer = new Timer(AUDIO_INTERVAL);
        audioTimer.addEventListener(TimerEvent.TIMER, onAudioTick);
        audioTimer.start();

        // Set up the GUI thread
        addEventListener(Event.ENTER_FRAME, onEnterFrame);

        // Set up mouse handling
        stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);

        // Add keyboard handling
        stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);

        // Only create monitor
        monitor = new MonitorInstrument();
    }

    private function onMouseDown(e:MouseEvent):Void {
        sequencer.mouseDown(KDiagramSequencer.PLAY_AREA_UID, 
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
        
        if (view.needsRedraw(KDiagramSequencer.PLAY_AREA_UID)) {
            view.redraw(KDiagramSequencer.PLAY_AREA_UID);
        }
    }

    private function onKeyDown(e:KeyboardEvent):Void {
        sequencer.keyPressed(KDiagramSequencer.PLAY_AREA_UID, 
                           String.fromCharCode(e.charCode));
    }
} 