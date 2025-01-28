package zewp;

import Math;

class Zewp {
    public var x:Float;
    public var y:Float;
    public var angle:Float;
    public var length:Float;
    public var velocity:Float;
    public var color:Int;
    
    // Cached trig calculations
    private var cosA:Float;
    private var sinA:Float;
    private var dx:Float;
    private var dy:Float;
    
    // Last seen block/zewp position
    public var lastGlyphX:Float;
    public var lastGlyphY:Float;
    public var inFront:Bool;
    
    // Turn rate (PI/12 or -PI/12)
    private var dAngle:Float;
    
    public function new(x:Float, y:Float, length:Float, velocity:Float, color:Int) {
        this.x = x;
        this.y = y;
        this.length = length;
        this.velocity = velocity;
        this.color = color;
        this.inFront = false;
        
        // Randomly choose turn direction
        this.dAngle = (Math.random() < 0.5) ? Math.PI / 12 : -Math.PI / 12;
        
        setAngle(0); // Initialize angle and cached values
    }
    
    public function setAngle(a:Float):Void {
        angle = a;
        cosA = Math.cos(angle);
        sinA = Math.sin(angle);
        dx = cosA * velocity;
        dy = sinA * velocity;
    }
    
    public function lookAhead(zewps:Array<Zewp>, blocks:Array<Block>, width:Int, height:Int):Bool {
        var px:Float = x + (cosA * length);
        var py:Float = y + (sinA * length);
        
        for (i in 0...15) {
            // Check edges
            if ((dx < 0 && px < 5) || 
                (dy < 0 && py < 5) || 
                (dx > 0 && px > width - 5) || 
                (dy > 0 && py > height - 5)) {
                return true;
            }
            
            // Check other zewps
            for (z in zewps) {
                if (z != this && z.hit(px, py)) {
                    lastGlyphX = z.lastGlyphX;
                    lastGlyphY = z.lastGlyphY;
                    inFront = true;
                    return true;
                }
            }
            
            // Check blocks
            for (block in blocks) {
                if (block.hit(px, py)) {
                    lastGlyphX = block.x;
                    lastGlyphY = block.y;
                    inFront = true;
                    return true;
                }
            }
            
            px += dx / 2;
            py += dy / 2;
        }
        
        inFront = false;
        return false;
    }
    
    public function hit(px:Float, py:Float):Bool {
        // Transform point to local coordinates
        var dx = px - x;
        var dy = py - y;
        var rotX = dx * Math.cos(-angle) - dy * Math.sin(-angle);
        var rotY = dx * Math.sin(-angle) + dy * Math.cos(-angle);
        
        // Check if point is in rectangle
        return (rotX >= -length && rotX <= length && 
                rotY >= -4 && rotY <= 4);
    }
    
    public function update(zewps:Array<Zewp>, blocks:Array<Block>, width:Int, height:Int):Void {
        if (lookAhead(zewps, blocks, width, height)) {
            setAngle(angle + dAngle);
        } else {
            x += dx;
            y += dy;
        }
        
        // Wrap around screen
        if (x < 0 || x > width) x = width / 2;
        if (y < 0 || y > height) y = height / 2;
    }
} 