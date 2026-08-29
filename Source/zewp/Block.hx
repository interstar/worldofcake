package zewp;

import worldofcake.LocalPoint;
import worldofcake.LocalRect;

class Block {
    /** Rectangle in Zewp local play-area coordinates. */
    public var bounds:LocalRect;
    public var color:Int;
    
    public function new(x:Float, y:Float, width:Float, height:Float, color:Int) {
        this.bounds = LocalRect.fromCenter(new LocalPoint(x, y), width, height);
        this.color = color;
    }
    
    public function hit(point:LocalPoint):Bool {
        return hitXY(point.x, point.y);
    }

    /** Allocation-free hit test used by Zewp look-ahead. */
    public function hitXY(x:Float, y:Float):Bool {
        return x >= bounds.left && x <= bounds.right && y >= bounds.top && y <= bounds.bottom;
    }
}
