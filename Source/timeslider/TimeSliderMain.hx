package timeslider;

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.utils.Timer;
import openfl.events.TimerEvent;
import worldofcake.LocalPoint;
import worldofcake.ui.ResponsivePanelHost;
import generated.timeslider.TimeSliderCompositionGenerated;
import generated.timeslider.TimeSliderLayoutGenerated;
#if !woc_preview
import worldofcake.IInstrument;
import platform.MonitorInstrument;
#end

class TimeSliderMain extends Sprite {
    private var sequencer:TimeSliderSequencer;
    private var view:TimeSliderView;
    private var audioTimer:Timer;
    private var panelHost:ResponsivePanelHost;
    #if !woc_preview
    private var monitor:IInstrument;
    #end
    
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

        // Panel dimensions and travel-time defaults are generated from the Layla layout/configuration.
        sequencer = TimeSliderCompositionGenerated.createSequencer();
        view = new TimeSliderView(sequencer);
        addChild(view);
        panelHost = new ResponsivePanelHost(stage, view, TimeSliderLayoutGenerated.PANEL_WIDTH, TimeSliderLayoutGenerated.PANEL_HEIGHT);

        // Set up the "audio thread" timer (100Hz)
        audioTimer = new Timer(AUDIO_INTERVAL);
        audioTimer.addEventListener(TimerEvent.TIMER, onAudioTick);
        audioTimer.start();

        // Set up the GUI thread
        addEventListener(Event.ENTER_FRAME, onEnterFrame);

        // Set up mouse handling
        stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        stage.addEventListener(Event.RESIZE, onResize);

        #if !woc_preview
        monitor = new MonitorInstrument();
        #end
    }

    private function onMouseDown(e:MouseEvent):Void {
        var point = panelHost.stageToDesign(e.stageX, e.stageY);
        sequencer.mouseDown(
            TimeSliderSequencer.PLAY_AREA_UID,
            new LocalPoint(point.x, point.y)
        );
    }

    private function onResize(e:Event):Void {
        panelHost.resize(stage.stageWidth, stage.stageHeight);
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
            #if !woc_preview
            monitor.send(event);
            #end
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
