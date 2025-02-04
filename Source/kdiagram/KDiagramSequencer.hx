package kdiagram;

import worldofcake.ISequencer;
import worldofcake.IControlPanel;
import worldofcake.Event;
import worldofcake.ISequencerControl;
import worldofcake.CoordinateMapper;
import worldofcake.LocalPoint;
import worldofcake.PanelPoint;
import worldofcake.BasePoint;

private class Cursor {
    public var pos:LocalPoint;
    public var target:LocalPoint;
    public var channel:Int;
    public var color:Int;
    public var isMoving:Bool;
    public var currentNode:Int;
    public var cursorSpeed:Float;
    
    public function new(channel:Int, color:Int) {
        this.channel = channel;
        this.color = color;
        this.isMoving = false;
        this.cursorSpeed = 0.2;
        this.pos = new LocalPoint(0, 0);
        this.target = new LocalPoint(0, 0);
    }
}

class KDiagramSequencer implements ISequencerControl {
    // Constants
    public static inline var PLAY_AREA_UID:Int = 1;
    public static inline var CC_EVENT_TYPE:Int = 1;
    public static inline var NOTE_EVENT_TYPE:Int = 0;
    public static inline var SPEED_SLIDER_1_UID:Int = 10;
    public static inline var SPEED_SLIDER_2_UID:Int = 11;
    public static inline var SPEED_SLIDER_3_UID:Int = 12;
    public static inline var CHANNEL_SLIDER_UID:Int = 20;
    
    // Network and cursor state
    private var network:Network;
    private var cursors:Array<Cursor>;
    
    // Sequencer state
    private var currentTime:Float;
    private var events:Array<Event>;
    private var dirty:Bool;
    
    private var selectedCursorIndex:Int = 0;
    
    public function new() {
        this.currentTime = 0.0;
        this.events = [];
        this.dirty = true;
        
        // Create network with -1 to 1 coordinates
        network = new Network(0.9, 12, 4);  // radius, nodeCount, arcsPerNode
        
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
            cursor.pos = new LocalPoint(node.pos.x, node.pos.y);
            
            // Start them moving
            var nextNode = network.nextFrom(cursor.currentNode);
            if (nextNode != -1) {
                cursor.currentNode = nextNode;
                var destNode = network.getNode(nextNode);
                cursor.target = new LocalPoint(destNode.pos.x, destNode.pos.y);
                cursor.isMoving = true;
            }
        }
        
