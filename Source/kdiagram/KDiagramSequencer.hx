package kdiagram;

import generated.kdiagram.KDiagramControlIdsGenerated;

import haxe.Json;
import worldofcake.Event;
import worldofcake.ISequencerControl;
import worldofcake.SequencerCore;
import worldofcake.CoordinateMapper;
import worldofcake.LocalPoint;
import worldofcake.PanelPoint;
import worldofcake.BasePoint;
import worldofcake.IRandomSource;
import worldofcake.NoteCalculator;
import worldofcake.SystemRandomSource;

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

class KDiagramSequencer extends SequencerCore implements ISequencerControl {
    // Constants
    public static inline var PLAY_AREA_UID:Int = KDiagramControlIdsGenerated.PLAYAREA;
    public static inline var CURSOR_SELECT_UID:Int = KDiagramControlIdsGenerated.SELECTCURSOR;
    public static inline var SCALE_SELECT_UID:Int = KDiagramControlIdsGenerated.SCALESELECT;
    public static inline var CC_EVENT_TYPE:Int = 1;
    public static inline var NOTE_EVENT_TYPE:Int = 0;
    public static inline var SPEED_UID_BASE:Int = KDiagramControlIdsGenerated.REDSPEED;
    public static inline var SPEED_UID_COUNT:Int = 3;
    public static inline var SPEED_SLIDER_1_UID:Int = SPEED_UID_BASE;
    public static inline var SPEED_SLIDER_2_UID:Int = SPEED_UID_BASE + 1;
    public static inline var SPEED_SLIDER_3_UID:Int = SPEED_UID_BASE + 2;
    public static inline var CHANNEL_SLIDER_UID:Int = KDiagramControlIdsGenerated.CHANNEL;
    public static inline var RESET_UID:Int = KDiagramControlIdsGenerated.RESET;
    public static inline var PAUSE_UID:Int = KDiagramControlIdsGenerated.PAUSE;
    public static inline var ROTATE_LEFT_UID:Int = KDiagramControlIdsGenerated.ROTATE_LEFT;
    public static inline var ROTATE_RIGHT_UID:Int = KDiagramControlIdsGenerated.ROTATE_RIGHT;

    public static inline function speedUid(index:Int):Int {
        return SPEED_UID_BASE + index;
    }

    public static inline function speedIndexForUid(uid:Int):Int {
        return uid - SPEED_UID_BASE;
    }

    public static inline function isSpeedUid(uid:Int):Bool {
        return uid >= SPEED_UID_BASE && uid < SPEED_UID_BASE + SPEED_UID_COUNT;
    }
    /** Random graph size for `resetNetwork`. */
    public static inline var NETWORK_NODE_COUNT:Int = 12;
    /** ~one leaf with no outgoing arcs; all other nodes get ≥1 exit. */
    public static inline var NETWORK_DEAD_END_RATIO:Float = 1.0 / 12.0;
    private static var SCALE_NAMES:Array<String> = ["chromatic", "major", "minor", "harmonic_minor", "melodic_minor", "minor_blues"];
    
    // Network and cursor state
    private var network:Network;
    private var cursors:Array<Cursor>;
    private var noteCalc:NoteCalculator;
    
    private var selectedCursorIndex:Int = 0;
    private var random:IRandomSource;
    
    public function new(?random:IRandomSource) {
        this.random = random == null ? new SystemRandomSource() : random;
        super(true);
        noteCalc = new NoteCalculator(2.0);
        
        selectedCursorIndex = 0;
        cursors = [
            new Cursor(1, 0xFF0000),  // Red cursor - channel 1
            new Cursor(2, 0x00FF00),  // Green cursor - channel 2
            new Cursor(3, 0x0000FF)   // Blue cursor - channel 3
        ];
        resetNetwork();
    }
    
    // ISequencer implementation
    public function reset():Void {
        resetTransport();
        resetNetwork();
    }

