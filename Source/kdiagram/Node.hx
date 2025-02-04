package kdiagram;

import worldofcake.LocalPoint;

class Node {
    public var pos:LocalPoint;
    public var angle:Float;
    public var distanceFromCenter:Float;  // Renamed from radius
    public var currentWait:Int;
    public var arcs:Array<Arc>;
    public static inline var HIT_RADIUS:Float = 0.04;  // In local coordinates (-1 to 1)
    
    public function new(angle:Float, distanceFromCenter:Float) {
        this.angle = angle;
        this.distanceFromCenter = distanceFromCenter;  // Renamed
        this.pos = new LocalPoint(0, 0);
        this.currentWait = 0;
        this.arcs = [];
        updatePosition();
    }
    
    public function updatePosition():Void {
        // Simple polar to cartesian, origin is (0,0)
        pos = new LocalPoint(
            Math.cos(angle) * distanceFromCenter,  // Using new name
            Math.sin(angle) * distanceFromCenter
        );
    }
    
    public function addArc(destination:Int, length1:Int, length2:Int):Void {
        arcs.push(new Arc(destination, length1, length2));
    }
    
    public function chooseNext():Int {
        if (arcs.length == 0) return -1;
        
        // Calculate inverse probabilities based on visit counts
        var total = 0;
        for (arc in arcs) total += arc.count;
        
        var inverts = [for (arc in arcs) total - arc.count];
        var tot2 = total;
        
        // Choose based on inverse probabilities
        var find = Math.floor(Math.random() * tot2);
        var tracker = 0;
        
        for (i in 0...arcs.length) {
            if (find < tracker + inverts[i]) {
                currentWait = arcs[i].length1;
                return arcs[i].destination;
            }
            tracker += inverts[i];
        }
        
        // Default to last arc if we get here
        var lastArc = arcs[arcs.length - 1];
        currentWait = lastArc.length1;
        return lastArc.destination;
    }
    
    public function updateCounter(destination:Int):Void {
        for (arc in arcs) {
            if (arc.destination == destination) {
                arc.count++;
                return;
            }
        }
    }
    
    public function hit(point:LocalPoint):Bool {
        var dx = pos.x - point.x;
        var dy = pos.y - point.y;
        var distance = Math.sqrt(dx * dx + dy * dy);
        
        trace('Testing node at (${pos.x},${pos.y}) against click at (${point.x},${point.y})');
        trace('  Distance: ${distance}, Hit radius: ${HIT_RADIUS}');
        var hit = (distance < HIT_RADIUS);
        trace('  Hit: ${hit}');
        return hit;
    }
    
    public function rotate(deltaAngle:Float):Void {
        angle += deltaAngle;
        updatePosition();
    }
} 