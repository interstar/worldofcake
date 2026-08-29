package gbloink;

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.utils.Timer;
import openfl.events.TimerEvent;
import worldofcake.WindowPoint;
import worldofcake.ui.ResponsivePanelHost;
#if !woc_preview
import worldofcake.IInstrument;
import platform.MonitorInstrument;
#end


/**
 * The OpenFL entry point.
 * Wires up the Gbloink engine + view + stage events.
 */
class GbloinkMain extends Sprite {
    private var world:GbloinkWorld;
    private var audioTimer:Timer;
    private var panelHost:ResponsivePanelHost;
    #if !woc_preview
    private var monitor:IInstrument;
    #end
    
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

        world = new GbloinkWorld();
        var panel:Sprite = cast world.getView();
        addChild(panel);
        panelHost = new ResponsivePanelHost(stage, panel, GbloinkLayout.PANEL_WIDTH, GbloinkLayout.PANEL_HEIGHT);
        
        #if !woc_preview
        monitor = new MonitorInstrument();
        #end
        
        // Set up the "audio thread" timer
        audioTimer = new Timer(AUDIO_INTERVAL);
        audioTimer.addEventListener(TimerEvent.TIMER, onAudioTick);
        audioTimer.start();
        
        // Set up event listeners
        stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
        stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
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
        frameCount++;
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

    private function onEnterFrame(e:Event):Void {
        var view = world.getView();
        
        // Check if play area needs redrawing
        if (view.needsRedraw(Gbloink.PLAY_AREA_UID)) {
            view.redraw(Gbloink.PLAY_AREA_UID);
        }
    }
}
