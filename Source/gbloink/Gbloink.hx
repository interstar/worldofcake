package gbloink;

import Math;
import worldofcake.ISequencer;
import worldofcake.IControlPanel;
import worldofcake.Event;
import worldofcake.Utils;
import worldofcake.NoteCalculator;

class Ball {
    public static var COUNTER:Int = 0;

    public var x:Float;
    public var y:Float;
    public var colour:Int;
    public var id:Int;
    public var dx:Float;
    public var dy:Float;
    public var rad:Float;
    public var width:Float;
    public var height:Float;
    public var channel:Int;

    public function new(x:Float, y:Float, colour:Int, w:Float, h:Float, channel:Int) {
        this.x = x;
        this.y = y;
        this.colour = colour;
        this.id = COUNTER++;
        this.dx = 2;
        this.dy = 2;
        this.rad = 5;
        this.width = w;
        this.height = h;
        this.channel = channel;
    }
}

class Block {
    public var x:Float;
    public var y:Float;
    public var w:Float;
    public var h:Float;
    public var left:Float;
    public var top:Float;
    public var right:Float;
    public var bottom:Float;
    public var colour:Int;

    public function new(x:Float, y:Float) {
        this.x = x;
        this.y = y;
        this.w = 20 + Math.random() * 50;
        this.h = 20 + Math.random() * 50;
        this.left   = x - w/2;
        this.top    = y - h/2;
        this.right  = x + w/2;
        this.bottom = y + h/2;
        this.colour = Math.floor(Math.random() * 0xFFFFFF);
    }

    public function hit(tx:Float, ty:Float, r:Float):Bool {
        return (tx + r > left) && (tx - r < right) && 
               (ty + r > top)  && (ty - r < bottom);
    }
}

class Gbloink implements ISequencer implements IControlPanel {
    // Some constants
    public static inline var PLAY_AREA_UID:Int = 1;

    // Sequencer data
    private var currentTime:Float = 0.0;
    private var events:Array<Event>;

    // A "dirty" flag for the view to know we need redraw
    private var dirty:Bool = true;

    // Our "Balls" and "Blocks"
    private var balls:Array<Ball>;
    private var blocks:Array<Block>;

    private var noteCalc:NoteCalculator;

    public var areaWidth:Int;
    public var areaHeight:Int;

    public function new(width:Int, height:Int) {
        this.areaWidth = width;
        this.areaHeight = height;
        this.events = [];
        this.noteCalc = new NoteCalculator();

        // Create some initial balls with different channels
        balls = [
            new Ball(200, 200, 0xFF0000, width, height, 1),  // Red ball - channel 1
            new Ball(300, 300, 0x00FF00, width, height, 2),  // Green ball - channel 2
            new Ball(400, 400, 0x0000FF, width, height, 3)   // Blue ball - channel 3
        ];
        blocks = [];
    }

    ///////////////////////////////////////////////////////////////////////////
    // ISequencer methods
    ///////////////////////////////////////////////////////////////////////////

    public function advanceTime(delta:Float):Void {
        currentTime += delta;
        // Move each ball, check collisions
        for (ball in balls) {
            moveBall(ball);
        }
    }

    public function hasEventBefore(timeLimit:Float):Bool {
        return events.length > 0 && events[0].timestamp <= timeLimit;
    }

    public function getNextEvent():Event {
        return events.shift();
    }

    ///////////////////////////////////////////////////////////////////////////
    // IControlPanel methods
    ///////////////////////////////////////////////////////////////////////////

    // Not used in this example
    public function textSubmitted(uid:Int, text:String):Void {}
    public function mouseDragged(uid:Int, x:Int, y:Int):Void {}
    public function mouseUp(uid:Int, x:Int, y:Int):Void {}
    public function newValue(uid:Int, value:Float):Void {}
    public function buttonPressed(uid:Int):Void {}

    // Main interaction: click to add/remove blocks
    public function mouseDown(uid:Int, x:Int, y:Int):Void {
        if (uid == PLAY_AREA_UID) {
            var foundBlock = false;
            for (block in blocks) {
                if (block.hit(x, y, 0)) {
                    removeBlock(block);
                    foundBlock = true;
                    break;
                }
            }
            if (!foundBlock) {
                addBlock(x, y);
            }
            dirty = true;
        }
    }

    // Add this to the Gbloink class with the other IControlPanel methods
    public function keyPressed(uid:Int, key:String):Void {
        // For now, just an empty implementation
        // We can add specific keyboard controls for Gbloink later if needed
    }

    ///////////////////////////////////////////////////////////////////////////
    // Public helper methods
    ///////////////////////////////////////////////////////////////////////////

    // The view might want to check if we need redraw
    public function consumeDirty():Bool {
        var wasDirty = dirty;
        dirty = false;
        return wasDirty;
    }

    public function getBalls():Array<Ball> {
        return balls;
    }

    public function getBlocks():Array<Block> {
        return blocks;
    }

    public function setScale(scaleName:String):Void {
        noteCalc.setCurrent(scaleName);
    }

    ///////////////////////////////////////////////////////////////////////////
    // Private utility
    ///////////////////////////////////////////////////////////////////////////

    private function pushEvent(evtType:Int, channel:Int, data2:Int, data3:Int):Void {
        events.push(new Event(currentTime, evtType, channel, data2, data3));
    }

    private function removeBlock(block:Block):Void {
        blocks = blocks.filter(b -> b != block);
    }

    private function addBlock(x:Float, y:Float):Void {
        blocks.push(new Block(x, y));
    }

    private function moveBall(ball:Ball):Void {
        var tx = ball.x + ball.dx;
        var ty = ball.y + ball.dy;

        // Walls
        if (tx < ball.rad || tx > areaWidth - ball.rad) ball.dx = -ball.dx;
        if (ty < ball.rad || ty > areaHeight - ball.rad) ball.dy = -ball.dy;

        // Ball-ball collisions
        for (other in balls) {
            if (other == ball) continue;
            var distX = other.x - tx;
            var distY = other.y - ty;
            var distance = Math.sqrt(distX*distX + distY*distY);
            if (distance < ball.rad + other.rad) {
                var overlap = (ball.rad + other.rad) - distance;
                var dirX = distX / distance;
                var dirY = distY / distance;
                ball.x -= dirX*overlap/2; 
                ball.y -= dirY*overlap/2;
                other.x += dirX*overlap/2;
                other.y += dirY*overlap/2;

                // flip velocities
                if (Math.abs(distX) > Math.abs(distY)) {
                    ball.dx = -ball.dx; 
                    other.dx = -other.dx;
                } else {
                    ball.dy = -ball.dy; 
                    other.dy = -other.dy;
                }
            }
        }

        // Ball-block collisions
        for (block in blocks) {
            // Horizontal
            if (block.hit(tx + ball.dx, ball.y, ball.rad)) {
                var note = noteCalc.transform(ball.y);
                pushEvent(0, ball.channel, note, 100); // Note event with channel
                if (ball.dx > 0) ball.x = block.left - ball.rad;
                else             ball.x = block.right + ball.rad;
                ball.dx = -ball.dx;
            }
            // Vertical
            if (block.hit(ball.x, ty + ball.dy, ball.rad)) {
                var note2 = noteCalc.transform(ball.y);
                pushEvent(0, ball.channel, note2, 100);
                if (ball.dy > 0) ball.y = block.top - ball.rad;
                else             ball.y = block.bottom + ball.rad;
                ball.dy = -ball.dy;
            }
        }

        // Update
        ball.x += ball.dx;
        ball.y += ball.dy;
    }

    public function setDirty():Void {
        dirty = true;
    }
}

