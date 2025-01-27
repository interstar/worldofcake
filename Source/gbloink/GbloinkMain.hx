package gbloink;

import openfl.display.Sprite;
import openfl.Lib;
import openfl.events.Event;
import openfl.events.MouseEvent;

/**
 * The OpenFL entry point.
 * Wires up the Gbloink engine + view + stage events.
 */
class GbloinkMain extends Sprite {
    private var engine:Gbloink;
    private var view:GbloinkView;

    private var lastTime:Float = 0;

    public function new() {
        super();
        addEventListener(Event.ADDED_TO_STAGE, init);
    }

    private function init(e:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, init);

        // Create the "engine" that does both ISequencer & IControlPanel
        engine = new Gbloink(800, 400);

        // Create the view
        view = new GbloinkView(engine);
        addChild(view);

        // Listen for frames
        addEventListener(Event.ENTER_FRAME, onEnterFrame);

        // Listen for mouse down
        stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);

        // Force an initial draw
        if (view.needsRedraw(Gbloink.PLAY_AREA_UID)) {
            view.redraw(Gbloink.PLAY_AREA_UID);
        }
    }

    private function onEnterFrame(e:Event):Void {
        var now = Lib.getTimer() / 1000.0;
        var delta = now - lastTime;
        lastTime = now;
        if (delta < 0 || delta > 1) {
            delta = 1.0 / 60.0;
        }

        // "advance time" on the engine
        engine.advanceTime(delta);

        // Possibly redraw
        if (view.needsRedraw(Gbloink.PLAY_AREA_UID)) {
            view.redraw(Gbloink.PLAY_AREA_UID);
        }
    }

    private function onMouseDown(e:MouseEvent):Void {
        // Pass to our engine (which implements IControlPanel)
        engine.mouseDown(Gbloink.PLAY_AREA_UID, e.localX, e.localY);

        // Possibly redraw
        if (view.needsRedraw(Gbloink.PLAY_AREA_UID)) {
            view.redraw(Gbloink.PLAY_AREA_UID);
        }
    }
}

