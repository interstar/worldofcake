package tileland;

import worldofcake.ISequencer;
import worldofcake.IControlPanel;
import worldofcake.Event;
import tileland.Tile;
import tileland.Cursor;
import tileland.Direction;

class TileLandSequencer implements ISequencer implements IControlPanel {
    // Constants
    public static inline var PLAY_AREA_UID:Int = 1;
    
    // Dimensions
    public var areaWidth:Int;
    public var areaHeight:Int;
    private var tileSize:Float;
    private var rows:Int;
    private var cols:Int;
    
    // Game objects
    private var tiles:Array<Array<Tile>>;
    private var dirty:Bool;
    
    // Sequencer state
    private var currentTime:Float;
    private var events:Array<Event>;
    
    // Add to fields
    private var cursors:Array<Cursor>;
    private var cursorSpeed:Float = 16.0; // Adjusted from 100.0 to match current speed
    
    public function new(width:Int, height:Int) {
        this.areaWidth = width;
        this.areaHeight = height;
        this.currentTime = 0.0;
        this.events = [];
        this.dirty = true;
        
        // Initialize grid
        tileSize = 50;  // 50x50 pixel tiles
        rows = Std.int(height / tileSize);
        cols = Std.int(width / tileSize);
        
        // Create tiles
        tiles = [];
        for (row in 0...rows) {
            tiles[row] = [];
            for (col in 0...cols) {
                // Randomly assign type 1 or 2
                var type = (Math.random() < 0.5) ? 1 : 2;
                tiles[row][col] = new Tile(type, col * tileSize, row * tileSize, tileSize);
            }
        }
        
        // Create three cursors with different channels and colors
        cursors = [
            new Cursor(2, 2, Direction.East, 1, 0xFF0000),  // Red cursor - channel 1
            new Cursor(cols-2, 0, Direction.South, 2, 0x00FF00),  // Green cursor - channel 2
            new Cursor(cols-2, rows-2, Direction.West, 3, 0x0000FF)  // Blue cursor - channel 3
        ];
        
        // Initialize cursor positions
        for (cursor in cursors) {
            var tile = tiles[cursor.tileY][cursor.tileX];
            cursor.updatePosition(tile, 0.0, rows, cols, cursorSpeed);
        }
    }
    
    // ISequencer implementation
    public function advanceTime(delta:Float):Void {
        currentTime += delta;
        
        for (cursor in cursors) {
            // Add bounds checking
            if (cursor.tileX < 0 || cursor.tileX >= cols || 
                cursor.tileY < 0 || cursor.tileY >= rows) {
                trace('Invalid cursor position: ${cursor.tileX}, ${cursor.tileY}');
                continue;
            }
            
            var tile = tiles[cursor.tileY][cursor.tileX];
            cursor.updatePosition(tile, delta, rows, cols, cursorSpeed);
            
            // Generate CC events for position
            events.push(new Event(
                currentTime,
                1,  // CC event type
                cursor.channel,
                1,  // CC number for X position
                Std.int((cursor.x / areaWidth) * 127)
            ));
            events.push(new Event(
                currentTime,
                1,  // CC event type
                cursor.channel,
                2,  // CC number for Y position
                Std.int((cursor.y / areaHeight) * 127)
            ));
        }
        
        dirty = true;
    }
    
    public function hasEventBefore(timeLimit:Float):Bool {
        return events.length > 0 && events[0].timestamp <= timeLimit;
    }
    
    public function getNextEvent():Event {
        return events.shift();
    }
    
    // IControlPanel implementation
    public function mouseDown(uid:Int, x:Int, y:Int):Void {
        if (uid == PLAY_AREA_UID) {
            var col = Std.int(x / tileSize);
            var row = Std.int(y / tileSize);
            if (row >= 0 && row < rows && col >= 0 && col < cols) {
                tiles[row][col].flip();
                dirty = true;
            }
        }
    }
    
    // Helper methods
    public function consumeDirty():Bool {
        var wasDirty = dirty;
        dirty = false;
        return wasDirty;
    }
    
    public function getTiles():Array<Array<Tile>> {
        return tiles;
    }
    
    // Unused IControlPanel methods
    public function mouseDragged(uid:Int, x:Int, y:Int):Void {}
    public function mouseUp(uid:Int, x:Int, y:Int):Void {}
    public function textSubmitted(uid:Int, text:String):Void {}
    public function newValue(uid:Int, value:Float):Void {}
    public function buttonPressed(uid:Int):Void {}
    public function keyPressed(uid:Int, key:String):Void {}
    
    // Add getter for cursors
    public function getCursors():Array<Cursor> {
        return cursors;
    }
} 