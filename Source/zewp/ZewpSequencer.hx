package zewp;

import generated.zewp.ZewpControlIdsGenerated;
import worldofcake.Event;
import worldofcake.ISequencerControl;
import worldofcake.SequencerCore;
import worldofcake.LocalPoint;
import worldofcake.IRandomSource;
import worldofcake.SystemRandomSource;
import haxe.Json;
import StringTools;

class ZewpSequencer extends SequencerCore implements ISequencerControl {
    public static inline var PLAY_AREA_UID:Int = ZewpControlIdsGenerated.PLAYAREA;
    public static inline var POPULATION_UID:Int = ZewpControlIdsGenerated.POPULATION;
    public static inline var SPEED_UID:Int = ZewpControlIdsGenerated.SPEED;
    public static inline var RESET_UID:Int = ZewpControlIdsGenerated.RESET;
    public static inline var PAUSE_UID:Int = ZewpControlIdsGenerated.PAUSE;
    public static inline var CC_EVENT_TYPE:Int = 1;

    public var areaWidth:Int;
    public var areaHeight:Int;

    private var zewps:Array<Zewp>;
    private var blocks:Array<Block>;
    private var selectedBlock:Block;
    private var dragOffsetX:Float;
    private var dragOffsetY:Float;
    private var random:IRandomSource;
    private var speedMultiplier:Float;
    private static var COLORS:Array<Int> = [0xFF4040, 0x40FF40, 0x4040FF, 0xFFFF40, 0xFF40FF, 0x40FFFF, 0xFF8040, 0x80FF40, 0x4080FF, 0xFFFFFF];

    public function new(width:Int, height:Int, ?random:IRandomSource) {
        this.random = random == null ? new SystemRandomSource() : random;
        super(true);
        areaWidth = width;
        areaHeight = height;
        speedMultiplier = 1.0;
        repopulateWorld();
    }

    private function repopulateWorld():Void {
        zewps = [];
        for (i in 0...10) {
            zewps.push(createZewp(i));
        }

        blocks = [];
        for (i in 0...20) {
            var x = 50 + random.nextFloat() * (areaWidth - 100);
            var y = 50 + random.nextFloat() * (areaHeight - 100);
            var blockWidth = 15 + random.nextFloat() * 20;
            var blockHeight = 15 + random.nextFloat() * 20;
            blocks.push(new Block(x, y, blockWidth, blockHeight, 0xFFFFFF));
        }
    }

    private function createZewp(index:Int):Zewp {
        var x = 80 + random.nextFloat() * (areaWidth - 160);
        var y = 80 + random.nextFloat() * (areaHeight - 160);
        var velocity = (4 + random.nextFloat() * 4) * speedMultiplier;
        return new Zewp(x, y, 10, velocity, COLORS[index % COLORS.length], 1, 10 + index, random);
    }

    public function reset():Void {
        resetTransport();
        selectedBlock = null;
        repopulateWorld();
    }

    override function advanceModel(delta:Float):Bool {
        // Preserve the original 1 ms physics granularity even when a native
        // frontend presents snapshots at a lower GUI rate. Turning and
        // look-ahead are discrete decisions, so one coarse 33 ms step would
        // skip intermediate collisions and produce visibly erratic jumps.
        var remaining = delta;
        while (remaining > 0) {
            var step = remaining > 0.001 ? 0.001 : remaining;
            for (zewp in zewps) {
                zewp.update(zewps, blocks, areaWidth, areaHeight, step);
            }
            remaining -= step;
        }
        return true;
    }

    /** Rack consumes position/gate snapshots, so it must not retain CC events. */
    public function discardPendingEvents():Void {
        events = [];
    }

    public function exportStateJson():String {
        // Keep Rack autosave allocation-free with respect to Haxe reflection.
        // The importer may continue to use Json.parse for compatibility, but
        // exporting is an explicit traversal of the known model fields.
        var out = new StringBuf();
        out.add('{"v":4,"kind":"zewp","width":'); out.add(areaWidth);
        out.add(',"height":'); out.add(areaHeight);
        out.add(',"currentTime":'); out.add(currentTime);
        out.add(',"paused":'); out.add(paused ? "true" : "false");
        out.add(',"speedMultiplier":'); out.add(speedMultiplier);
        out.add(',"zewps":[');
        for (i in 0...zewps.length) {
            if (i > 0) out.add(',');
            var z = zewps[i];
            out.add('{"x":'); out.add(z.position.x); out.add(',"y":'); out.add(z.position.y);
            out.add(',"angle":'); out.add(z.angle); out.add(',"length":'); out.add(z.length);
            out.add(',"velocity":'); out.add(z.velocity); out.add(',"color":'); out.add(z.color);
            out.add(',"channel":'); out.add(z.channel); out.add(',"ccNumber":'); out.add(z.ccNumber);
            out.add(',"dAngle":'); out.add(z.dAngle); out.add('}');
        }
        out.add('],"blocks":[');
        for (i in 0...blocks.length) {
            if (i > 0) out.add(',');
            var b = blocks[i];
            out.add('{"left":'); out.add(b.bounds.left); out.add(',"top":'); out.add(b.bounds.top);
            out.add(',"right":'); out.add(b.bounds.right); out.add(',"bottom":'); out.add(b.bounds.bottom);
            out.add(',"color":'); out.add(b.color); out.add('}');
        }
        out.add(']}');
        return out.toString();
    }

