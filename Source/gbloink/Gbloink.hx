package gbloink;

import Math;
import worldofcake.ISequencerControl;
import worldofcake.Event;
import worldofcake.Utils;
import worldofcake.NoteCalculator;
import worldofcake.LocalPoint;
import worldofcake.LocalRect;
import haxe.Json;
import StringTools;
import Reflect;
import worldofcake.IRandomSource;
import worldofcake.SystemRandomSource;

class Ball {
    public static var COUNTER:Int = 0;

    public var pos:LocalPoint;
    public var colour:Int;
    public var id:Int;
    public var velocity:LocalPoint;
    public var rad:Float;
    public var channel:Int;

    public function new(pos:LocalPoint, colour:Int, channel:Int) {
        this.pos = pos;
        this.colour = colour;
        this.id = COUNTER++;
        this.velocity = new LocalPoint(2, 2);
        this.rad = 5;
        this.channel = channel;
    }

    public function writeJson(out:StringBuf):Void {
        out.add('{"x":'); out.add(Std.string(pos.x));
        out.add(',"y":'); out.add(Std.string(pos.y));
        out.add(',"vx":'); out.add(Std.string(velocity.x));
        out.add(',"vy":'); out.add(Std.string(velocity.y));
        out.add(',"rad":'); out.add(Std.string(rad));
        out.add(',"channel":'); out.add(Std.string(channel));
        out.add(',"colour":'); out.add(Std.string(colour)); out.add('}');
    }

    public function toJson():String { var out = new StringBuf(); writeJson(out); return out.toString(); }
}

class Block {
    public var bounds:LocalRect;
    public var colour:Int;

    public function new(pos:LocalPoint, random:IRandomSource) {
        var size = 20 + random.nextFloat() * 50;
        this.bounds = LocalRect.fromCenter(pos, size, size);

        this.colour = Math.floor(random.nextFloat() * 0xFFFFFF);
    }

    public function writeJson(out:StringBuf):Void {
        out.add('{"left":'); out.add(Std.string(bounds.left));
        out.add(',"top":'); out.add(Std.string(bounds.top));
        out.add(',"right":'); out.add(Std.string(bounds.right));
        out.add(',"bottom":'); out.add(Std.string(bounds.bottom));
        out.add(',"colour":'); out.add(Std.string(colour)); out.add('}');
    }

    public function toJson():String { var out = new StringBuf(); writeJson(out); return out.toString(); }

    public static function fromSaved(left:Float, top:Float, right:Float, bottom:Float, colour:Int):Block {
        var b = new Block(
            new LocalPoint((left + right) * 0.5, (top + bottom) * 0.5),
            new SystemRandomSource()
        );
        b.bounds = new LocalRect(left, top, right, bottom);
        b.colour = colour;
        return b;
    }

    public function hit(tx:Float, ty:Float, r:Float):Bool {
        return (tx + r > bounds.left) && (tx - r < bounds.right) && 
               (ty + r > bounds.top)  && (ty - r < bounds.bottom);
    }
}

class Gbloink implements ISequencerControl {
    public static inline var PLAY_AREA_UID:Int = 1;
    /** Optional toolbar (OpenFL, Rack, …): clear blocks / toggle pause. */
    public static inline var BTN_CLEAR_BLOCKS:Int = 20;
    public static inline var BTN_PAUSE_TOGGLE:Int = 21;
    /** Latch 0 = off, 1 = play note on play-area edge bounce (hosts map from param). */
    public static inline var EDGE_NOTES_UID:Int = 22;
    public static inline var SCALE_SELECT_UID:Int = 23;
    private static var SCALE_NAMES:Array<String> = ["chromatic", "major", "minor", "harmonic_minor", "melodic_minor", "minor_blues"];
    /** The legacy OpenFL model advanced nominally once per millisecond. */
    private static inline var LEGACY_TICKS_PER_SECOND:Float = 1000.0;
    /** Applied to default `(2,2)` motion and to `setBallSpeed` targets. */
    private static inline var BALL_SPEED_SCALE:Float = 0.25;

