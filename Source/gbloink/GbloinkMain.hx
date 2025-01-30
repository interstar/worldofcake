package gbloink;

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.utils.Timer;
import openfl.events.TimerEvent;
import worldofcake.IInstrument;
import platform.MonitorInstrument;

/**
 * The OpenFL entry point.
 * Wires up the Gbloink engine + view + stage events.
 */
class GbloinkMain extends Sprite {
    private var sequencer:Gbloink;
    private var view:GbloinkView;
    private var audioTimer:Timer;
    private var monitor:IInstrument;
    
    // Audio thread runs at 1000Hz (every 1ms)
    private static inline var AUDIO_INTERVAL:Float = 1;
    private var lastAudioTime:Float = 0;
    private var frameCount:Int = 0;  // Debug counter

    public function new() {
        super();
        addEventListener(Event.ADDED_TO_STAGE, init);
    }

    private function init(e:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, init);

        // Initialize sequencer and view
        sequencer = new Gbloink(800, 600);
        view = new GbloinkView(sequencer);
        addChild(view);

        // Set up the "audio thread" timer (1000Hz)
        audioTimer = new Timer(AUDIO_INTERVAL);
        audioTimer.addEventListener(TimerEvent.TIMER, onAudioTick);
        audioTimer.start();

        // Set up the GUI thread (display refresh)
        addEventListener(Event.ENTER_FRAME, onEnterFrame);

        // Set up mouse handling
        stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);

        monitor = new MonitorInstrument();
    }

    private function onMouseDown(e:MouseEvent):Void {
        // Pass mouse events to the sequencer (which implements IControlPanel)
        sequencer.mouseDown(Gbloink.PLAY_AREA_UID, Std.int(e.localX), Std.int(e.localY));
    }

    private function onAudioTick(e:TimerEvent):Void {
        // Debug print every 100 ticks
        if (frameCount % 100 == 0) {
            trace('Audio tick: ${frameCount}');
        }
        
        sequencer.advanceTime(AUDIO_INTERVAL / 1000);
        
        // Force dirty flag after moving balls
        sequencer.setDirty();  // We'll need to add this method to Gbloink

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
        if (view.needsRedraw(Gbloink.PLAY_AREA_UID)) {
            view.redraw(Gbloink.PLAY_AREA_UID);
        }
    }

    public function keyPressed(uid:Int, key:String):Void {}
}

