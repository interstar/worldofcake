package kdiagram;

import worldofcake.ISequencer;
import worldofcake.IControlPanel;
import worldofcake.Event;

class KDiagramSequencer implements ISequencer implements IControlPanel {
    // Constants
    public static inline var PLAY_AREA_UID:Int = 1;
    public static inline var CC_EVENT_TYPE:Int = 1;
    public static inline var NOTE_EVENT_TYPE:Int = 0;
    
    // Dimensions
    public var areaWidth:Int;
    public var areaHeight:Int;
    
    // Network and cursor state
    private var network:Network;
    private var currentNode:Int;
    private var cursorX:Float;
    private var cursorY:Float;
    private var targetX:Float;
    private var targetY:Float;
    private var cursorSpeed:Float;
    private var isMoving:Bool;
    
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
        this.cursorSpeed = 200.0; // pixels per second
        
        // Create network with reasonable defaults
        network = new Network(width, height, height * 0.4, 15, 6);
        
        // Start at node 0 and immediately begin moving to next node
        currentNode = 0;
        var startNode = network.getNode(currentNode);
        cursorX = startNode.x;
        cursorY = startNode.y;
        
        // Choose first destination
        var nextNode = network.nextFrom(currentNode);
        if (nextNode != -1) {
            currentNode = nextNode;
            var node = network.getNode(currentNode);
            targetX = node.x;
            targetY = node.y;
            isMoving = true;
        }
    }
    
    // ISequencer implementation
    public function advanceTime(delta:Float):Void {
        currentTime += delta;
        
        if (isMoving) {
            // Move cursor towards target
            var dx = targetX - cursorX;
            var dy = targetY - cursorY;
            var distance = Math.sqrt(dx * dx + dy * dy);
            
            if (distance < cursorSpeed * delta) {
                // Arrived at target node
                cursorX = targetX;
                cursorY = targetY;
                isMoving = false;
                
                // Generate Note-On event for arrival
                events.push(new Event(
                    currentTime,
                    NOTE_EVENT_TYPE,
                    60 + Std.int((cursorY / areaHeight) * 24), // Note number based on Y position
                    100  // Velocity
                ));
                
                // Choose next node
                var nextNode = network.nextFrom(currentNode);
                if (nextNode != -1) {
                    currentNode = nextNode;
                    var node = network.getNode(currentNode);
                    targetX = node.x;
                    targetY = node.y;
                    isMoving = true;
                }
            } else {
                // Move towards target
                var moveDistance = cursorSpeed * delta;
                var factor = moveDistance / distance;
                cursorX += dx * factor;
                cursorY += dy * factor;
            }
            
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
            var selectedNode = network.selected(x, y);
            if (selectedNode != -1) {
                currentNode = selectedNode;
                var node = network.getNode(currentNode);
                cursorX = node.x;
                cursorY = node.y;
                
                // Choose next destination and start moving
                var nextNode = network.nextFrom(currentNode);
                if (nextNode != -1) {
                    currentNode = nextNode;
                    var destNode = network.getNode(currentNode);
                    targetX = destNode.x;
                    targetY = destNode.y;
                    isMoving = true;
                }
                
                dirty = true;
            }
        }
    }
    
    // Unused IControlPanel methods
    public function mouseDragged(uid:Int, x:Int, y:Int):Void {}
    public function mouseUp(uid:Int, x:Int, y:Int):Void {}
    public function textSubmitted(uid:Int, text:String):Void {}
    public function newValue(uid:Int, value:Float):Void {}
    public function buttonPressed(uid:Int):Void {}
    
    // Helper methods
    public function generateEvents():Void {
        // Generate CC events for cursor position
        events.push(new Event(
            currentTime,
            CC_EVENT_TYPE,
            0,  // CC number for X
            Std.int((cursorX / areaWidth) * 127)
        ));
        
        events.push(new Event(
            currentTime,
            CC_EVENT_TYPE,
            1,  // CC number for Y
            Std.int((cursorY / areaHeight) * 127)
        ));
    }
    
    public function consumeDirty():Bool {
        var wasDirty = dirty;
        dirty = false;
        return wasDirty;
    }
    
    public function getNetwork():Network {
        return network;
    }
    
    public function getCursorPosition():{x:Float, y:Float} {
        return {x: cursorX, y: cursorY};
    }
    
    // Add to KDiagramSequencer class
    public function keyPressed(uid:Int, key:String):Void {
        if (uid == PLAY_AREA_UID) {
            switch (key) {
                case " ":  // Space - recreate network
                    network = new Network(areaWidth, areaHeight, areaHeight * 0.4, 15, 6);
                    // Reset cursor to node 0 and start moving
                    currentNode = 0;
                    var startNode = network.getNode(currentNode);
                    cursorX = startNode.x;
                    cursorY = startNode.y;
                    var nextNode = network.nextFrom(currentNode);
                    if (nextNode != -1) {
                        currentNode = nextNode;
                        var node = network.getNode(currentNode);
                        targetX = node.x;
                        targetY = node.y;
                        isMoving = true;
                    }
                    dirty = true;
                
                case "[":  // Rotate network counter-clockwise
                    network.rotate(-0.1);
                    rotateCursor(-0.1);
                    dirty = true;
                
                case "]":  // Rotate network clockwise
                    network.rotate(0.1);
                    rotateCursor(0.1);
                    dirty = true;
            }
        }
    }
    
    private function rotateCursor(deltaAngle:Float):Void {
        // Rotate current cursor position
        var dx = cursorX - network.centerX;
        var dy = cursorY - network.centerY;
        var cos = Math.cos(deltaAngle);
        var sin = Math.sin(deltaAngle);
        cursorX = network.centerX + (dx * cos - dy * sin);
        cursorY = network.centerY + (dx * sin + dy * cos);
        
        // Rotate target position if we're moving
        if (isMoving) {
            dx = targetX - network.centerX;
            dy = targetY - network.centerY;
            targetX = network.centerX + (dx * cos - dy * sin);
            targetY = network.centerY + (dx * sin + dy * cos);
        }
    }
} 