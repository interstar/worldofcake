package tileland;

class Tile {
    public var type:Int;  // 1 or 2 for the two orientations
    public var x:Float;
    public var y:Float;
    public var size:Float;
    
    public function new(type:Int, x:Float, y:Float, size:Float) {
        this.type = type;
        this.x = x;
        this.y = y;
        this.size = size;
    }
    
    public function flip():Void {
        type = (type == 1) ? 2 : 1;
    }
} 