    private var dirty:Bool;
    private var currentTime:Float;
    /** When true, `advanceTime` does not move balls or advance `currentTime`. */
    private var paused:Bool;
    /** When true, bouncing off the play-area border emits the same note events as block hits. */
    private var edgeNotesEnabled:Bool;
    
    private var areaSize:LocalPoint;
    private var random:IRandomSource;
    public var events:Array<Event>;
    public var noteCalc:NoteCalculator;
    public var balls:Array<Ball>;
    public var blocks:Array<Block>;

    public function new(size:LocalPoint, ?random:IRandomSource) {
        this.areaSize = size;
        this.random = random == null ? new SystemRandomSource() : random;
        this.events = [];
        this.noteCalc = new NoteCalculator();
        this.dirty = false;
        this.currentTime = 0;
        this.paused = false;
        this.edgeNotesEnabled = false;

        // Spread across 700×500 local space so all three are easy to see (OpenFL + Rack + future ports).
        initBalls();
        blocks = [];
    }

    private function initBalls():Void {
        balls = [
            new Ball(new LocalPoint(95, 85), 0xFF0000, 1),
            new Ball(new LocalPoint(360, 260), 0x00FF00, 2),
            new Ball(new LocalPoint(605, 400), 0x0000FF, 3)
        ];
        for (b in balls) {
            b.velocity.x *= BALL_SPEED_SCALE * LEGACY_TICKS_PER_SECOND;
            b.velocity.y *= BALL_SPEED_SCALE * LEGACY_TICKS_PER_SECOND;
        }
    }

    ///////////////////////////////////////////////////////////////////////////
    // ISequencer methods
    ///////////////////////////////////////////////////////////////////////////

    public function pause():Void {
        setPaused(true);
    }

    public function resume():Void {
        setPaused(false);
    }

    public function reset():Void {
        blocks = [];
        events = [];
        currentTime = 0;
        paused = false;
        initBalls();
        dirty = true;
    }

    public function advanceTime(delta:Float):Void {
        if (paused || !Math.isFinite(delta) || delta <= 0) {
            return;
        }
        currentTime += delta;
        // Move each ball, check collisions
        for (ball in balls) {
            moveBall(ball, delta);
        }
    }

    public function hasEventBefore(timeLimit:Float):Bool {
        return events.length > 0 && events[0].timestamp <= timeLimit;
    }

    public function getNextEvent():Event {
        return events.shift();
    }

    public function exportStateJson():String {
        var out = new StringBuf();
        out.add('{"v":1,"kind":"gbloink"');
        out.add(',"currentTime":'); out.add(Std.string(currentTime));
        out.add(',"paused":'); out.add(paused ? 'true' : 'false');
        out.add(',"scale":"'); out.add(noteCalc.current); out.add('"');
        out.add(',"balls":[');
        for (i in 0...balls.length) {
            if (i > 0) out.add(',');
            balls[i].writeJson(out);
        }
        out.add('],"blocks":[');
        for (i in 0...blocks.length) {
            if (i > 0) out.add(',');
            blocks[i].writeJson(out);
        }
        out.add('],"edgeNotes":'); out.add(edgeNotesEnabled ? 'true' : 'false');
        out.add('}');
        return out.toString();
    }

