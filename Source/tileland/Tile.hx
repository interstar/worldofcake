package tileland;

import worldofcake.LocalPoint;

class Tile {
    public var type:TileOrientation;
    /** Top-left position in TileLand's local play-area coordinate space. */
    public var position:LocalPoint;
    /** Square edge length in TileLand local play-area units (not a window or panel size). */
    public var size:Float;
    
    public function new(type:TileOrientation, position:LocalPoint, size:Float) {
        this.type = type;
        this.position = position;
        this.size = size;
    }

    
    public function flip():Void {
        type = (type == TileOrientation.A) ? TileOrientation.B : TileOrientation.A;
    }
} 
