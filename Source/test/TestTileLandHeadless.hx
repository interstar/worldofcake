package test;

import tileland.TileLandSequencer;
import worldofcake.LocalPoint;
import worldofcake.SeededRandomSource;

class TestTileLandHeadless {
    static var failures = 0;

    static function check(name:String, condition:Bool):Void {
        Sys.println((condition ? "PASS " : "FAIL ") + name);
        if (!condition) failures++;
    }

    static function near(a:Float, b:Float, epsilon:Float = 0.000001):Bool {
        return Math.abs(a - b) <= epsilon;
    }

    static function make(seed:Int = 12345):TileLandSequencer {
        return new TileLandSequencer(new SeededRandomSource(seed));
    }

    static function testSeedAndCadence():Void {
        var sameA = make();
        var sameB = make();
        var different = make(54321);
        check("tileland same seed grid", sameA.exportStateJson() == sameB.exportStateJson());
        check("tileland different seed grid", sameA.exportStateJson() != different.exportStateJson());

        var fine = make();
        var coarse = make();
        for (_ in 0...100) fine.advanceTime(0.001);
        coarse.advanceTime(0.1);
        for (i in 0...3) {
            var a = fine.getCursors()[i];
            var b = coarse.getCursors()[i];
            check('tileland cadence cursor $i position', near(a.position.x, b.position.x) && near(a.position.y, b.position.y));
            check('tileland cadence cursor $i tile', a.tileX == b.tileX && a.tileY == b.tileY);
        }
        check("tileland cadence logical time", near(fine.getLogicalTime(), coarse.getLogicalTime()));
    }

    static function testCommandsPauseAndInvalidDelta():Void {
        var app = make();
        var beforeType = app.getTile(0, 0).type;
        app.mouseDown(TileLandSequencer.PLAY_AREA_UID, new LocalPoint(10, 10));
        check("tileland click flips tile", app.getTile(0, 0).type != beforeType);
        app.newValue(TileLandSequencer.speedUid(0), 8.0);
        check("tileland speed command", near(app.getCursorSpeed(0), 8.0));

        var before = app.getCursors()[0].position.x;
        app.pause();
        app.advanceTime(1.0);
        check("tileland pause", near(app.getCursors()[0].position.x, before));
        app.resume();
        app.advanceTime(-1.0);
        app.advanceTime(Math.NaN);
        check("tileland invalid delta", near(app.getCursors()[0].position.x, before));
    }

    static function testStateRoundTrip():Void {
        var source = make();
        source.mouseDown(TileLandSequencer.PLAY_AREA_UID, new LocalPoint(10, 10));
        source.newValue(TileLandSequencer.speedUid(1), 7.0);
        source.advanceTime(0.125);
        var restored = make(999);
        restored.importStateJson(source.exportStateJson());
        check("tileland state JSON", source.exportStateJson() == restored.exportStateJson());
        check("tileland state logical time", near(source.getLogicalTime(), restored.getLogicalTime()));
    }

    public static function main():Void {
        testSeedAndCadence();
        testCommandsPauseAndInvalidDelta();
        testStateRoundTrip();
        if (failures > 0) {
            Sys.println('$failures TileLand headless test(s) failed');
            Sys.exit(1);
        }
        Sys.println("All TileLand headless tests passed");
    }
}
