package zewp;

import worldofcake.ISequencer;
import worldofcake.IControlPanel;
import worldofcake.Event;

class Zewp {
    public var x:Float;
    public var y:Float;
    public var length:Float;
    public var velocity:Float;
    public var color:Int;
    public var channel:Int;
    public var ccNumber:Int;
    
    public function new(x:Float, y:Float, length:Float, velocity:Float, color:Int, 
                       channel:Int, ccNumber:Int) {
        this.x = x;
        this.y = y;
        this.length = length;
        this.velocity = velocity;
        this.color = color;
        this.channel = channel;
        this.ccNumber = ccNumber;
    }
}

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
        
        // Create zewps with different channels and CC numbers
        zewps = [
            new Zewp(100, 100, 20, 4, 0x808080, 1, 10),  // Channel 1, CC 10
            new Zewp(200, 200, 20, 4, 0x808080, 1, 11),  // Channel 1, CC 11
            new Zewp(300, 300, 20, 4, 0x808080, 1, 12)   // Channel 1, CC 12
        ];
        
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
        for (zewp in zewps) {
            events.push(new Event(
                currentTime,
                CC_EVENT_TYPE,
                zewp.channel,
                zewp.ccNumber,
                Std.int((zewp.y / areaHeight) * 127)  // Value
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