    public function importStateJson(json:String):Void {
        if (json == null || StringTools.trim(json) == "") return;
        try {
            var o:Dynamic = Json.parse(json);
            if (Reflect.field(o, "kind") != "zewp" || Std.int(Reflect.field(o, "v")) < 4) return;
            var zs:Array<Dynamic> = Reflect.field(o, "zewps");
            var bs:Array<Dynamic> = Reflect.field(o, "blocks");
            if (zs == null || bs == null) return;
            zewps = [];
            speedMultiplier = Reflect.hasField(o, "speedMultiplier") ? o.speedMultiplier : 1.0;
            for (q in zs) {
                var z = new Zewp(q.x, q.y, q.length, q.velocity, q.color, q.channel, q.ccNumber, random);
                z.dAngle = q.dAngle; z.setAngle(q.angle); z.constrainGlyphToArea(areaWidth, areaHeight); zewps.push(z);
            }
            blocks = [for (q in bs) {
                var b = new Block(0, 0, 1, 1, q.color);
                b.bounds = new worldofcake.LocalRect(q.left, q.top, q.right, q.bottom);
                b;
            }];
            for (block in blocks) constrainBlockToArea(block);
            currentTime = Reflect.hasField(o, "currentTime") ? o.currentTime : 0;
            paused = Reflect.hasField(o, "paused") && o.paused == true;
            selectedBlock = null; events = []; dirty = true;
        } catch (_:Dynamic) {}
    }

    public function mouseDown(uid:Int, point:LocalPoint):Void {
        if (uid != PLAY_AREA_UID) {
            return;
        }

        for (block in blocks) {
            if (block.hit(point)) {
                selectedBlock = block;
                dragOffsetX = point.x - block.bounds.center().x;
                dragOffsetY = point.y - block.bounds.center().y;
                break;
            }
        }
    }

    public function mouseDragged(uid:Int, point:LocalPoint):Void {
        dragTo(uid, point);
    }

    /** Canonical model-space drag operation shared by every frontend. */
    public function dragTo(uid:Int, point:LocalPoint):Void {
        if (uid == PLAY_AREA_UID && selectedBlock != null) {
            selectedBlock.bounds.moveTo(new LocalPoint(point.x - dragOffsetX, point.y - dragOffsetY));
            constrainBlockToArea(selectedBlock);
            dirty = true;
        }
    }


    public function mouseUp(uid:Int, point:LocalPoint):Void {
        selectedBlock = null;
    }

    public function textSubmitted(uid:Int, text:String):Void {}
    public function newValue(uid:Int, value:Float):Void {
        if (uid == POPULATION_UID) {
            setPopulation(Std.int(Math.round(value)));
        } else if (uid == SPEED_UID) {
            setSpeedMultiplier(value);
        } else if (uid == PAUSE_UID) {
            if (value > 0.5) pause(); else resume();
        }
        dirty = true;
    }
    public function buttonPressed(uid:Int):Void {
        if (uid == RESET_UID) reset();
    }
    public function keyPressed(uid:Int, key:String):Void {}

    public function generateEvents():Void {
        if (paused) {
            return;
        }
        for (zewp in zewps) {
            events.push(new Event(
                currentTime,
                CC_EVENT_TYPE,
                zewp.channel,
                zewp.ccNumber,
                Std.int((zewp.position.y / areaHeight) * 127)
            ));
        }
    }

    public function getZewps():Array<Zewp> {
        return zewps;
    }

    public function getBlocks():Array<Block> {
        return blocks;
    }

    public function setPopulation(value:Int):Void {
        var target = Std.int(Math.max(0, Math.min(40, value)));
        while (zewps.length > target) zewps.pop();
        while (zewps.length < target) zewps.push(createZewp(zewps.length));
        dirty = true;
    }

    public function setSpeedMultiplier(value:Float):Void {
        var next = Math.max(1.0 / 3.0, Math.min(1.5, value));
        var ratio = speedMultiplier > 0 ? next / speedMultiplier : 1.0;
        speedMultiplier = next;
        for (zewp in zewps) {
            zewp.velocity *= ratio;
            zewp.setAngle(zewp.angle);
        }
        dirty = true;
    }

    public function getSpeedMultiplier():Float return speedMultiplier;

    private function constrainBlockToArea(block:Block):Void {
        var center = block.bounds.center();
        var halfWidth = block.bounds.width() * 0.5;
        var halfHeight = block.bounds.height() * 0.5;
        var clampedX = Math.max(halfWidth, Math.min(areaWidth - halfWidth, center.x));
        var clampedY = Math.max(halfHeight, Math.min(areaHeight - halfHeight, center.y));
        // Preserve the exact persisted rectangle when it is already in bounds.
        if (clampedX != center.x || clampedY != center.y) {
            block.bounds.moveTo(new LocalPoint(clampedX, clampedY));
        }
    }
}
