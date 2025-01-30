package kdiagram;

import worldofcake.ISequencer;
import worldofcake.IControlPanel;
import worldofcake.Event;

class Cursor {
    public var x:Float;
    public var y:Float;
    public var targetX:Float;
    public var targetY:Float;
    public var channel:Int;
    public var color:Int;
    public var isMoving:Bool;
    public var currentNode:Int;
    public var cursorSpeed:Float;  // Add speed field
    
    public function new(channel:Int, color:Int) {
        this.channel = channel;
        this.color = color;
        this.isMoving = false;
        this.cursorSpeed = 200.0;  // Pixels per second
    }
}

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
    private var cursors:Array<Cursor>;
    
    // Sequencer state
    private var currentTime:Float;
    private var events:Array<Event>;
    private var dirty:Bool;
    
    private var selectedCursorIndex:Int = 0;  // Default to first cursor
    
    public function new(width:Int, height:Int) {
        this.areaWidth = width;
        this.areaHeight = height;
        this.currentTime = 0.0;
        this.events = [];
        this.dirty = true;
        
        // Create network with reasonable defaults
        network = new Network(width, height, height * 0.45, 12, 4);
        
        // Create three cursors with different channels and colors
        cursors = [
            new Cursor(1, 0xFF0000),  // Red cursor - channel 1
            new Cursor(2, 0x00FF00),  // Green cursor - channel 2
            new Cursor(3, 0x0000FF)   // Blue cursor - channel 3
        ];
        
        // Space cursors out more since we have fewer nodes
        for (i in 0...cursors.length) {
            var cursor = cursors[i];
            cursor.currentNode = i * 4;  // Adjust spacing for fewer nodes
            var node = network.getNode(cursor.currentNode);
            cursor.x = node.x;
            cursor.y = node.y;
            
            // Start them moving
            var nextNode = network.nextFrom(cursor.currentNode);
            if (nextNode != -1) {
                cursor.currentNode = nextNode;
                var destNode = network.getNode(nextNode);
                cursor.targetX = destNode.x;
                cursor.targetY = destNode.y;
                cursor.isMoving = true;
            }
        }
    }
    
    // ISequencer implementation
    public function advanceTime(delta:Float):Void {
        currentTime += delta;
        
        for (cursor in cursors) {
            if (cursor.isMoving) {
                // Move cursor towards target
                var dx = cursor.targetX - cursor.x;
                var dy = cursor.targetY - cursor.y;
                var distance = Math.sqrt(dx * dx + dy * dy);
                
                if (distance < cursor.cursorSpeed * delta) {
                    // Arrived at target node
                    cursor.x = cursor.targetX;
                    cursor.y = cursor.targetY;
                    cursor.isMoving = false;
                    
                    // Generate Note-On event for arrival
                    events.push(new Event(
                        currentTime,
                        NOTE_EVENT_TYPE,
                        cursor.channel,
                        60 + cursor.currentNode,  // Note number based on node
                        100  // Velocity
                    ));
                    
                    // Choose next node
                    var nextNode = network.nextFrom(cursor.currentNode);
                    if (nextNode != -1) {
                        cursor.currentNode = nextNode;
                        var node = network.getNode(cursor.currentNode);
                        cursor.targetX = node.x;
                        cursor.targetY = node.y;
                        cursor.isMoving = true;
                    }
                } else {
                    // Move towards target
                    var moveDistance = cursor.cursorSpeed * delta;
                    var factor = moveDistance / distance;
                    cursor.x += dx * factor;
                    cursor.y += dy * factor;
                }
                
                // Generate CC events for position
                events.push(new Event(
                    currentTime,
                    CC_EVENT_TYPE,
                    cursor.channel,
                    1,  // CC number for X position
                    Std.int((cursor.x / areaWidth) * 127)
                ));
                events.push(new Event(
                    currentTime,
                    CC_EVENT_TYPE,
                    cursor.channel,
                    2,  // CC number for Y position
                    Std.int((cursor.y / areaHeight) * 127)
                ));
            }
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
            var selectedNode = network.selected(x, y);
            if (selectedNode != -1) {
                var cursor = cursors[selectedCursorIndex];
                cursor.currentNode = selectedNode;
                var node = network.getNode(selectedNode);
                cursor.x = node.x;
                cursor.y = node.y;
                
                // Choose next destination and start moving
                var nextNode = network.nextFrom(selectedNode);
                if (nextNode != -1) {
                    cursor.currentNode = nextNode;
                    var destNode = network.getNode(nextNode);
                    cursor.targetX = destNode.x;
                    cursor.targetY = destNode.y;
                    cursor.isMoving = true;
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
        // We're already generating events in advanceTime()
        // This method is called after drawing, but we don't need
        // to generate additional events here
    }
    
    public function consumeDirty():Bool {
        var wasDirty = dirty;
        dirty = false;
        return wasDirty;
    }
    
    public function getNetwork():Network {
        return network;
    }
    
    public function getCursors():Array<Cursor> {
        return cursors;
    }
    
    // Add to KDiagramSequencer class
    public function keyPressed(uid:Int, key:String):Void {
        if (uid == PLAY_AREA_UID) {
            switch (key) {
                case "1", "2", "3":
                    selectedCursorIndex = Std.parseInt(key) - 1;
                    dirty = true;
                
                case " ":  // Space - recreate network
                    network = new Network(areaWidth, areaHeight, areaHeight * 0.45, 12, 4);
                    // Reset cursors to different nodes like in constructor
                    for (i in 0...cursors.length) {
                        var cursor = cursors[i];
                        cursor.currentNode = i * 4;  // Space them out by 4 nodes
                        var node = network.getNode(cursor.currentNode);
                        cursor.x = node.x;
                        cursor.y = node.y;
                        var nextNode = network.nextFrom(cursor.currentNode);
                        if (nextNode != -1) {
                            cursor.currentNode = nextNode;
                            var destNode = network.getNode(nextNode);
                            cursor.targetX = destNode.x;
                            cursor.targetY = destNode.y;
                            cursor.isMoving = true;
                        }
                    }
                    dirty = true;
                
                case "[":  // Rotate network counter-clockwise
                    network.rotate(-0.1);
                    rotateCursors(-0.1);
                    dirty = true;
                
                case "]":  // Rotate network clockwise
                    network.rotate(0.1);
                    rotateCursors(0.1);
                    dirty = true;
            }
        }
    }
    
    private function rotateCursors(deltaAngle:Float):Void {
        for (cursor in cursors) {
            // Rotate current cursor position
            var dx = cursor.x - network.centerX;
            var dy = cursor.y - network.centerY;
            var cos = Math.cos(deltaAngle);
            var sin = Math.sin(deltaAngle);
            cursor.x = network.centerX + (dx * cos - dy * sin);
            cursor.y = network.centerY + (dx * sin + dy * cos);
            
            // Rotate target position if we're moving
            if (cursor.isMoving) {
                dx = cursor.targetX - network.centerX;
                dy = cursor.targetY - network.centerY;
                cursor.targetX = network.centerX + (dx * cos - dy * sin);
                cursor.targetY = network.centerY + (dx * sin + dy * cos);
            }
        }
    }
    
    public function getSelectedCursorIndex():Int {
        return selectedCursorIndex;
    }
} 