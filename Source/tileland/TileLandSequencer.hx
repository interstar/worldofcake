package tileland;

import generated.tileland.TileLandControlIdsGenerated;
import haxe.Json;
import StringTools;
import worldofcake.Event;
import tileland.Tile;
import tileland.Cursor;
import tileland.Direction;
import worldofcake.ISequencerControl;
import worldofcake.SequencerCore;
import tileland.TileLandLayout;
import worldofcake.LocalPoint;
import worldofcake.IRandomSource;
import worldofcake.SystemRandomSource;

class TileLandSequencer extends SequencerCore implements ISequencerControl {
    // Constants
    public static inline var PLAY_AREA_UID:Int = TileLandControlIdsGenerated.PLAYAREA;
    public static inline var SPEED_UID_BASE:Int = TileLandControlIdsGenerated.REDSPEED;
    public static inline var SPEED_UID_COUNT:Int = 3;
    public static inline var RESET_UID:Int = TileLandControlIdsGenerated.RESET;
    public static inline var PAUSE_UID:Int = TileLandControlIdsGenerated.PAUSE;

    public static inline function speedUid(index:Int):Int {
        return SPEED_UID_BASE + index;
    }

    public static inline function speedIndexForUid(uid:Int):Int {
        return uid - SPEED_UID_BASE;
    }

    public static inline function isSpeedUid(uid:Int):Bool {
        return uid >= SPEED_UID_BASE && uid < SPEED_UID_BASE + SPEED_UID_COUNT;
    }
    
    // Dimensions
    public var areaWidth:Float;
    public var areaHeight:Float;
    private var tileSize:Float;
    private var rows:Int;
    private var cols:Int;
    
    // Game objects
    private var tiles:Array<Array<Tile>>;
    /** Increments whenever semantic tile visuals change. */
    private var visualVersion:Int;
    
    // Cursor state
    private var cursors:Array<Cursor>;
    private var random:IRandomSource;
    
    public function new(?random:IRandomSource) {
        this.random = random == null ? new SystemRandomSource() : random;
        this.areaWidth = TileLandLayout.PLAY_AREA_WIDTH;
        this.areaHeight = TileLandLayout.PLAY_AREA_HEIGHT;
        this.tileSize = TileLandLayout.TILE_SIZE;
        this.rows = TileLandLayout.GRID_ROWS;
        this.cols = TileLandLayout.GRID_COLS;
        super(true);
        this.visualVersion = 0;
        buildGridAndCursors();
    }

    private function buildGridAndCursors():Void {
        visualVersion++;
        tiles = [];
        for (row in 0...rows) {
            tiles[row] = [];
            for (col in 0...cols) {
                var type = (random.nextFloat() < 0.5) ? 1 : 2;
                tiles[row][col] = new Tile(type, new LocalPoint(col * tileSize, row * tileSize), tileSize);
            }
        }

        cursors = [
            new Cursor(2, 2, Direction.East, 1, 0xFF0000),
            new Cursor(cols - 2, 0, Direction.South, 2, 0x00FF00),
            new Cursor(cols - 2, rows - 2, Direction.West, 3, 0x0000FF)
        ];

        for (cursor in cursors) {
            var tile = tiles[cursor.tileY][cursor.tileX];
            cursor.updatePosition(tile, 0.0, rows, cols);
        }
    }

    public function reset():Void {
        resetTransport();
        buildGridAndCursors();
    }
    
    // ISequencer implementation
    override function advanceModel(delta:Float):Bool {
        for (cursor in cursors) {
            advanceCursor(cursor, delta);
            
            // Generate CC events for position
            events.push(new Event(
                currentTime,
                1,  // CC event type
                cursor.channel,
                1,  // CC number for X position
                Std.int((cursor.position.x / areaWidth) * 127)
            ));
            events.push(new Event(
                currentTime,
                1,  // CC event type
                cursor.channel,
                2,  // CC number for Y position
                Std.int(((areaHeight - cursor.position.y) / areaHeight) * 127)
            ));
        }
        
        return true;
    }

    /**
        Split only at tile boundaries so a control tick cannot discard excess
        travel. Equivalent elapsed time therefore follows the same tile path
        even when the host uses a different control cadence.
    **/
    private function advanceCursor(cursor:Cursor, delta:Float):Void {
        if (!Math.isFinite(cursor.speed) || cursor.speed <= 0) {
            return;
        }
        var remaining = delta;
        var transitions = 0;
        while (remaining > 0 && transitions < 100000) {
            if (cursor.tileX < 0 || cursor.tileX >= cols ||
                cursor.tileY < 0 || cursor.tileY >= rows) {
                return;
            }
            var tile = tiles[cursor.tileY][cursor.tileX];
            var toBoundary = (1.0 - cursor.progress) / cursor.speed;
            if (toBoundary <= 0) {
                cursor.updatePosition(tile, 0.0, rows, cols);
                transitions++;
                continue;
            }
            var step = Math.min(remaining, toBoundary);
            cursor.updatePosition(tile, step, rows, cols);
            remaining -= step;
            if (step >= toBoundary) {
                transitions++;
            }
            if (step == 0) {
                break;
            }
        }
    }
    
    static function dirToStr(d:Direction):String {
        return switch (d) {
            case North: "n";
            case South: "s";
            case East: "e";
            case West: "w";
        };
    }

    static function strToDir(s:String):Direction {
        if (s == "n") {
            return North;
        }
        if (s == "s") {
            return South;
        }
        if (s == "w") {
            return West;
        }
        return East;
    }

