package tileland;

import openfl.display.Graphics;
import worldofcake.CoordinateMapper;
import worldofcake.ui.PlayArea;
import worldofcake.ui.ControlValueViewBase;
import generated.tileland.TileLandControlIdsGenerated;

class TileLandView extends ControlValueViewBase {
    private var sequencer:TileLandSequencer;
    private var playArea:PlayArea;

    public function new(sequencer:TileLandSequencer, windowToPanelMapper:CoordinateMapper) {
        super();
        this.sequencer = sequencer;
    }

    private function needsRedraw(uid:Int):Bool {
        if (uid == TileLandSequencer.PLAY_AREA_UID) {
            return sequencer.consumeDirty();
        }
        return TileLandControlIdsGenerated.REDRAW_CONTROL_UIDS.indexOf(uid) >= 0;
    }


    override public function redrawDirty():Void {
        if (needsRedraw(TileLandSequencer.PLAY_AREA_UID)) {
            redraw(TileLandSequencer.PLAY_AREA_UID);
        }

        for (uid in TileLandControlIdsGenerated.REDRAW_CONTROL_UIDS) {
            if (needsRedraw(uid)) {
                redraw(uid);
            }
        }
    }

    private function redraw(uid:Int):Void {
        if (uid == TileLandSequencer.PLAY_AREA_UID) {
            redrawPlayArea();
        } else if (TileLandSequencer.isSpeedUid(uid)) {
            redrawValueControl(uid);
        }
    }

    private function redrawPlayArea():Void {
        var g = playArea.graphics;
        g.clear();

        g.beginFill(0x0C0E14);
        g.drawRect(0, 0, TileLandLayout.PLAY_AREA_WIDTH, TileLandLayout.PLAY_AREA_HEIGHT);
        g.endFill();

        for (row in 0...sequencer.getRows()) {
            for (col in 0...sequencer.getCols()) {
                drawTile(g, sequencer.getTile(col, row));
            }
        }

        for (cursor in sequencer.getCursors()) {
            drawCursor(g, cursor);
        }
    }

    private function drawTile(g:Graphics, tile:Tile):Void {
        g.lineStyle(0.65, 0x373A44, 200 / 255);
        g.drawRect(tile.position.x, tile.position.y, tile.size, tile.size);

        g.lineStyle(1.35, 0xFFFFFF, 215 / 255);
        if (tile.type == TileOrientation.A) {
            g.moveTo(tile.position.x + tile.size / 2, tile.position.y);
            g.curveTo(tile.position.x + tile.size / 2, tile.position.y + tile.size / 2, tile.position.x, tile.position.y + tile.size / 2);

            g.moveTo(tile.position.x + tile.size / 2, tile.position.y + tile.size);
            g.curveTo(tile.position.x + tile.size / 2, tile.position.y + tile.size / 2, tile.position.x + tile.size, tile.position.y + tile.size / 2);
        } else {
            g.moveTo(tile.position.x + tile.size / 2, tile.position.y);
            g.curveTo(tile.position.x + tile.size / 2, tile.position.y + tile.size / 2, tile.position.x + tile.size, tile.position.y + tile.size / 2);

            g.moveTo(tile.position.x + tile.size / 2, tile.position.y + tile.size);
            g.curveTo(tile.position.x + tile.size / 2, tile.position.y + tile.size / 2, tile.position.x, tile.position.y + tile.size / 2);
        }
    }

    private function drawCursor(g:Graphics, cursor:Cursor):Void {
        g.lineStyle(2, cursor.color);
        g.beginFill(cursor.color);
            g.drawCircle(cursor.position.x, cursor.position.y, 5);
        g.endFill();
    }

    public function setPlayArea(playArea:PlayArea):Void {
        this.playArea = playArea;
        addChild(playArea);
    }

}
