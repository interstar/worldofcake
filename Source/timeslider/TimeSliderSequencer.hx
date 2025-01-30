package timeslider;

import worldofcake.ISequencer;
import worldofcake.IControlPanel;
import worldofcake.Event;

// TimeSlider class definition
class TimeSlider {
    public var x:Float;
    public var y:Float;
    public var width:Float;
    public var height:Float;
    public var channel:Int;     // Add channel
    public var ccNumber:Int;    // This is now separate from channel
    
    public var current:Float;
    public var destination:Float;
    public var speed:Float;
    public var moving:Bool;
    
    private var minSpeed:Float;
    private var maxSpeed:Float;
    
    public function new(x:Float, y:Float, width:Float, height:Float, 
                       channel:Int, ccNumber:Int, minSpeed:Float, maxSpeed:Float) {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        this.channel = channel;
        this.ccNumber = ccNumber;
        this.minSpeed = minSpeed;
        this.maxSpeed = maxSpeed;
        
        // Start in middle
        this.current = height/2;
        this.destination = current;
        this.moving = false;
        this.speed = 0;
    }
    
    public function hit(px:Float, py:Float):Bool {
        return (px >= x && px <= x + width && 
                py >= y && py <= y + height);
    }
    
    public function setDestination(px:Float, py:Float):Void {
        var relativeX = (px - x) / width;  // 0 to 1 from left to right
        var targetY = py - y;
        
        if (targetY < 0) targetY = 0;
        if (targetY > height) targetY = height;
        
        destination = targetY;
        
        if (relativeX < 0.01) relativeX = 0.01;

        // At left side (relativeX = 0): uses maxSpeed
        // At right side (relativeX = 1): uses minSpeed
        var distance = Math.abs(destination - current);
        var timeToDestination = relativeX * maxSpeed + (1 - relativeX) * minSpeed;
        speed = (destination - current) / (timeToDestination * 1000);
        moving = true;
    }
    
    public function update(delta:Float):Bool {
        if (!moving) return false;
        
        var nextPos = current + speed * delta * 1000;
        
        // Check if we're about to overshoot
        if ((speed > 0 && nextPos > destination) || 
            (speed < 0 && nextPos < destination)) {
            current = destination;
            moving = false;
            return true;
        }
        
        // Bounds checking
        if (nextPos < 0) {
            current = 0;
            moving = false;
        } else if (nextPos > height) {
            current = height;
            moving = false;
        } else {
            current = nextPos;
        }
        
        return true;
    }
    
    public function getValue():Int {
        // Map current position (height to 0) to MIDI range (0 to 127)
        return Std.int((height - current) / height * 127);
    }
}

// Main sequencer class
class TimeSliderSequencer implements ISequencer implements IControlPanel {
    // Constants
    public static inline var PLAY_AREA_UID:Int = 1;
    public static inline var CC_EVENT_TYPE:Int = 1;
    public static inline var BASE_CC:Int = 20;  // First CC number to use
    
    // Dimensions
    public var areaWidth:Int;
    public var areaHeight:Int;
    
    // Sliders
    private var sliders:Array<TimeSlider>;
    
    // Sequencer state
    private var currentTime:Float;
    private var events:Array<Event>;
    private var dirty:Bool;
    
    private var minSpeed:Float;
    private var maxSpeed:Float;
    
    public function new(width:Int, height:Int, minSpeed:Float, maxSpeed:Float) {
        this.areaWidth = width;
        this.areaHeight = height;
        this.currentTime = 0.0;
        this.events = [];
        this.dirty = true;
        this.minSpeed = minSpeed;
        this.maxSpeed = maxSpeed;
        
        // Create sliders with different channels and CC numbers
        sliders = [
            new TimeSlider(50, 50, 30, height-100, 1, 1, minSpeed, maxSpeed),   // Channel 1, CC 1
            new TimeSlider(150, 50, 30, height-100, 1, 2, minSpeed, maxSpeed),  // Channel 1, CC 2
            new TimeSlider(250, 50, 30, height-100, 1, 3, minSpeed, maxSpeed)   // Channel 1, CC 3
        ];
    }
    
    // ISequencer implementation
    public function advanceTime(delta:Float):Void {
        currentTime += delta;
        
        var changed = false;
        for (slider in sliders) {
            if (slider.update(delta)) {
                changed = true;
            }
        }
        
        if (changed) {
            dirty = true;
        }
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
            for (slider in sliders) {
                if (slider.hit(x, y)) {
                    slider.setDestination(x, y);
                    dirty = true;
                    break;
                }
            }
        }
    }
    
    // Unused IControlPanel methods
    public function mouseDragged(uid:Int, x:Int, y:Int):Void {}
    public function mouseUp(uid:Int, x:Int, y:Int):Void {}
    public function textSubmitted(uid:Int, text:String):Void {}
    public function newValue(uid:Int, value:Float):Void {}
    public function buttonPressed(uid:Int):Void {}
    public function keyPressed(uid:Int, key:String):Void {}
    
    // Helper methods
    public function generateEvents():Void {
        for (slider in sliders) {
            if (slider.moving) {
                events.push(new Event(
                    currentTime,
                    CC_EVENT_TYPE,
                    slider.channel,    // Channel number
                    slider.ccNumber,   // CC number
                    slider.getValue()  // Value
                ));
            }
        }
    }
    
    public function consumeDirty():Bool {
        var wasDirty = dirty;
        dirty = false;
        return wasDirty;
    }
    
    public function getSliders():Array<TimeSlider> {
        return sliders;
    }
} 