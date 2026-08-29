package tileland;

import openfl.display.Graphics;
import openfl.display.Sprite;
import worldofcake.CoordinateMapper;
import worldofcake.IControlPanelView;
import worldofcake.ui.PlayArea;
import worldofcake.ui.Slider;

class TileLandView extends Sprite implements IControlPanelView {
    private var sequencer:TileLandSequencer;
    private var playArea:PlayArea;
    private var speedSliders:Array<Slider>;
    private var channelSlider:Slider;
    private var windowToPanelMapper:CoordinateMapper;

    public function new(sequencer:TileLandSequencer, windowToPanelMapper:CoordinateMapper) {
        super();
        this.sequencer = sequencer;
        this.windowToPanelMapper = windowToPanelMapper;
        speedSliders = [];
    }

    public function needsRedraw(uid:Int):Bool {
        if (uid == TileLandSequencer.PLAY_AREA_UID) {
            return sequencer.consumeDirty();
        }
        return (uid >= 10 && uid <= 12) || uid == 20;
    }

    public function redraw(uid:Int):Void {
        if (uid == TileLandSequencer.PLAY_AREA_UID) {
            redrawPlayArea();
        } else if (uid >= 10 && uid <= 12) {
            speedSliders[uid - 10].redraw();
        } else if (uid == 20 && channelSlider != null) {
            channelSlider.redraw();
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

    public function addSlider(slider:Slider):Void {
        speedSliders.push(slider);
        addChild(slider);
    }

    public function setChannelSlider(slider:Slider):Void {
        channelSlider = slider;
        addChild(slider);
    }
}
