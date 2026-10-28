package zewp;

import Math;
import worldofcake.IRandomSource;
import worldofcake.LocalPoint;

class Zewp {
    private static inline var LOOK_AHEAD_STEPS:Int = 8;
    /** Turning speed while blocked, radians per second (π/12 per 60 Hz frame). */
    public static inline var TURN_RATE:Float = 15.707963267948966; // 5π
    /** Each look-ahead probe is this much further along the path in time. */
    static inline var LOOK_AHEAD_STEP_SECONDS:Float = 1.0 / 120.0;
    /** Centre position in Zewp local play-area coordinates. */
    public var position:LocalPoint;
    public var angle:Float;
    public var length:Float;
    public var velocity:Float;
    public var color:Int;
    public var channel:Int;
    public var ccNumber:Int;

    private var cosA:Float;
    private var sinA:Float;
    private var velocityVector:LocalPoint;
    public var dAngle:Float;

    public var lastGlyphPosition:LocalPoint;
    public var inFront:Bool;
    /** Zewps and blocks near this one's look-ahead path (the first `*Count`); reused every step. */
    private var nearby:Array<Zewp> = [];
    private var nearbyCount:Int = 0;
    private var nearbyBlocks:Array<Block> = [];
    private var nearbyBlockCount:Int = 0;

    public function new(x:Float, y:Float, length:Float, velocity:Float, color:Int, channel:Int, ccNumber:Int,
                        random:IRandomSource) {
        this.position = new LocalPoint(x, y);
        this.length = length;
        this.velocity = velocity;
        this.color = color;
        this.channel = channel;
        this.ccNumber = ccNumber;
        this.inFront = false;
        this.lastGlyphPosition = new LocalPoint(x, y);
        this.dAngle = (random.nextFloat() < 0.5) ? TURN_RATE : -TURN_RATE;
        setAngle(0);
    }

    public function setAngle(a:Float):Void {
        angle = a;
        cosA = Math.cos(angle);
        sinA = Math.sin(angle);
        if (velocityVector == null) {
            velocityVector = new LocalPoint(cosA * velocity, sinA * velocity);
        } else {
            velocityVector.x = cosA * velocity;
            velocityVector.y = sinA * velocity;
        }
    }

    public function lookAhead(zewps:Array<Zewp>, blocks:Array<Block>, width:Int, height:Int):Bool {
        var px:Float = position.x + (cosA * length);
        var py:Float = position.y + (sinA * length);
        collectNearby(zewps, blocks, px, py);

        for (i in 0...LOOK_AHEAD_STEPS) {
            if ((velocityVector.x < 0 && px < 5) ||
                (velocityVector.y < 0 && py < 5) ||
                (velocityVector.x > 0 && px > width - 5) ||
                (velocityVector.y > 0 && py > height - 5)) {
                return true;
            }

            for (k in 0...nearbyCount) {
                var z = nearby[k];
                if (z.hitXY(px, py)) {
                    lastGlyphPosition = z.lastGlyphPosition;
                    inFront = true;
                    return true;
                }
            }

            for (k in 0...nearbyBlockCount) {
                var block = nearbyBlocks[k];
                if (block.hitXY(px, py)) {
                    lastGlyphPosition.x = block.bounds.center().x;
                    lastGlyphPosition.y = block.bounds.center().y;
                    inFront = true;
                    return true;
                }
            }

            px += velocityVector.x * LOOK_AHEAD_STEP_SECONDS;
            py += velocityVector.y * LOOK_AHEAD_STEP_SECONDS;
        }

        inFront = false;
        return false;
    }

    /**
        Gather, in their original order, the other zewps and the blocks that any look-ahead
        probe could hit. A glyph lies within sqrt(length² + 4²) of its centre, so a zewp further
        than that from the probes' bounding box cannot be hit; nor can a block that does not
        overlap the box. This keeps the look-ahead from testing every probe against everything,
        without changing which obstacle is found first.
    **/
    function collectNearby(zewps:Array<Zewp>, blocks:Array<Block>, startX:Float, startY:Float):Void {
        var span = (LOOK_AHEAD_STEPS - 1) * LOOK_AHEAD_STEP_SECONDS;
        var endX = startX + velocityVector.x * span, endY = startY + velocityVector.y * span;
        var minX = Math.min(startX, endX), maxX = Math.max(startX, endX);
        var minY = Math.min(startY, endY), maxY = Math.max(startY, endY);
        nearbyCount = 0;
        for (z in zewps) {
            if (z == this) continue;
            var cx = z.position.x, cy = z.position.y;
            var dx = cx < minX ? minX - cx : (cx > maxX ? cx - maxX : 0.0);
            var dy = cy < minY ? minY - cy : (cy > maxY ? cy - maxY : 0.0);
            // A little slack so rounding never drops a zewp that is exactly at the edge.
            if (dx * dx + dy * dy <= z.length * z.length + 16 + 1) nearby[nearbyCount++] = z;
        }
        nearbyBlockCount = 0;
        for (block in blocks) {
            var b = block.bounds;
            if (b.right >= minX - 1 && b.left <= maxX + 1 && b.bottom >= minY - 1 && b.top <= maxY + 1)
                nearbyBlocks[nearbyBlockCount++] = block;
        }
    }

    public function hit(point:LocalPoint):Bool {
        return hitXY(point.x, point.y);
    }

    /** Allocation-free hit test used by the high-rate look-ahead loop. */
    public function hitXY(x:Float, y:Float):Bool {
        var localDx = x - position.x;
        var localDy = y - position.y;
        // Rotate by -angle using the cached cos/sin (setAngle keeps them current).
        var rotX = localDx * cosA + localDy * sinA;
        var rotY = localDy * cosA - localDx * sinA;
        return rotX >= -length && rotX <= length && rotY >= -4 && rotY <= 4;
    }

    /** Move (units/s) or, when blocked, turn (rad/s) for `delta` seconds of real time. */
    public function update(zewps:Array<Zewp>, blocks:Array<Block>, width:Int, height:Int, delta:Float):Void {
        if (lookAhead(zewps, blocks, width, height)) {
            setAngle(angle + dAngle * delta);
        } else {
            position.x += velocityVector.x * delta;
            position.y += velocityVector.y * delta;
        }

        constrainGlyphToArea(width, height);
    }

    /** Keep the complete rotated line glyph inside model-space play-area bounds. */
    public function constrainGlyphToArea(width:Float, height:Float):Void {
        var halfWidth = Math.abs(cosA) * length + 2.0;
        var halfHeight = Math.abs(sinA) * length + 2.0;
        position.x = clampAxis(position.x, halfWidth, width - halfWidth, width * 0.5);
        position.y = clampAxis(position.y, halfHeight, height - halfHeight, height * 0.5);
    }

    private static function clampAxis(value:Float, minimum:Float, maximum:Float, fallback:Float):Float {
        if (minimum > maximum) return fallback;
        if (value < minimum) return minimum;
        if (value > maximum) return maximum;
        return value;
    }
}