    public function exportStateJson():String {
        var flat:Array<Int> = [];
        for (row in 0...rows) {
            for (col in 0...cols) {
                flat.push(tiles[row][col].type);
            }
        }
        var curs:Array<Dynamic> = [];
        for (c in cursors) {
            curs.push({
                tileX: c.tileX,
                tileY: c.tileY,
                dir: dirToStr(c.direction),
                channel: c.channel,
                speed: c.speed,
                progress: c.progress
            });
        }
        var out = new StringBuf(); out.add('{"v":2,"kind":"tileland","currentTime":'); out.add(currentTime); out.add(',"paused":'); out.add(paused ? 'true' : 'false'); out.add(',"tiles":[');
        for (i in 0...flat.length) { if (i > 0) out.add(','); out.add(flat[i]); }
        out.add('],"cursors":[');
        for (i in 0...curs.length) { if (i > 0) out.add(','); var c:Dynamic=curs[i]; out.add('{"tileX":'); out.add(c.tileX); out.add(',"tileY":'); out.add(c.tileY); out.add(',"dir":"'); out.add(c.dir); out.add('","channel":'); out.add(c.channel); out.add(',"speed":'); out.add(c.speed); out.add(',"progress":'); out.add(c.progress); out.add('}'); }
        out.add(']}'); return out.toString();
    }

    public function importStateJson(json:String):Void {
        events = [];
        if (json == null || StringTools.trim(json) == "") {
            return;
        }
        try {
            var o:Dynamic = Json.parse(json);
            if (Reflect.field(o, "kind") != "tileland") {
                return;
            }
            var v = Reflect.field(o, "v");
            if (v == null || Std.int(v) < 2) {
                return;
            }
            var flat:Array<Dynamic> = cast Reflect.field(o, "tiles");
            if (flat == null || flat.length != rows * cols) {
                return;
            }
            var k = 0;
            for (row in 0...rows) {
                for (col in 0...cols) {
                    var t = Std.int(flat[k++]);
                    if (t != 1 && t != 2) {
                        t = 1;
                    }
                    tiles[row][col] = new Tile(t, new LocalPoint(col * tileSize, row * tileSize), tileSize);
                }
            }
            var ca:Array<Dynamic> = cast Reflect.field(o, "cursors");
            if (ca == null || ca.length != cursors.length) {
                return;
            }
            var colours = [0xFF0000, 0x00FF00, 0x0000FF];
            cursors = [];
            for (i in 0...ca.length) {
                var c:Dynamic = ca[i];
                var dstr = Std.string(Reflect.field(c, "dir"));
                var cx = Std.int(Reflect.field(c, "tileX"));
                var cy = Std.int(Reflect.field(c, "tileY"));
                var ch = Std.int(Reflect.field(c, "channel"));
                var sp = Std.parseFloat(Std.string(Reflect.field(c, "speed")));
                var pr = Std.parseFloat(Std.string(Reflect.field(c, "progress")));
                var cur = new Cursor(cx, cy, strToDir(dstr), ch, colours[i]);
                cur.speed = sp;
                cur.progress = pr;
                cursors.push(cur);
            }
            for (c in cursors) {
                if (c.tileY >= 0 && c.tileY < rows && c.tileX >= 0 && c.tileX < cols) {
                    var tile = tiles[c.tileY][c.tileX];
                    c.updatePosition(tile, 0.0, rows, cols);
                }
            }
            if (Reflect.hasField(o, "currentTime")) {
                currentTime = Std.parseFloat(Std.string(Reflect.field(o, "currentTime")));
            }
            if (Reflect.hasField(o, "paused")) {
                paused = Reflect.field(o, "paused") == true;
            }
            dirty = true;
            visualVersion++;
        } catch (_:Dynamic) {}
    }
    
    // IControlPanel implementation
    public function mouseDown(uid:Int, point:LocalPoint):Void {
        if (uid == PLAY_AREA_UID) {
            var col = Std.int(point.x / tileSize);
            var row = Std.int(point.y / tileSize);
            if (row >= 0 && row < rows && col >= 0 && col < cols) {
                tiles[row][col].flip();
                dirty = true;
                visualVersion++;
            }
        }
    }
    
    // Helper methods
    public function getVisualVersion():Int return visualVersion;
    
    public function getTiles():Array<Array<Tile>> {
        return tiles;
    }
    
    // Unused IControlPanel methods
    public function mouseDragged(uid:Int, point:LocalPoint):Void {}
    public function mouseUp(uid:Int, point:LocalPoint):Void {}
    public function textSubmitted(uid:Int, text:String):Void {}
    public function newValue(uid:Int, value:Float):Void {
        if (isSpeedUid(uid)) {  // Speed sliders
            var cursorIndex = speedIndexForUid(uid);
            cursors[cursorIndex].speed = value;  // Update cursor's speed directly
            dirty = true;
        } else if (uid == PAUSE_UID) {
            if (value > 0.5) pause(); else resume();
            dirty = true;
        }
    }
    public function buttonPressed(uid:Int):Void {
        if (uid == RESET_UID) reset();
    }
    public function keyPressed(uid:Int, key:String):Void {}
    
    // Add getter for cursors
    public function getCursors():Array<Cursor> {
        return cursors;
    }
    
    // Add these methods
    public function getRows():Int {
        return rows;
    }
    
    public function getCols():Int {
        return cols;
    }
    
    public function getTile(col:Int, row:Int):Tile {
        return tiles[row][col];
    }
    
    public function getCursorSpeed(index:Int):Float {
        return cursors[index].speed;
    }
    
    public function getBaseChannel():Int {
        return 1;  // Default channel, adjust as needed
    }
} 
