package tileland;

import openfl.display.Sprite;
import openfl.display.Graphics;
import worldofcake.IControlPanelView;
import tileland.Tile;

class TileLandView extends Sprite implements IControlPanelView {
    private var engine:TileLandSequencer;
    
    public function new(engine:TileLandSequencer) {
        super();
        this.engine = engine;
    }
    
    public function needsRedraw(uid:Int):Bool {
        if (uid == TileLandSequencer.PLAY_AREA_UID) {
            return engine.consumeDirty();
        }
        return false;
    }
    
    public function redraw(uid:Int):Void {
        if (uid == TileLandSequencer.PLAY_AREA_UID) {
            var g:Graphics = this.graphics;
            g.clear();
            
            // Draw background
            g.beginFill(0x000000);
            g.drawRect(0, 0, engine.areaWidth, engine.areaHeight);
            g.endFill();
            
            // Draw tiles
            for (row in engine.getTiles()) {
                for (tile in row) {
                    drawTile(g, tile);
                }
            }
            
            // Draw cursors
            for (cursor in engine.getCursors()) {
                g.lineStyle(2, cursor.color);
                g.beginFill(cursor.color);
                g.drawCircle(cursor.x, cursor.y, 5);
                g.endFill();
            }
        }
    }
    
    private function drawTile(g:Graphics, tile:Tile):Void {
        // Draw tile border
        g.lineStyle(1, 0x333333);
        g.drawRect(tile.x, tile.y, tile.size, tile.size);
        
        // Draw curves based on type
        g.lineStyle(2, 0xFFFFFF);
        
        if (tile.type == 1) {
            // Top-left to bottom-right
            g.moveTo(tile.x + tile.size/2, tile.y);
            g.curveTo(tile.x + tile.size/2, tile.y + tile.size/2, 
                     tile.x, tile.y + tile.size/2);
            
            g.moveTo(tile.x + tile.size/2, tile.y + tile.size);
            g.curveTo(tile.x + tile.size/2, tile.y + tile.size/2,
                     tile.x + tile.size, tile.y + tile.size/2);
        } else {
            // Top-right to bottom-left
            g.moveTo(tile.x + tile.size/2, tile.y);
            g.curveTo(tile.x + tile.size/2, tile.y + tile.size/2,
                     tile.x + tile.size, tile.y + tile.size/2);
            
            g.moveTo(tile.x + tile.size/2, tile.y + tile.size);
            g.curveTo(tile.x + tile.size/2, tile.y + tile.size/2,
                     tile.x, tile.y + tile.size/2);
        }
    }
} 