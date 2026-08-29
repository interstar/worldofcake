package kdiagram;

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.utils.Timer;
import openfl.events.TimerEvent;
import openfl.events.KeyboardEvent;
import worldofcake.WindowPoint;
import worldofcake.ui.ResponsivePanelHost;
#if !woc_preview
import worldofcake.IInstrument;
import platform.MonitorInstrument;
#end

class KDiagramMain extends Sprite {
    private var world:KDiagramWorld;
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

        world = new KDiagramWorld();
        var panel:Sprite = cast world.getView();
        addChild(panel);
        panelHost = new ResponsivePanelHost(stage, panel, KDiagramLayout.PANEL_WIDTH, KDiagramLayout.PANEL_HEIGHT);
        
        // Set up the "audio thread" timer
        audioTimer = new Timer(AUDIO_INTERVAL);
        audioTimer.addEventListener(TimerEvent.TIMER, onAudioTick);
        audioTimer.start();
        
        #if !woc_preview
        monitor = new MonitorInstrument();
        #end
        
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
            #if !woc_preview
            monitor.send(event);
            #end
        }
        lastAudioTime += AUDIO_INTERVAL / 1000;
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

    private function onKeyDown(e:KeyboardEvent):Void {
        var key = switch (e.keyCode) {
            case 49: "1";
            case 50: "2";
            case 51: "3";
            case 32: " ";
            case 219: "[";
            case 221: "]";
            case _: String.fromCharCode(e.charCode);
        };
        world.handleKeyPressed(key);
    }

    private function onResize(e:Event):Void {
        panelHost.resize(stage.stageWidth, stage.stageHeight);
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
