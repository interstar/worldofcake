package kdiagram;

class Node {
    public var x:Float;
    public var y:Float;
    public var angle:Float;
    public var radius:Float;
    public var currentWait:Int;
    public var arcs:Array<Arc>;
    
    private var centerX:Float;
    private var centerY:Float;
    
    public function new(angle:Float, radius:Float, centerX:Float, centerY:Float) {
        this.angle = angle;
        this.radius = radius;
        this.centerX = centerX;
        this.centerY = centerY;
        this.currentWait = 0;
        this.arcs = [];
        updatePosition();
    }
    
    public function updatePosition():Void {
        // Convert polar to cartesian, relative to center
        x = centerX + Math.cos(angle) * radius;
        y = centerY + Math.sin(angle) * radius;
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
    
    public function hit(px:Float, py:Float):Bool {
        var dx = Math.abs(x - px);
        var dy = Math.abs(y - py);
        return (dx < 10 && dy < 10);  // 20x20 hit area
    }
    
    public function rotate(deltaAngle:Float):Void {
        angle += deltaAngle;
        updatePosition();
    }
} 