    public function importStateJson(json:String):Void {
        events = [];
        if (json == null || StringTools.trim(json) == "") {
            return;
        }
        try {
            var data = Json.parse(json);
            if (Std.isOfType(data, Array)) {
                importBlocksJson(json);
                return;
            }
            var o:Dynamic = data;
            if (!Reflect.hasField(o, "v")) {
                return;
            }
            if (Reflect.field(o, "v") != 1) {
                return;
            }
            if (Reflect.hasField(o, "currentTime")) {
                currentTime = cast Reflect.field(o, "currentTime");
            }
            if (Reflect.hasField(o, "paused")) {
                paused = cast Reflect.field(o, "paused");
            }
            if (Reflect.hasField(o, "edgeNotes")) {
                edgeNotesEnabled = Reflect.field(o, "edgeNotes") == true;
            }
            if (Reflect.hasField(o, "scale")) {
                noteCalc.setCurrent(cast Reflect.field(o, "scale"));
            }

            blocks = [];
            if (Reflect.hasField(o, "blocks")) {
                var barr:Array<Dynamic> = cast Reflect.field(o, "blocks");
                if (barr != null) {
                    for (blk in barr) {
                        var b = Block.fromSaved(
                            cast blk.left,
                            cast blk.top,
                            cast blk.right,
                            cast blk.bottom,
                            cast blk.colour
                        );
                        b.bounds = intersectBlockWithPlayArea(b.bounds);
                        blocks.push(b);
                    }
                }
            }

            balls = [];
            if (Reflect.hasField(o, "balls")) {
                var ballArr:Array<Dynamic> = cast Reflect.field(o, "balls");
                if (ballArr != null && ballArr.length > 0) {
                    for (raw in ballArr) {
                        var col = Reflect.hasField(raw, "colour") ? cast Reflect.field(raw, "colour") : 0xffffff;
                        var ch = Reflect.hasField(raw, "channel") ? cast Reflect.field(raw, "channel") : 1;
                        var b = new Ball(
                            new LocalPoint(cast Reflect.field(raw, "x"), cast Reflect.field(raw, "y")),
                            col,
                            ch
                        );
                        b.velocity = new LocalPoint(
                            cast Reflect.field(raw, "vx"),
                            cast Reflect.field(raw, "vy")
                        );
                        if (Reflect.hasField(raw, "rad")) {
                            b.rad = cast Reflect.field(raw, "rad");
                        }
                        clampBallToPlayArea(b);
                        balls.push(b);
                    }
                }
            }
            if (balls.length == 0) {
                initBalls();
            }
            dirty = true;
        } catch (_:Dynamic) {}
    }

    /** Logical time used for queued `Event` timestamps (e.g. align host schedulers after load). */
    public function getLogicalTime():Float {
        return currentTime;
    }

    /** Current scale id for `NoteCalculator` (e.g. sync host UI after `importStateJson`). */
    public function getScaleName():String {
        return noteCalc.current;
    }

    ///////////////////////////////////////////////////////////////////////////
    // IControlPanel methods
    ///////////////////////////////////////////////////////////////////////////

    // Not used in this example
    public function textSubmitted(uid:Int, text:String):Void {}
    public function mouseDragged(uid:Int, point:LocalPoint):Void {}
    public function mouseUp(uid:Int, point:LocalPoint):Void {}
    public function newValue(uid:Int, value:Float):Void {
        if (uid >= 10 && uid <= 12) {
            setBallSpeed(uid - 10, value);
            dirty = true;
        } else if (uid == EDGE_NOTES_UID) {
            edgeNotesEnabled = value > 0.5;
            dirty = true;
        } else if (uid == SCALE_SELECT_UID) {
            var index = Std.int(Math.max(0, Math.min(SCALE_NAMES.length - 1, Math.round(value))));
            setScale(SCALE_NAMES[index]);
        }
    }
    public function buttonPressed(uid:Int):Void {
        if (uid == BTN_CLEAR_BLOCKS) {
            clearBlocks();
        } else if (uid == BTN_PAUSE_TOGGLE) {
            setPaused(!paused);
        }
    }

    public function isEdgeNotesEnabled():Bool {
        return edgeNotesEnabled;
    }

    public function setEdgeNotesEnabled(v:Bool):Void {
        if (edgeNotesEnabled != v) {
            edgeNotesEnabled = v;
            dirty = true;
        }
    }

    public function isPaused():Bool {
        return paused;
    }

    public function setPaused(p:Bool):Void {
        if (paused == p) {
            return;
        }
        paused = p;
        dirty = true;
    }

    public function clearBlocks():Void {
        blocks = [];
        events = [];
        dirty = true;
    }

    // Main interaction: click to add/remove blocks
    public function mouseDown(uid:Int, point:LocalPoint):Void {
        if (uid == PLAY_AREA_UID) {
            var foundBlock = false;
            for (block in blocks) {
                if (block.hit(point.x, point.y, 0)) {
                    removeBlock(block);
                    foundBlock = true;
                    break;
                }
            }
            if (!foundBlock) {
                addBlock(point.x, point.y);
            }
            dirty = true;
        }
    }