    override function advanceModel(delta:Float):Bool {
        var startTime = currentTime - delta;
        
        for (cursor in cursors) {
            var remaining = delta;
            var elapsed = 0.0;
            var transitions = 0;
            while (cursor.isMoving && remaining > 0 && transitions < 100000) {
                var dx = cursor.target.x - cursor.pos.x;
                var dy = cursor.target.y - cursor.pos.y;
                var distance = Math.sqrt(dx * dx + dy * dy);
                if (!Math.isFinite(cursor.cursorSpeed) || cursor.cursorSpeed <= 0) break;
                var travelTime = distance / cursor.cursorSpeed;
                if (travelTime <= remaining) {
                    cursor.pos = cursor.target;
                    elapsed += travelTime;
                    remaining -= travelTime;
                    events.push(new Event(
                        startTime + elapsed,
                        NOTE_EVENT_TYPE,
                        cursor.channel,
                        noteForLocalY(cursor.pos.y),
                        100
                    ));
                    var nextNode = network.nextFrom(cursor.currentNode);
                    if (nextNode != -1) {
                        cursor.currentNode = nextNode;
                        var node = network.getNode(cursor.currentNode);
                        cursor.target = new LocalPoint(node.pos.x, node.pos.y);
                        cursor.isMoving = true;
                    } else {
                        cursor.isMoving = false;
                    }
                    transitions++;
                } else {
                    var moveDistance = cursor.cursorSpeed * remaining;
                    var factor = moveDistance / distance;
                    cursor.pos = new LocalPoint(
                        cursor.pos.x + dx * factor,
                        cursor.pos.y + dy * factor
                    );
                    elapsed += remaining;
                    remaining = 0;
                }
            }
            if (cursor.isMoving || elapsed > 0) {
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
        
        return true;
    }
    
    public function peekNextEventType():Int {
        return events.length == 0 ? -1 : events[0].type;
    }

    public function peekNextEventTimestamp():Float {
        return events.length == 0 ? 0.0 : events[0].timestamp;
    }

    public function peekNextEventData1():Int {
        return events.length == 0 ? 0 : events[0].data1;
    }

    public function peekNextEventData2():Int {
        return events.length == 0 ? 0 : events[0].data2;
    }

    public function peekNextEventData3():Int {
        return events.length == 0 ? 0 : events[0].data3;
    }

    public function popNextEvent():Void {
        if (events.length > 0) {
            events.shift();
        }
    }

    public function exportStateJson():String {
        var nodeParts:Array<Dynamic> = [];
        if (network != null) {
            for (n in network.nodes) {
                var arcParts:Array<Dynamic> = [];
                for (a in n.arcs) {
                    arcParts.push({
                        dest: a.destination,
                        l1: a.length1,
                        l2: a.length2,
                        count: a.count
                    });
                }
                nodeParts.push({
                    angle: n.angle,
                    d: n.distanceFromCenter,
                    arcs: arcParts
                });
            }
        }
        var curParts:Array<Dynamic> = [];
        for (c in cursors) {
            curParts.push({
                channel: c.channel,
                color: c.color,
                pos: {x: c.pos.x, y: c.pos.y},
                target: {x: c.target.x, y: c.target.y},
                isMoving: c.isMoving,
                currentNode: c.currentNode,
                cursorSpeed: c.cursorSpeed
            });
        }
        var out = new StringBuf();
        out.add('{"v":2,"kind":"kdiagram","currentTime":'); out.add(currentTime);
        out.add(',"paused":'); out.add(paused ? 'true' : 'false');
        out.add(',"scale":"'); out.add(noteCalc.current); out.add('"');
        out.add(',"selectedCursorIndex":'); out.add(selectedCursorIndex);
        out.add(',"networkRadius":'); out.add(network == null ? 0.9 : network.radius);
        out.add(',"nodes":[');
        for (i in 0...nodeParts.length) { if (i > 0) out.add(','); var n:Dynamic = nodeParts[i]; out.add('{"angle":'); out.add(n.angle); out.add(',"d":'); out.add(n.d); out.add(',"arcs":['); for (j in 0...n.arcs.length) { if (j > 0) out.add(','); var a:Dynamic=n.arcs[j]; out.add('{"dest":'); out.add(a.dest); out.add(',"l1":'); out.add(a.l1); out.add(',"l2":'); out.add(a.l2); out.add(',"count":'); out.add(a.count); out.add('}'); } out.add(']}'); }
        out.add('],"cursors":[');
        for (i in 0...curParts.length) { if (i > 0) out.add(','); var c:Dynamic=curParts[i]; out.add('{"channel":'); out.add(c.channel); out.add(',"color":'); out.add(c.color); out.add(',"pos":{"x":'); out.add(c.pos.x); out.add(',"y":'); out.add(c.pos.y); out.add('},"target":{"x":'); out.add(c.target.x); out.add(',"y":'); out.add(c.target.y); out.add('},"isMoving":'); out.add(c.isMoving ? 'true' : 'false'); out.add(',"currentNode":'); out.add(c.currentNode); out.add(',"cursorSpeed":'); out.add(c.cursorSpeed); out.add('}'); }
        out.add(']}'); return out.toString();
    }

    public function importStateJson(json:String):Void {
        if (json == null || json == "") {
            return;
        }
        try {
            var o:Dynamic = Json.parse(json);
            if (o == null || Reflect.field(o, "kind") != "kdiagram") {
                return;
            }
            var ver = Reflect.field(o, "v");
            if (ver == null || Std.int(ver) < 2) {
                resetNetwork();
                return;
            }
            currentTime = Reflect.hasField(o, "currentTime") ? Std.parseFloat(Std.string(Reflect.field(o, "currentTime"))) : 0;
            paused = Reflect.hasField(o, "paused") && Reflect.field(o, "paused") == true;
            if (Reflect.hasField(o, "scale")) {
                noteCalc.setCurrent(cast Reflect.field(o, "scale"));
            }
            selectedCursorIndex = Reflect.hasField(o, "selectedCursorIndex") ? Std.int(Reflect.field(o, "selectedCursorIndex")) : 0;
            if (selectedCursorIndex < 0) {
                selectedCursorIndex = 0;
            }
            if (selectedCursorIndex > cursors.length - 1) {
                selectedCursorIndex = cursors.length - 1;
            }
            var rad = Reflect.hasField(o, "networkRadius") ? Std.parseFloat(Std.string(Reflect.field(o, "networkRadius"))) : 0.9;
            var nArr:Array<Dynamic> = Reflect.field(o, "nodes");
            network = Network.fromSerialized(rad, nArr, random);
            if (network.getNodeCount() == 0) {
                resetNetwork();
                return;
            }
            events = [];
            var cArr:Array<Dynamic> = Reflect.field(o, "cursors");
            if (cArr != null && cArr.length == cursors.length) {
                for (i in 0...cursors.length) {
                    var cd:Dynamic = cArr[i];
                    var c = cursors[i];
                    c.channel = Reflect.hasField(cd, "channel") ? Std.int(Reflect.field(cd, "channel")) : c.channel;
                    c.color = Reflect.hasField(cd, "color") ? Std.int(Reflect.field(cd, "color")) : c.color;
                    var p:Dynamic = Reflect.field(cd, "pos");
                    var t:Dynamic = Reflect.field(cd, "target");
                    if (p != null) {
                        c.pos = new LocalPoint(
                            Std.parseFloat(Std.string(Reflect.field(p, "x"))),
                            Std.parseFloat(Std.string(Reflect.field(p, "y")))
                        );
                    }
                    if (t != null) {
                        c.target = new LocalPoint(
                            Std.parseFloat(Std.string(Reflect.field(t, "x"))),
                            Std.parseFloat(Std.string(Reflect.field(t, "y")))
                        );
                    }
                    c.isMoving = Reflect.hasField(cd, "isMoving") && Reflect.field(cd, "isMoving") == true;
                    c.currentNode = Reflect.hasField(cd, "currentNode") ? Std.int(Reflect.field(cd, "currentNode")) : 0;
                    c.cursorSpeed = Reflect.hasField(cd, "cursorSpeed") ? Std.parseFloat(Std.string(Reflect.field(cd, "cursorSpeed"))) : 0.2;
                    var nc = network.getNodeCount();
                    if (nc > 0) {
                        if (c.currentNode < 0 || c.currentNode >= nc) {
                            c.currentNode = 0;
                        }
                    }
                }
            }
            dirty = true;
        } catch (_:Dynamic) {
            resetNetwork();
        }
    }

    /** Rack / tests: move cursors and graph together. */
    public function rotateNetwork(deltaAngle:Float):Void {
        if (network == null) {
            return;
        }
        network.rotate(deltaAngle);
        rotateCursors(deltaAngle);
        dirty = true;
    }

    public function setSelectedCursorIndex(idx:Int):Void {
        if (idx >= 0 && idx < cursors.length) {
            selectedCursorIndex = idx;
            dirty = true;
        }
    }

    public function setCursorSpeed(slot:Int, value:Float):Void {
        if (slot >= 0 && slot < cursors.length) {
            cursors[slot].cursorSpeed = value;
            dirty = true;
        }
    }

    public function getCursorSpeed(slot:Int):Float {
        return (slot >= 0 && slot < cursors.length) ? cursors[slot].cursorSpeed : 0.2;
    }

    /** MIDI channel for cursor 0; others use base+1, base+2 (clamped 1–14 base so +2 ≤ 16). */
    public function setBaseMidiChannel(base:Int):Void {
        var b = base;
        if (b < 1) {
            b = 1;
        }
        if (b > 14) {
            b = 14;
        }
        for (i in 0...cursors.length) {
            cursors[i].channel = b + i;
        }
        dirty = true;
    }

    public inline function playAreaMouseDown(lx:Float, ly:Float):Void {
        mouseDown(PLAY_AREA_UID, new LocalPoint(lx, ly));
    }

    public function getCursorCount():Int {
        return cursors.length;
    }

    public function getCursorPosX(i:Int):Float {
        return (i >= 0 && i < cursors.length) ? cursors[i].pos.x : 0;
    }

    public function getCursorPosY(i:Int):Float {
        return (i >= 0 && i < cursors.length) ? cursors[i].pos.y : 0;
    }

    public function getCursorTargetX(i:Int):Float {
        return (i >= 0 && i < cursors.length) ? cursors[i].target.x : 0;
    }

    public function getCursorTargetY(i:Int):Float {
        return (i >= 0 && i < cursors.length) ? cursors[i].target.y : 0;
    }

    public function getCursorColourRgb(i:Int):Int {
        return (i >= 0 && i < cursors.length) ? cursors[i].color : 0xffffff;
    }

    public function getCursorChannel(i:Int):Int {
        return (i >= 0 && i < cursors.length) ? cursors[i].channel : 1;
    }

    public function noteForLocalY(y:Float):Int {
        return noteCalc.transform(1.0 - y);
    }

    public function getScaleName():String {
        return noteCalc.current;
    }

    public function setScale(scaleName:String):Void {
        noteCalc.setCurrent(scaleName);
        dirty = true;
    }

    public function getScaleIndex():Int {
        var index = SCALE_NAMES.indexOf(noteCalc.current);
        return index < 0 ? 0 : index;
    }

    public function getCursorIsMoving(i:Int):Bool {
        return (i >= 0 && i < cursors.length) && cursors[i].isMoving;
    }

    public function getNetworkRadius():Float {
        return network == null ? 0.9 : network.radius;
    }

    public function getNodeCount():Int {
        return network == null ? 0 : network.getNodeCount();
    }

    public function getNodePosX(i:Int):Float {
        if (network == null || i < 0 || i >= network.getNodeCount()) {
            return 0;
        }
        return network.getNode(i).pos.x;
    }

    public function getNodePosY(i:Int):Float {
        if (network == null || i < 0 || i >= network.getNodeCount()) {
            return 0;
        }
        return network.getNode(i).pos.y;
    }

    public function getNodeArcCount(i:Int):Int {
        if (network == null || i < 0 || i >= network.getNodeCount()) {
            return 0;
        }
        return network.getNode(i).arcs.length;
    }

    public function getArcDestination(nodeIdx:Int, arcIdx:Int):Int {
        if (network == null || nodeIdx < 0 || nodeIdx >= network.getNodeCount()) {
            return -1;
        }
        var arcs = network.getNode(nodeIdx).arcs;
        if (arcIdx < 0 || arcIdx >= arcs.length) {
            return -1;
        }
        return arcs[arcIdx].destination;
    }

    public function getBaseMidiChannel():Int {
        return cursors.length > 0 ? cursors[0].channel : 1;
    }
    
    // IControlPanel implementation
    public function mouseDown(uid:Int, point:LocalPoint):Void {
        if (uid == PLAY_AREA_UID) {
            var selectedNode = network.selected(point);
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
        if (isSpeedUid(uid)) {  // Speed sliders
            cursors[speedIndexForUid(uid)].cursorSpeed = value;
        } else if (uid == CHANNEL_SLIDER_UID) {  // Channel slider
            var baseChannel = Math.floor(value);  // Convert to integer
            for (i in 0...cursors.length) {
                cursors[i].channel = baseChannel + i;  // Channels will be baseChannel, baseChannel+1, baseChannel+2
            }
        } else if (uid == CURSOR_SELECT_UID) {
            setSelectedCursorIndex(Std.int(Math.round(value)));
        } else if (uid == SCALE_SELECT_UID) {
            var index = Std.int(Math.max(0, Math.min(SCALE_NAMES.length - 1, Math.round(value))));
            setScale(SCALE_NAMES[index]);
        } else if (uid == PAUSE_UID) {
            if (value > 0.5) pause(); else resume();
        }
        dirty = true;
    }
    public function buttonPressed(uid:Int):Void {
        if (uid == RESET_UID) {
            reset();
        } else if (uid == ROTATE_LEFT_UID) {
            rotateNetwork(-0.1);
        } else if (uid == ROTATE_RIGHT_UID) {
            rotateNetwork(0.1);
        }
    }
    
    // Helper methods
    public function generateEvents():Void {
        // We're already generating events in advanceTime()
        // This method is called after drawing, but we don't need
        // to generate additional events here
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
                    reset();
                
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
    
    private function resetNetwork():Void {
        network = new Network(0.9, NETWORK_NODE_COUNT, 4, NETWORK_DEAD_END_RATIO, random);
        
        // Reset cursors to random positions with default speeds
        for (i in 0...3) {
            var cursor = cursors[i];
            
            // Position at random node and stop any existing movement
            var randomNodeId = Math.floor(random.nextFloat() * network.getNodeCount());
            var node = network.getNode(randomNodeId);
            cursor.currentNode = randomNodeId;
            cursor.pos = new LocalPoint(node.pos.x, node.pos.y);
            cursor.isMoving = false;  // Stop any existing movement
            cursor.target = cursor.pos;  // Reset target to current position
            
            // Choose next destination and start moving
            var nextNode = network.nextFrom(randomNodeId);
            if (nextNode != -1) {
                cursor.currentNode = nextNode;
                var destNode = network.getNode(nextNode);
                cursor.target = new LocalPoint(destNode.pos.x, destNode.pos.y);
                cursor.isMoving = true;
            }
        }
        dirty = true;
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
