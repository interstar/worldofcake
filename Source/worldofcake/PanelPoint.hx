package worldofcake;

class PanelPoint extends BasePoint {
    public function new(x:Float, y:Float) {
        super(x, y);
    }
    
    public static function fromMap(map:{x:Float, y:Float}):PanelPoint {
        return new PanelPoint(map.x, map.y);
    }
} 