    // Add this to the Gbloink class with the other IControlPanel methods
    public function keyPressed(uid:Int, key:String):Void {
        // For now, just an empty implementation
        // We can add specific keyboard controls for Gbloink later if needed
    }

    ///////////////////////////////////////////////////////////////////////////
    // Public helper methods
    ///////////////////////////////////////////////////////////////////////////

    // The view might want to check if we need redraw
    public function consumeDirty():Bool {
        var wasDirty = dirty;
        dirty = false;
        return wasDirty;
    }

    public function getBalls():Array<Ball> {
        return balls;
    }

    public function getBlocks():Array<Block> {
        return blocks;
    }

    public function setScale(scaleName:String):Void {
        noteCalc.setCurrent(scaleName);
        dirty = true;
    }

    public function getScaleIndex():Int {
        var index = SCALE_NAMES.indexOf(noteCalc.current);
        return index < 0 ? 0 : index;
    }

    /** JSON array of `{ left, top, right, bottom, colour }` for patch save/restore. */
    public function exportBlocksJson():String {
        var parts:Array<Dynamic> = [];
        for (blk in blocks) {
            parts.push({
                left: blk.bounds.left,
                top: blk.bounds.top,
                right: blk.bounds.right,
                bottom: blk.bounds.bottom,
                colour: blk.colour
            });
        }
        return Json.stringify(parts);
    }

    public function importBlocksJson(json:String):Void {
        blocks = [];
        if (json == null || StringTools.trim(json) == "") {
            return;
        }
        try {
            var arr:Array<Dynamic> = Json.parse(json);
            if (arr == null) {
                return;
            }
            for (o in arr) {
                var blk = Block.fromSaved(
                    cast o.left,
                    cast o.top,
                    cast o.right,
                    cast o.bottom,
                    cast o.colour
                );
                blk.bounds = intersectBlockWithPlayArea(blk.bounds);
                blocks.push(blk);
            }
            dirty = true;
        } catch (_:Dynamic) {}
    }

    ///////////////////////////////////////////////////////////////////////////
    // Private utility
    ///////////////////////////////////////////////////////////////////////////

    private function pushEvent(evtType:Int, channel:Int, data2:Int, data3:Int):Void {
        events.push(new Event(currentTime, evtType, channel, data2, data3));
    }

    private function removeBlock(block:Block):Void {
        blocks = blocks.filter(b -> b != block);
    }

    /** Clip block AABB to the play area so physics and all hosts stay inside bounds. */
    private function intersectBlockWithPlayArea(r:LocalRect):LocalRect {
        var l = Math.max(0, r.left);
        var rt = Math.min(areaSize.x, r.right);
        var t = Math.max(0, r.top);
        var b = Math.min(areaSize.y, r.bottom);
        if (rt > l && b > t) {
            return new LocalRect(l, t, rt, b);
        }
        var cx = Math.max(1, Math.min(areaSize.x - 1, (r.left + r.right) * 0.5));
        var cy = Math.max(1, Math.min(areaSize.y - 1, (r.top + r.bottom) * 0.5));
        return new LocalRect(cx - 1, cy - 1, cx + 1, cy + 1);
    }

    private function addBlock(x:Float, y:Float):Void {
        var blk = new Block(new LocalPoint(x, y), random);
        blk.bounds = intersectBlockWithPlayArea(blk.bounds);
        blocks.push(blk);
    }

    private function clampBallToPlayArea(b:Ball):Void {
        var r = Math.max(0.5, b.rad);
        b.rad = r;
        b.pos.x = Math.max(r, Math.min(areaSize.x - r, b.pos.x));
        b.pos.y = Math.max(r, Math.min(areaSize.y - r, b.pos.y));
    }

