package gbloink;

import openfl.display.Sprite;
import openfl.display.Graphics;
import worldofcake.IControlPanelView;


class GbloinkView extends Sprite implements IControlPanelView {
    private var engine:Gbloink;

    public function new(engine:Gbloink) {
        super();
        this.engine = engine;
    }

    public function needsRedraw(uid:Int):Bool {
        if (uid == Gbloink.PLAY_AREA_UID) {
            return engine.consumeDirty();
        }
        return false;
    }

    public function redraw(uid:Int):Void {
        if (uid == Gbloink.PLAY_AREA_UID) {
            var g:Graphics = this.graphics;
            g.clear();

            // Background
            g.beginFill(0x000000);
            g.drawRect(0, 0, engine.areaWidth, engine.areaHeight);
            g.endFill();

            // Draw Balls
            for (ball in engine.getBalls()) {
                g.beginFill(ball.colour);
                g.drawCircle(ball.x, ball.y, ball.rad);
                g.endFill();
            }

            // Draw Blocks
            for (block in engine.getBlocks()) {
                g.beginFill(block.colour);
                g.drawRect(block.left, block.top, block.w, block.h);
                g.endFill();
            }
        }
    }
}

