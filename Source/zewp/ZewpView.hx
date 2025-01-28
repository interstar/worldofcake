package zewp;

import openfl.display.Sprite;
import openfl.display.Graphics;
import worldofcake.IControlPanelView;

class ZewpView extends Sprite implements IControlPanelView {
    private var engine:ZewpSequencer;

    public function new(engine:ZewpSequencer) {
        super();
        this.engine = engine;
    }

    public function needsRedraw(uid:Int):Bool {
        if (uid == ZewpSequencer.PLAY_AREA_UID) {
            return engine.consumeDirty();
        }
        return false;
    }

    public function redraw(uid:Int):Void {
        if (uid == ZewpSequencer.PLAY_AREA_UID) {
            var g:Graphics = this.graphics;
            g.clear();

            // Draw background
            g.beginFill(0x000000);
            g.drawRect(0, 0, engine.areaWidth, engine.areaHeight);
            g.endFill();

            // Draw blocks
            for (block in engine.getBlocks()) {
                g.beginFill(block.color);
                g.drawRect(
                    block.x - block.width/2, 
                    block.y - block.height/2, 
                    block.width, 
                    block.height
                );
                g.endFill();
            }

            // Draw zewps
            for (zewp in engine.getZewps()) {
                g.lineStyle(4, zewp.color);
                
                // Calculate line endpoints
                var x1 = zewp.x - Math.cos(zewp.angle) * zewp.length;
                var y1 = zewp.y - Math.sin(zewp.angle) * zewp.length;
                var x2 = zewp.x + Math.cos(zewp.angle) * zewp.length;
                var y2 = zewp.y + Math.sin(zewp.angle) * zewp.length;
                
                g.moveTo(x1, y1);
                g.lineTo(x2, y2);
            }

            // Generate events after drawing
            engine.generateEvents();
        }
    }
} 