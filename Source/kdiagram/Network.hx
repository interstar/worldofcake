package kdiagram;

class Network {
    public var nodes:Array<Node>;
    public var radius:Float;
    public var currentWait:Int;
    public var centerX:Float;
    public var centerY:Float;
    
    public function new(areaWidth:Float, areaHeight:Float, networkRadius:Float, nodeCount:Int, arcsPerNode:Int) {
        this.centerX = areaWidth / 2;
        this.centerY = areaHeight / 2;
        this.radius = networkRadius;
        this.nodes = [];
        
        // Create nodes
        for (i in 0...nodeCount) {
            var angle = Math.random() * Math.PI * 2;
            // Radius varies between 20% and 80% of network radius
            var nodeRadius = (0.2 + 0.6 * Math.random()) * radius;
            var node = new Node(angle, nodeRadius, centerX, centerY);
            
            // Add random arcs
            var arcCount = Math.floor(Math.random() * arcsPerNode);
            for (j in 0...arcCount) {
                var dest = i;
                while (dest == i) {
                    dest = Math.floor(Math.random() * nodeCount);
                }
                // Random lengths between 1 and 10
                node.addArc(dest, 1 + Math.floor(Math.random() * 10), 
                                1 + Math.floor(Math.random() * 10));
            }
            nodes.push(node);
        }
    }
    
    public function nextFrom(fromIndex:Int):Int {
        var node = nodes[fromIndex];
        var dest = node.chooseNext();
        if (dest != -1) {
            node.updateCounter(dest);
            currentWait = node.currentWait;
        }
        return dest;
    }
    
    public function selected(x:Float, y:Float):Int {
        for (i in 0...nodes.length) {
            if (nodes[i].hit(x, y)) {
                return i;
            }
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
} 