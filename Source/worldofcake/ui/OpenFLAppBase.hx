package worldofcake.ui;

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.events.TimerEvent;
import openfl.utils.Timer;
#if !woc_preview
import platform.MonitorInstrument;
import worldofcake.IInstrument;
#end
import worldofcake.ISequencer;

class OpenFLAppBase extends Sprite {
    private static inline var AUDIO_INTERVAL:Float = 1;

    private var world:ISequencerWorld;
    private var audioTimer:Timer;
    private var panelHost:ResponsivePanelHost;
    private var lastAudioTime:Float = 0;
    private var frameCount:Int = 0;
    #if !woc_preview
    private var monitor:IInstrument;
    #end

    public function new() {
        super();
        addEventListener(Event.ADDED_TO_STAGE, init);
    }

    private function init(e:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, init);

        world = createWorld();
        var panel:Sprite = cast world.getView();
        addChild(panel);
        panelHost = new ResponsivePanelHost(stage, panel, panelWidth(), panelHeight());

        audioTimer = new Timer(AUDIO_INTERVAL);
        audioTimer.addEventListener(TimerEvent.TIMER, onAudioTick);
        audioTimer.start();

        stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
        stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
        stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
        if (usesKeyboard()) {
            stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
        }
        stage.addEventListener(Event.RESIZE, onResize);
        stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);

        #if !woc_preview
        monitor = new MonitorInstrument();
        #end
    }

    private function createWorld():ISequencerWorld {
        throw "OpenFLAppBase.createWorld must be overridden";
    }

    private function panelWidth():Float {
        throw "OpenFLAppBase.panelWidth must be overridden";
    }

    private function panelHeight():Float {
        throw "OpenFLAppBase.panelHeight must be overridden";
    }

    private function usesKeyboard():Bool {
        return false;
    }

    private function keyFromEvent(e:KeyboardEvent):String {
        return String.fromCharCode(e.charCode);
    }

    private function onAudioTick(e:TimerEvent):Void {
        var sequencer:ISequencer = world.getSequencer();
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

    private function onKeyDown(e:KeyboardEvent):Void {
        world.handleKeyPressed(keyFromEvent(e));
    }

    private function onResize(e:Event):Void {
        panelHost.resize(stage.stageWidth, stage.stageHeight);
    }

    private function onEnterFrame(e:Event):Void {
        world.getView().redrawDirty();
    }
}
