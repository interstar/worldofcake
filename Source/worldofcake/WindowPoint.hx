package worldofcake;

class WindowPoint extends BasePoint {
    public function new(x:Float, y:Float) {
        super(x, y);
    }
    
    public static function fromMap(map:{x:Float, y:Float}):WindowPoint {
        return new WindowPoint(map.x, map.y);
    }
} 