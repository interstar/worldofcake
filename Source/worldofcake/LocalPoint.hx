package worldofcake;

class LocalPoint extends BasePoint {
    public function new(x:Float, y:Float) {
        super(x, y);
    }
    
    public static function fromMap(map:{x:Float, y:Float}):LocalPoint {
        return new LocalPoint(map.x, map.y);
    }
} 