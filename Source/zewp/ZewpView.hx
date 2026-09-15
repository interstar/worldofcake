package zewp;

import openfl.display.Graphics;
import worldofcake.CoordinateMapper;
import worldofcake.LocalPoint;
import worldofcake.ui.PlayArea;
import worldofcake.ui.ControlValueViewBase;
import generated.zewp.ZewpControlIdsGenerated;

class ZewpView extends ControlValueViewBase {
    private var engine:ZewpSequencer;
    private var playArea:PlayArea;

    public function new(engine:ZewpSequencer, windowToPanelMapper:CoordinateMapper) {
        super();
        this.engine = engine;
    }

    public function setPlayArea(playArea:PlayArea):Void {
        this.playArea = playArea;
        addChild(playArea);
    }

    private function needsRedraw(uid:Int):Bool {
        if (uid == ZewpSequencer.PLAY_AREA_UID) {
            return engine.consumeDirty();
        }
        return ZewpControlIdsGenerated.REDRAW_CONTROL_UIDS.indexOf(uid) >= 0;
    }


    override public function redrawDirty():Void {
        if (needsRedraw(ZewpSequencer.PLAY_AREA_UID)) {
            redraw(ZewpSequencer.PLAY_AREA_UID);
        }

        for (uid in ZewpControlIdsGenerated.REDRAW_CONTROL_UIDS) {
            if (needsRedraw(uid)) {
                redraw(uid);
            }
        }
    }

    private function redraw(uid:Int):Void {
        if (uid == ZewpSequencer.PLAY_AREA_UID) {
            redrawPlayArea();
        } else if (uid == ZewpSequencer.POPULATION_UID || uid == ZewpSequencer.SPEED_UID) {
            redrawValueControl(uid);
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

}