    private function setBallSpeed(ballIndex:Int, speed:Float):Void {
        if (ballIndex < 0 || ballIndex >= balls.length) {
            return;
        }

        speed *= BALL_SPEED_SCALE * LEGACY_TICKS_PER_SECOND;

        var ball = balls[ballIndex];
        var vx = ball.velocity.x;
        var vy = ball.velocity.y;
        var magnitude = Math.sqrt(vx * vx + vy * vy);

        if (magnitude == 0) {
            var diagonal = speed / Math.sqrt(2);
            ball.velocity = new LocalPoint(diagonal, diagonal);
            return;
        }

        var scale = speed / magnitude;
        ball.velocity = new LocalPoint(vx * scale, vy * scale);
    }

    private function moveBall(ball:Ball, delta:Float):Void {
        var nextX = ball.pos.x + ball.velocity.x * delta;
        var nextY = ball.pos.y + ball.velocity.y * delta;

        if (nextX < ball.rad) {
            nextX = ball.rad;
            ball.velocity.x = -ball.velocity.x;
            if (edgeNotesEnabled) {
                pushEvent(0, ball.channel, noteCalc.transform(nextY), 100);
            }
        } else if (nextX > areaSize.x - ball.rad) {
            nextX = areaSize.x - ball.rad;
            ball.velocity.x = -ball.velocity.x;
            if (edgeNotesEnabled) {
                pushEvent(0, ball.channel, noteCalc.transform(nextY), 100);
            }
        }

        if (nextY < ball.rad) {
            nextY = ball.rad;
            ball.velocity.y = -ball.velocity.y;
            if (edgeNotesEnabled) {
                pushEvent(0, ball.channel, noteCalc.transform(nextY), 100);
            }
        } else if (nextY > areaSize.y - ball.rad) {
            nextY = areaSize.y - ball.rad;
            ball.velocity.y = -ball.velocity.y;
            if (edgeNotesEnabled) {
                pushEvent(0, ball.channel, noteCalc.transform(nextY), 100);
            }
        }

        for (other in balls) {
            if (other == ball) continue;

            var distX = other.pos.x - nextX;
            var distY = other.pos.y - nextY;
            var distance = Math.sqrt(distX * distX + distY * distY);
            var minDistance = ball.rad + other.rad;
            if (distance < minDistance) {
                if (distance == 0) {
                    distX = ball.velocity.x != 0 ? -ball.velocity.x : 1;
                    distY = ball.velocity.y != 0 ? -ball.velocity.y : 0;
                    distance = Math.sqrt(distX * distX + distY * distY);
                }

                var normalX = distX / distance;
                var normalY = distY / distance;
                var overlap = minDistance - distance;

                nextX -= normalX * overlap / 2;
                nextY -= normalY * overlap / 2;
                other.pos.x += normalX * overlap / 2;
                other.pos.y += normalY * overlap / 2;

                if (Math.abs(normalX) > Math.abs(normalY)) {
                    ball.velocity.x = -ball.velocity.x;
                    other.velocity.x = -other.velocity.x;
                } else {
                    ball.velocity.y = -ball.velocity.y;
                    other.velocity.y = -other.velocity.y;
                }
            }
        }

        for (block in blocks) {
            if (block.hit(nextX, ball.pos.y, ball.rad)) {
                pushEvent(0, ball.channel, noteCalc.transform(ball.pos.y), 100);
                if (ball.velocity.x > 0) nextX = block.bounds.left - ball.rad;
                else nextX = block.bounds.right + ball.rad;
                ball.velocity.x = -ball.velocity.x;
            }

            if (block.hit(ball.pos.x, nextY, ball.rad)) {
                pushEvent(0, ball.channel, noteCalc.transform(ball.pos.y), 100);
                if (ball.velocity.y > 0) nextY = block.bounds.top - ball.rad;
                else nextY = block.bounds.bottom + ball.rad;
                ball.velocity.y = -ball.velocity.y;
            }
        }

        ball.pos.x = nextX;
        ball.pos.y = nextY;
        dirty = true;
    }

    public function setDirty():Void {
        dirty = true;
    }

    public function needsRedraw(componentId:Int):Bool {
        if (componentId == PLAY_AREA_UID) {
            return dirty;
        }
        return false;
    }
}