        // Set default speeds
        cursors[0].cursorSpeed = 16.0 * 10;  // Default speed from ui.YAML
        cursors[1].cursorSpeed = 16.0 * 10;
        cursors[2].cursorSpeed = 16.0 * 10;
    }
    
    // ISequencer implementation
    public function advanceTime(delta:Float):Void {
        currentTime += delta;
        
        for (cursor in cursors) {
            if (cursor.isMoving) {
                // Move cursor towards target
                var dx = cursor.target.x - cursor.pos.x;
                var dy = cursor.target.y - cursor.pos.y;
                var distance = Math.sqrt(dx * dx + dy * dy);
                
                if (distance < cursor.cursorSpeed * delta) {
                    // Arrived at target node
                    cursor.pos = cursor.target;
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
                        cursor.target = new LocalPoint(node.pos.x, node.pos.y);
                        cursor.isMoving = true;
                    }
                } else {
                    // Move towards target
                    var moveDistance = cursor.cursorSpeed * delta;
                    var factor = moveDistance / distance;
                    cursor.pos = new LocalPoint(
                        cursor.pos.x + dx * factor,
                        cursor.pos.y + dy * factor
                    );
                }
                
                // Generate CC events for position
                events.push(new Event(
                    currentTime,
                    CC_EVENT_TYPE,
                    cursor.channel,
                    1,  // CC number for X position
                    Std.int((cursor.pos.x * 127))
                ));
                events.push(new Event(
                    currentTime,
                    CC_EVENT_TYPE,
                    cursor.channel,
                    2,  // CC number for Y position
                    Std.int((cursor.pos.y * 127))
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
    public function mouseDown(uid:Int, point:LocalPoint):Void {
        if (uid == PLAY_AREA_UID) {
            var selectedNode = network.selected(point);
            trace('Selected node: ${selectedNode}');
            if (selectedNode != -1) {
                var cursor = cursors[selectedCursorIndex];
                cursor.currentNode = selectedNode;
                var node = network.getNode(selectedNode);
                cursor.pos = new LocalPoint(node.pos.x, node.pos.y);
                
                // Choose next destination and start moving
                var nextNode = network.nextFrom(selectedNode);
                if (nextNode != -1) {
                    cursor.currentNode = nextNode;
                    var destNode = network.getNode(nextNode);
                    cursor.target = new LocalPoint(destNode.pos.x, destNode.pos.y);
                    cursor.isMoving = true;
                }
                dirty = true;
            }
        }
    }
    
    public function mouseDragged(uid:Int, point:LocalPoint):Void {}
    
    public function mouseUp(uid:Int, point:LocalPoint):Void {}
    
    public function textSubmitted(uid:Int, text:String):Void {}
    public function newValue(uid:Int, value:Float):Void {
        switch(uid) {
            case SPEED_SLIDER_1_UID: // Red cursor speed
                cursors[0].cursorSpeed = value * 0.01;  // Changed from value * 10
            case SPEED_SLIDER_2_UID: // Green cursor speed 
                cursors[1].cursorSpeed = value * 0.01;
            case SPEED_SLIDER_3_UID: // Blue cursor speed
                cursors[2].cursorSpeed = value * 0.01;
            case CHANNEL_SLIDER_UID: // MIDI channel
                var channel = Std.int(value);
                for (cursor in cursors) {
                    cursor.channel = channel;
                }
        }
        dirty = true;
    }
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
                    network = new Network(0.9, 12, 4);  // radius, nodeCount, arcsPerNode
                    // Reset cursors to different nodes like in constructor
                    for (i in 0...cursors.length) {
                        var cursor = cursors[i];
                        cursor.currentNode = i * 4;  // Space them out by 4 nodes
                        var node = network.getNode(cursor.currentNode);
                        cursor.pos = new LocalPoint(node.pos.x, node.pos.y);
                        var nextNode = network.nextFrom(cursor.currentNode);
                        if (nextNode != -1) {
                            cursor.currentNode = nextNode;
                            var destNode = network.getNode(nextNode);
                            cursor.target = new LocalPoint(destNode.pos.x, destNode.pos.y);
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
            // Rotate current cursor position around origin (0,0)
            var cos = Math.cos(deltaAngle);
            var sin = Math.sin(deltaAngle);
            var newX = cursor.pos.x * cos - cursor.pos.y * sin;
            var newY = cursor.pos.x * sin + cursor.pos.y * cos;
            cursor.pos = new LocalPoint(newX, newY);
            
            // Rotate target position if we're moving
            if (cursor.isMoving) {
                newX = cursor.target.x * cos - cursor.target.y * sin;
                newY = cursor.target.x * sin + cursor.target.y * cos;
                cursor.target = new LocalPoint(newX, newY);
            }
        }
    }
    
    public function getSelectedCursorIndex():Int {
        return selectedCursorIndex;
    }
    
    public function makePlayAreaMapper(controlID:Int, panelXMin:Float, panelYMin:Float, 
                                     panelXMax:Float, panelYMax:Float):CoordinateMapper {
        if (controlID == PLAY_AREA_UID) {
            return new CoordinateMapper(
                new BasePoint(panelXMin, panelYMin),  // Space 1 min (panel)
                new BasePoint(panelXMax, panelYMax),  // Space 1 max (panel)
                new BasePoint(-1.0, -1.0),           // Space 2 min (local)
                new BasePoint(1.0, 1.0)              // Space 2 max (local)
            );
        }
        return null;
    }
} 