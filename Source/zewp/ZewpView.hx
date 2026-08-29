package zewp;

import openfl.display.Graphics;
import openfl.display.Sprite;
import worldofcake.CoordinateMapper;
import worldofcake.IControlPanelView;
import worldofcake.LocalPoint;
import worldofcake.ui.PlayArea;
import worldofcake.ui.Slider;

class ZewpView extends Sprite implements IControlPanelView {
    private var engine:ZewpSequencer;
    private var windowToPanelMapper:CoordinateMapper;
    private var playArea:PlayArea;
    private var sliders:Array<Slider> = [];

    public function new(engine:ZewpSequencer, windowToPanelMapper:CoordinateMapper) {
        super();
        this.engine = engine;
        this.windowToPanelMapper = windowToPanelMapper;
    }

    public function setPlayArea(playArea:PlayArea):Void {
        this.playArea = playArea;
        addChild(playArea);
    }

    public function needsRedraw(uid:Int):Bool {
        if (uid == ZewpSequencer.PLAY_AREA_UID) {
            return engine.consumeDirty();
        }
        return uid == ZewpSequencer.POPULATION_UID || uid == ZewpSequencer.SPEED_UID;
    }

    public function redraw(uid:Int):Void {
        if (uid == ZewpSequencer.PLAY_AREA_UID) {
            redrawPlayArea();
        } else if (uid == ZewpSequencer.POPULATION_UID || uid == ZewpSequencer.SPEED_UID) {
            sliders[uid - ZewpSequencer.POPULATION_UID].redraw();
        }
    }

    private function redrawPlayArea():Void {
        var g:Graphics = playArea.graphics;
        g.clear();

        g.beginFill(0x000000);
        g.drawRect(0, 0, ZewpLayout.PLAY_AREA_WIDTH, ZewpLayout.PLAY_AREA_HEIGHT);
        g.endFill();

        for (block in engine.getBlocks()) {
            var bounds = block.bounds;
            var topLeft = localToPlayAreaDisplay(bounds.topLeft());
            g.beginFill(block.color);
            g.drawRect(
                topLeft.x,
                topLeft.y,
                playArea.localLengthToWindowLength(bounds.width()),
                playArea.localLengthToWindowLength(bounds.height())
            );
            g.endFill();
        }

        for (zewp in engine.getZewps()) {
            var p1 = localToPlayAreaDisplay(new LocalPoint(
                zewp.position.x - Math.cos(zewp.angle) * zewp.length,
                zewp.position.y - Math.sin(zewp.angle) * zewp.length
            ));
            var p2 = localToPlayAreaDisplay(new LocalPoint(
                zewp.position.x + Math.cos(zewp.angle) * zewp.length,
                zewp.position.y + Math.sin(zewp.angle) * zewp.length
            ));

            g.lineStyle(4, zewp.color);
            g.moveTo(p1.x, p1.y);
            g.lineTo(p2.x, p2.y);
        }

        engine.generateEvents();
    }

    private function localToPlayAreaDisplay(localPoint:LocalPoint):LocalPoint {
        var windowPoint = playArea.localToWindow(localPoint);
        return new LocalPoint(windowPoint.x - playArea.x, windowPoint.y - playArea.y);
    }

    public function addSlider(slider:Slider):Void {
        sliders.push(slider);
        addChild(slider);
    }
}
