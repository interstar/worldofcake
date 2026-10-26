package gbloink;

import Math;
import worldofcake.ISequencerControl;
import worldofcake.SequencerCore;
import worldofcake.Event;
import worldofcake.Utils;
import worldofcake.NoteCalculator;
import worldofcake.LocalPoint;
import worldofcake.LocalRect;
import generated.gbloink.GbloinkControlIdsGenerated;
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
    /** MIDI velocity (1..127) of the notes this ball plays. Not to be confused with `velocity`, its motion. */
    public var noteVelocity:Int;

    public function new(pos:LocalPoint, colour:Int, channel:Int) {
        this.pos = pos;
        this.colour = colour;
        this.id = COUNTER++;
        this.velocity = new LocalPoint(2, 2);
        this.rad = 5;
        this.channel = channel;
        this.noteVelocity = Gbloink.DEFAULT_NOTE_VELOCITY;
    }

    public function writeJson(out:StringBuf):Void {
        out.add('{"x":'); out.add(Std.string(pos.x));
        out.add(',"y":'); out.add(Std.string(pos.y));
        out.add(',"vx":'); out.add(Std.string(velocity.x));
        out.add(',"vy":'); out.add(Std.string(velocity.y));
        out.add(',"rad":'); out.add(Std.string(rad));
        out.add(',"channel":'); out.add(Std.string(channel));
        out.add(',"noteVelocity":'); out.add(Std.string(noteVelocity));
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

class Gbloink extends SequencerCore implements ISequencerControl {
    public static inline var PLAY_AREA_UID:Int = GbloinkControlIdsGenerated.PLAYAREA;
    public static inline var RESET_UID:Int = GbloinkControlIdsGenerated.RESET;
    /** Latch 0 = off, 1 = play note on play-area edge bounce (hosts map from param). */
    public static inline var EDGE_NOTES_UID:Int = GbloinkControlIdsGenerated.EDGE_NOTES;
    public static inline var NOTE_LENGTH_UID:Int = GbloinkControlIdsGenerated.NOTE_LENGTH;
    public static inline var DEFAULT_NOTE_LENGTH:Float = 0.05;
    public static inline var SCALE_SELECT_UID:Int = GbloinkControlIdsGenerated.SCALESELECT;

    /** Per-ball controls, indexed by ball. Control IDs follow layout order, so they are listed, not computed. */
    public static var SPEED_UIDS(default, never):Array<Int> = [
        GbloinkControlIdsGenerated.REDSPEED, GbloinkControlIdsGenerated.GREENSPEED, GbloinkControlIdsGenerated.BLUESPEED];
    public static var NOTE_VELOCITY_UIDS(default, never):Array<Int> = [
        GbloinkControlIdsGenerated.REDVELOCITY, GbloinkControlIdsGenerated.GREENVELOCITY, GbloinkControlIdsGenerated.BLUEVELOCITY];
    public static inline var DEFAULT_NOTE_VELOCITY:Int = 100;

    public static inline function speedUid(index:Int):Int return SPEED_UIDS[index];
    public static inline function isSpeedUid(uid:Int):Bool return SPEED_UIDS.indexOf(uid) >= 0;
    public static inline function noteVelocityUid(index:Int):Int return NOTE_VELOCITY_UIDS[index];
    public static inline function isNoteVelocityUid(uid:Int):Bool return NOTE_VELOCITY_UIDS.indexOf(uid) >= 0;
    private static var SCALE_NAMES:Array<String> = ["chromatic", "major", "minor", "harmonic_minor", "melodic_minor", "minor_blues"];
    /** Ball speed in play-area units per second of real time (the knob's unit). */
    public static inline var DEFAULT_BALL_SPEED:Float = 120.0;

    /** When true, bouncing off the play-area border emits the same note events as block hits. */
    private var edgeNotesEnabled:Bool;
    /** Seconds between each note-on and its note-off. */
    private var noteLength:Float;
    
    private var areaSize:LocalPoint;
    private var random:IRandomSource;
    public var noteCalc:NoteCalculator;
    public var balls:Array<Ball>;
    public var blocks:Array<Block>;

    public function new(size:LocalPoint, ?random:IRandomSource) {
        this.areaSize = size;
        this.random = random == null ? new SystemRandomSource() : random;
        super(false);
        maxStepSeconds = SequencerCore.PHYSICS_STEP_SECONDS;
        bindLifecycleControls(GbloinkControlIdsGenerated.PAUSE, GbloinkControlIdsGenerated.MUTE);
        this.noteCalc = new NoteCalculator(size.y);
        this.edgeNotesEnabled = false;
        this.noteLength = DEFAULT_NOTE_LENGTH;

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
        for (i in 0...balls.length) setBallSpeed(i, DEFAULT_BALL_SPEED);
    }

    ///////////////////////////////////////////////////////////////////////////
    // ISequencer methods
    ///////////////////////////////////////////////////////////////////////////

    public function reset():Void {
        blocks = [];
        resetTransport();
        initBalls();
    }

    override function advanceModel(delta:Float):Bool {
        // Move each ball, check collisions
        for (ball in balls) {
            moveBall(ball, delta);
        }
        return true;
    }

    public function exportStateJson():String {
        var out = new StringBuf();
        out.add('{"v":1,"kind":"gbloink"');
        out.add(',"currentTime":'); out.add(Std.string(currentTime));
        out.add(',"paused":'); out.add(paused ? 'true' : 'false');
        out.add(',"muted":'); out.add(muted ? 'true' : 'false');
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
        out.add(',"noteLength":'); out.add(Std.string(noteLength));
        out.add('}');
        return out.toString();
    }

    public function importStateJson(json:String):Void {
        flushOutput();
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
            if (Reflect.hasField(o, "muted")) muted = Reflect.field(o, "muted") == true;
            if (Reflect.hasField(o, "noteLength")) setNoteLength(cast Reflect.field(o, "noteLength"));
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
                        if (Reflect.hasField(raw, "noteVelocity")) {
                            b.noteVelocity = clampNoteVelocity(cast Reflect.field(raw, "noteVelocity"));
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
        if (applyLifecycleValue(uid, value)) return;
        if (isSpeedUid(uid)) {
            setBallSpeed(SPEED_UIDS.indexOf(uid), value);
            dirty = true;
        } else if (isNoteVelocityUid(uid)) {
            setNoteVelocity(NOTE_VELOCITY_UIDS.indexOf(uid), value);
        } else if (uid == NOTE_LENGTH_UID) {
            setNoteLength(value);
        } else if (uid == EDGE_NOTES_UID) {
            edgeNotesEnabled = value > 0.5;
            dirty = true;
        } else if (uid == SCALE_SELECT_UID) {
            var index = Std.int(Math.max(0, Math.min(SCALE_NAMES.length - 1, Math.round(value))));
            setScale(SCALE_NAMES[index]);
        }
    }
    public function buttonPressed(uid:Int):Void {
        if (uid == RESET_UID) reset();
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

    public function getBalls():Array<Ball> {
        return balls;
    }

    /** Semantic speed value used by speed controls, independent of render target. */
    public function getBallSpeed(ballIndex:Int):Float {
        if (ballIndex < 0 || ballIndex >= balls.length) return 0.0;
        var velocity = balls[ballIndex].velocity;
        return Math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y);
    }

    public function getBlocks():Array<Block> {
        return blocks;
    }

    /** MIDI velocity (1..127) of the notes a ball plays. */
    public function getNoteVelocity(ballIndex:Int):Int {
        return ballIndex < 0 || ballIndex >= balls.length ? DEFAULT_NOTE_VELOCITY : balls[ballIndex].noteVelocity;
    }

    public function setNoteVelocity(ballIndex:Int, value:Float):Void {
        if (ballIndex < 0 || ballIndex >= balls.length || !Math.isFinite(value)) return;
        balls[ballIndex].noteVelocity = clampNoteVelocity(value);
        dirty = true;
    }

    private static function clampNoteVelocity(value:Float):Int {
        return Std.int(Math.max(1, Math.min(127, Math.round(value))));
    }

    public function getNoteLength():Float return noteLength;

    public function setNoteLength(seconds:Float):Void {
        if (!Math.isFinite(seconds)) return;
        noteLength = Math.max(SequencerCore.MIN_NOTE_DURATION, seconds);
        dirty = true;
    }

    public function setScale(scaleName:String):Void {
        if (!noteCalc.scales.exists(scaleName) || noteCalc.current == scaleName) return;
        noteCalc.setCurrent(scaleName);
        // Notes already queued under the previous scale must not leak through
        // after a scale change.  The next collision will publish using the new
        // calculator immediately. Releases already queued are kept.
        clearEvents();
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

    private function playNote(ball:Ball, note:Int):Void {
        emitNote(currentTime, ball.channel, note, ball.noteVelocity, noteLength);
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
                playNote(ball, noteCalc.transform(nextY));
            }
        } else if (nextX > areaSize.x - ball.rad) {
            nextX = areaSize.x - ball.rad;
            ball.velocity.x = -ball.velocity.x;
            if (edgeNotesEnabled) {
                playNote(ball, noteCalc.transform(nextY));
            }
        }

        if (nextY < ball.rad) {
            nextY = ball.rad;
            ball.velocity.y = -ball.velocity.y;
            if (edgeNotesEnabled) {
                playNote(ball, noteCalc.transform(nextY));
            }
        } else if (nextY > areaSize.y - ball.rad) {
            nextY = areaSize.y - ball.rad;
            ball.velocity.y = -ball.velocity.y;
            if (edgeNotesEnabled) {
                playNote(ball, noteCalc.transform(nextY));
            }
        }

        for (other in balls) {
            if (other == ball) continue;
            // Resolve each pair exactly once.  The old loop handled A-B when
            // moving A and then again when moving B, flipping both velocities
            // twice and allowing overlapped balls to orbit/stick together.
            if (other.id <= ball.id) continue;

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

                // Only reflect while the pair is closing.  Once positional
                // correction has separated them, repeatedly flipping their
                // components is what caused the characteristic sticking and
                // rotation around one another.
                var relativeAlongNormal =
                    (ball.velocity.x - other.velocity.x) * normalX +
                    (ball.velocity.y - other.velocity.y) * normalY;
                if (relativeAlongNormal > 0) {
                    if (Math.abs(normalX) > Math.abs(normalY)) {
                        ball.velocity.x = -ball.velocity.x;
                        other.velocity.x = -other.velocity.x;
                    } else {
                        ball.velocity.y = -ball.velocity.y;
                        other.velocity.y = -other.velocity.y;
                    }
                }
            }
        }

        for (block in blocks) {
            if (block.hit(nextX, ball.pos.y, ball.rad)) {
                playNote(ball, noteCalc.transform(ball.pos.y));
                // If the ball is already embedded (for example because a
                // block was clicked over it), velocity alone is not a useful
                // side selector: it can eject the ball through the whole
                // block.  Choose the nearest face instead.  For a normal
                // approach we retain the traditional velocity-directed
                // reflection.
                if (ball.pos.x > block.bounds.left && ball.pos.x < block.bounds.right) {
                    var leftGap = ball.pos.x - block.bounds.left;
                    var rightGap = block.bounds.right - ball.pos.x;
                    if (leftGap <= rightGap) {
                        nextX = block.bounds.left - ball.rad;
                        ball.velocity.x = -Math.abs(ball.velocity.x);
                    } else {
                        nextX = block.bounds.right + ball.rad;
                        ball.velocity.x = Math.abs(ball.velocity.x);
                    }
                } else if (ball.velocity.x > 0) {
                    nextX = block.bounds.left - ball.rad;
                    ball.velocity.x = -ball.velocity.x;
                } else {
                    nextX = block.bounds.right + ball.rad;
                    ball.velocity.x = -ball.velocity.x;
                }
            }

            if (block.hit(ball.pos.x, nextY, ball.rad)) {
                playNote(ball, noteCalc.transform(ball.pos.y));
                if (ball.pos.y > block.bounds.top && ball.pos.y < block.bounds.bottom) {
                    var topGap = ball.pos.y - block.bounds.top;
                    var bottomGap = block.bounds.bottom - ball.pos.y;
                    if (topGap <= bottomGap) {
                        nextY = block.bounds.top - ball.rad;
                        ball.velocity.y = -Math.abs(ball.velocity.y);
                    } else {
                        nextY = block.bounds.bottom + ball.rad;
                        ball.velocity.y = Math.abs(ball.velocity.y);
                    }
                } else if (ball.velocity.y > 0) {
                    nextY = block.bounds.top - ball.rad;
                    ball.velocity.y = -ball.velocity.y;
                } else {
                    nextY = block.bounds.bottom + ball.rad;
                    ball.velocity.y = -ball.velocity.y;
                }
            }
        }

        ball.pos.x = nextX;
        ball.pos.y = nextY;
        dirty = true;
    }

    public function setDirty():Void {
        dirty = true;
    }

}
