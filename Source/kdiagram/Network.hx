package kdiagram;

import worldofcake.LocalPoint;
import worldofcake.IRandomSource;
import worldofcake.SystemRandomSource;

class Network {
    public var nodes:Array<Node>;
    public var radius:Float;
    public var currentWait:Int;
    public var centerX:Float;
    public var centerY:Float;
    private var random:IRandomSource;
    
    /**
        @param nodeCount If `<= 0`, creates an empty graph (for `fromSerialized`).
        @param deadEndRatio Approximate fraction of nodes with **no** outgoing arcs (`0`…`1`).
               Capped so at least one node is not a dead end when `nodeCount > 1`.
               All non-dead-end nodes get **at least one** exit arc.
    **/
    public function new(radius:Float, nodeCount:Int, arcsPerNode:Int, ?deadEndRatio:Float = 0.0,
                        ?random:IRandomSource) {
        this.random = random == null ? new SystemRandomSource() : random;
        this.radius = radius;
        this.nodes = [];
        this.centerX = 0;
        this.centerY = 0;
        this.currentWait = 0;
        if (nodeCount <= 0) {
            return;
        }

        for (i in 0...nodeCount) {
            var angle = this.random.nextFloat() * Math.PI * 2;
            var nodeRadius = (0.2 + 0.6 * this.random.nextFloat()) * radius;
            nodes.push(new Node(angle, nodeRadius));
        }

        var r = deadEndRatio;
        if (r < 0) {
            r = 0;
        }
        if (r > 1) {
            r = 1;
        }
        var targetDead = Math.round(nodeCount * r);
        if (nodeCount > 1 && targetDead > nodeCount - 1) {
            targetDead = nodeCount - 1;
        }
        if (targetDead < 0) {
            targetDead = 0;
        }

        var order = [for (j in 0...nodeCount) j];
        for (i in 0...nodeCount) {
            var k = i + Math.floor(this.random.nextFloat() * (nodeCount - i));
            var tmp = order[i];
            order[i] = order[k];
            order[k] = tmp;
        }
        var deadEnd = [for (_ in 0...nodeCount) false];
        for (k in 0...targetDead) {
            deadEnd[order[k]] = true;
        }

        for (i in 0...nodeCount) {
            if (deadEnd[i]) {
                continue;
            }
            var node = nodes[i];
            var maxArcs = arcsPerNode < 1 ? 1 : arcsPerNode;
            var arcCount = 1 + Math.floor(this.random.nextFloat() * maxArcs);
            for (_ in 0...arcCount) {
                var dest = randomOutgoingDest(nodeCount, i);
                if (dest != i) {
                    node.addArc(dest, 1 + Math.floor(this.random.nextFloat() * 10), 1 + Math.floor(this.random.nextFloat() * 10));
                }
            }
            if (node.arcs.length == 0 && nodeCount > 1) {
                var d = randomOutgoingDest(nodeCount, i);
                if (d != i) {
                    node.addArc(d, 1 + Math.floor(this.random.nextFloat() * 10), 1 + Math.floor(this.random.nextFloat() * 10));
                }
            }
        }
    }

    function randomOutgoingDest(nodeCount:Int, exclude:Int):Int {
        var d = exclude;
        var guard = 0;
        while (d == exclude && guard++ < 200) {
            d = Math.floor(random.nextFloat() * nodeCount);
        }
        return d;
    }
    
    public function nextFrom(fromIndex:Int):Int {
        var node = nodes[fromIndex];
        var dest = node.chooseNext(random);
        if (dest != -1) {
            node.updateCounter(dest);
            currentWait = node.currentWait;
        }
        return dest;
    }
    
    public function selected(point:LocalPoint):Int {
        for (i in 0...nodes.length) {
            if (nodes[i].hit(point)) return i;
        }
        return -1;
    }
    
    public function rotate(deltaAngle:Float):Void {
        for (node in nodes) {
            node.rotate(deltaAngle);
        }
    }
    
    public function getNode(index:Int):Node {
        return nodes[index];
    }
    
    public function getNodeCount():Int {
        return nodes.length;
    }

    /** Rebuild topology from patch JSON (Rack / hosts). */
    public static function fromSerialized(radius:Float, nodeEntries:Array<Dynamic>, ?random:IRandomSource):Network {
        var net = new Network(radius, 0, 0, 0, random);
        if (nodeEntries == null) {
            return net;
        }
        for (e in nodeEntries) {
            var ang = Std.parseFloat(Std.string(Reflect.field(e, "angle")));
            var d = Std.parseFloat(Std.string(Reflect.field(e, "d")));
            var node = new Node(ang, d);
            var arcs:Array<Dynamic> = Reflect.field(e, "arcs");
            if (arcs != null) {
                for (a in arcs) {
                    var dest = Std.int(Reflect.field(a, "dest"));
                    var l1 = Std.int(Reflect.field(a, "l1"));
                    var l2 = Std.int(Reflect.field(a, "l2"));
                    node.addArc(dest, l1, l2);
                    var last = node.arcs[node.arcs.length - 1];
                    if (Reflect.hasField(a, "count")) {
                        last.count = Std.int(Reflect.field(a, "count"));
                    }
                }
            }
            net.nodes.push(node);
        }
        return net;
    }
} 
