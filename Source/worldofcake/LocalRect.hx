package worldofcake;

class LocalRect {
    public var left:Float;
    public var right:Float;
    public var top:Float;
    public var bottom:Float;
    private var cachedTopLeft:LocalPoint;
    private var cachedBottomRight:LocalPoint;
    private var cachedCenter:LocalPoint;

    public function new(left:Float, top:Float, right:Float, bottom:Float) {
        this.left = left;
        this.right = right;
        this.top = top;
        this.bottom = bottom;
        updateCachedPoints();
    }

    private function updateCachedPoints():Void {
        this.cachedTopLeft = new LocalPoint(left, top);
        this.cachedBottomRight = new LocalPoint(right, bottom);
        this.cachedCenter = new LocalPoint(
            left + width()/2,
            top + height()/2
        );
    }

    public function translate(d:LocalPoint):Void {
        this.left += d.x;
        this.right += d.x;
        this.top += d.y;
        this.bottom += d.y;
        updateCachedPoints();
    }
    
    public function moveTo(newCenter:LocalPoint):Void {
        var w2 = width()/2;
        var h2 = height()/2;
        this.left = newCenter.x - w2;
        this.right = newCenter.x + w2;
        this.top = newCenter.y - h2;
        this.bottom = newCenter.y + h2;
        updateCachedPoints();
    }

    // Factory methods
    public static function fromCenter(center:LocalPoint, width:Float, height:Float):LocalRect {
        var halfWidth = width / 2;
        var halfHeight = height / 2;
        return new LocalRect(
            center.x - halfWidth,
            center.y - halfHeight,
            center.x + halfWidth,
            center.y + halfHeight
        );
    }

    public static function fromTopLeft(topLeft:LocalPoint, width:Float, height:Float):LocalRect {
        return new LocalRect(
            topLeft.x,
            topLeft.y,
            topLeft.x + width,
            topLeft.y + height
        );
    }

    // Accessors
    public function topLeft():LocalPoint {
        return cachedTopLeft;
    }

    public function bottomRight():LocalPoint {
        return cachedBottomRight;
    }

    public function width():Float {
        return right - left;
    }

    public function height():Float {
        return bottom - top;
    }

    public function center():LocalPoint {
        return cachedCenter;
    }

    // Utility methods
    public function contains(point:LocalPoint):Bool {
        return point.x >= left && point.x <= right &&
               point.y >= top && point.y <= bottom;
    }

    public function intersects(other:LocalRect):Bool {
        return !(other.left > right || 
                other.right < left || 
                other.top > bottom ||
                other.bottom < top);
    }

    public function toString():String {
        return 'LocalRect(L:${left} T:${top} R:${right} B:${bottom})';
    }
} 