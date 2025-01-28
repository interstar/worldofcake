package zewp;

import worldofcake.ISequencer;
import worldofcake.IControlPanel;
import worldofcake.Event;

class ZewpSequencer implements ISequencer implements IControlPanel {
    // Constants
    public static inline var PLAY_AREA_UID:Int = 1;
    public static inline var CC_EVENT_TYPE:Int = 1;  // Type for MIDI CC events
    
    // Dimensions
    public var areaWidth:Int;
    public var areaHeight:Int;
    
    // Game objects
    private var zewps:Array<Zewp>;
    private var blocks:Array<Block>;
    
    // Dragging state
    private var selectedBlock:Block;
    private var dragOffsetX:Float;
    private var dragOffsetY:Float;
    
    // Sequencer state
    private var currentTime:Float;
    private var events:Array<Event>;
    private var dirty:Bool;
    
    public function new(width:Int, height:Int) {
        this.areaWidth = width;
        this.areaHeight = height;
        this.currentTime = 0.0;
        this.events = [];
        this.dirty = true;
        
        // Initialize zewps (12 grey zewps, shorter and faster)
        zewps = [];
        for (i in 0...12) {
            var x = 100 + Math.random() * (width - 200);  // Keep away from edges
            var y = 100 + Math.random() * (height - 200);
            zewps.push(new Zewp(x, y, 10, 4, 0x808080));  // Length 10, speed 4, grey color
        }
        
        // Initialize blocks (20 blocks)
        blocks = [];
        for (i in 0...20) {
            var x = 50 + Math.random() * (width - 100);   // Keep away from edges
            var y = 50 + Math.random() * (height - 100);
            var blockWidth = 30 + Math.random() * 30;     // Random size between 30-60
            var blockHeight = 30 + Math.random() * 30;
            blocks.push(new Block(x, y, blockWidth, blockHeight, 0xFFFFFF));
        }
    }
    
    // ISequencer implementation
    public function advanceTime(delta:Float):Void {
        currentTime += delta;
        
        // Update all zewps
        for (zewp in zewps) {
            zewp.update(zewps, blocks, areaWidth, areaHeight);
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
            // Try to select a block
            for (block in blocks) {
                if (block.hit(x, y)) {
                    selectedBlock = block;
                    dragOffsetX = x - block.x;
                    dragOffsetY = y - block.y;
                    break;
                }
            }
        }
    }
    
    public function mouseDragged(uid:Int, x:Int, y:Int):Void {
        if (uid == PLAY_AREA_UID && selectedBlock != null) {
            selectedBlock.x = x - dragOffsetX;
            selectedBlock.y = y - dragOffsetY;
            dirty = true;
        }
    }
    
    public function mouseUp(uid:Int, x:Int, y:Int):Void {
        selectedBlock = null;
    }
    
    // Unused IControlPanel methods
    public function textSubmitted(uid:Int, text:String):Void {}
    public function newValue(uid:Int, value:Float):Void {}
    public function buttonPressed(uid:Int):Void {}
    
    // Helper methods
    public function generateEvents():Void {
        // Generate CC events for each zewp's position
        for (i in 0...zewps.length) {
            var zewp = zewps[i];
            var channel = i * 2;  // Use two CC channels per zewp
            
            // X position
            events.push(new Event(
                currentTime,
                CC_EVENT_TYPE,
                channel,     // CC number for X
                Std.int((zewp.x / areaWidth) * 127)  // CC value 0-127
            ));
            
            // Y position
            events.push(new Event(
                currentTime,
                CC_EVENT_TYPE,
                channel + 1, // CC number for Y
                Std.int((zewp.y / areaHeight) * 127)  // CC value 0-127
            ));
        }
    }
    
    public function consumeDirty():Bool {
        var wasDirty = dirty;
        dirty = false;
        return wasDirty;
    }
    
    public function getZewps():Array<Zewp> {
        return zewps;
    }
    
    public function getBlocks():Array<Block> {
        return blocks;
    }
    
    public function keyPressed(uid:Int, key:String):Void {}
} 