package tileland;

import openfl.display.Sprite;
import openfl.display.Graphics;
import worldofcake.IControlPanelView;
import worldofcake.ui.SliderView;
import tileland.Tile;

class TileLandView extends Sprite implements IControlPanelView {
    private var sequencer:TileLandSequencer;
    private var playArea:Sprite;
    private var speedSliders:Array<SliderView>;
    private var channelSlider:SliderView;
    
    // Constants from YAML
    private static inline var PLAY_AREA_X:Float = 20;
    private static inline var PLAY_AREA_Y:Float = 20;
    private static inline var PLAY_AREA_WIDTH:Float = 600;
    private static inline var PLAY_AREA_HEIGHT:Float = 600;
    
    public function new(sequencer:TileLandSequencer) {
        super();
        this.sequencer = sequencer;
        
        // Create play area sprite
        playArea = new Sprite();
        playArea.x = PLAY_AREA_X;
        playArea.y = PLAY_AREA_Y;
        trace('Created play area at ${PLAY_AREA_X},${PLAY_AREA_Y} size ${PLAY_AREA_WIDTH}x${PLAY_AREA_HEIGHT}');
        addChild(playArea);
        
        // Initialize arrays (but don't create sliders - they're managed by World)
        speedSliders = [];
        channelSlider = null;
    }
    
    public function needsRedraw(uid:Int):Bool {
        if (uid == TileLandSequencer.PLAY_AREA_UID) {
            return sequencer.consumeDirty();
        }
        // Add UIDs for sliders (10-12 for speed, 20 for channel)
        return (uid >= 10 && uid <= 12) || uid == 20;
    }
    
    public function redraw(uid:Int):Void {
        if (uid == TileLandSequencer.PLAY_AREA_UID) {
            redrawPlayArea();
        } else if (uid >= 10 && uid <= 12) {
            // Speed sliders need redrawing
            var sliderIndex = uid - 10;
            speedSliders[sliderIndex].redraw();
        } else if (uid == 20) {
            // Channel slider needs redrawing
            channelSlider.redraw();
        }
    }
    
    private function redrawPlayArea():Void {
        var g = playArea.graphics;
        g.clear();
        
        // Draw black background only within play area bounds
        g.beginFill(0x000000);
        g.drawRect(0, 0, PLAY_AREA_WIDTH, PLAY_AREA_HEIGHT);
        g.endFill();
        
        // Add debug rectangle to see play area bounds
        g.lineStyle(1, 0xFF0000);
        g.drawRect(0, 0, PLAY_AREA_WIDTH, PLAY_AREA_HEIGHT);
        
        // Draw grid
        for (row in 0...sequencer.getRows()) {
            for (col in 0...sequencer.getCols()) {
                var tile = sequencer.getTile(col, row);
                drawTile(g, tile);
            }
        }
        
        // Draw cursors
        for (cursor in sequencer.getCursors()) {
            drawCursor(g, cursor);
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
    
    private function drawCursor(g:Graphics, cursor:Cursor):Void {
        g.lineStyle(2, cursor.color);
        g.beginFill(cursor.color);
        g.drawCircle(cursor.x, cursor.y, 5);
        g.endFill();
    }
    
    public function resize(width:Float, height:Float):Void {
        // Update any size-dependent drawing if needed
    }
    
    public function setSliders(speedSliders:Array<SliderView>, channelSlider:SliderView):Void {
        this.speedSliders = speedSliders;
        this.channelSlider = channelSlider;
    }
} 