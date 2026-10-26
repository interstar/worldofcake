package test;

import gbloink.Gbloink;
import worldofcake.LocalPoint;
import worldofcake.SeededRandomSource;

class TestGbloinkHeadless {
    static var failures:Int = 0;

    static function check(name:String, condition:Bool):Void {
        if (condition) {
            Sys.println('PASS $name');
        } else {
            Sys.println('FAIL $name');
            failures++;
        }
    }

    static function near(a:Float, b:Float, epsilon:Float = 0.000001):Bool {
        return Math.abs(a - b) <= epsilon;
    }

    static function make(seed:Int):Gbloink {
        return new Gbloink(new LocalPoint(700, 500), new SeededRandomSource(seed));
    }

    /** Ball speed is play-area units per second of real time (the knob's unit). */
    static function testLegacyPacing():Void {
        var app = make(1);
        app.advanceTime(0.001);
        var perAxis = Gbloink.DEFAULT_BALL_SPEED / Math.sqrt(2) * 0.001;
        check("real-time 1 ms x pacing", near(app.balls[0].pos.x, 95 + perAxis));
        check("real-time 1 ms y pacing", near(app.balls[0].pos.y, 85 + perAxis));
    }

    static function testCadenceIndependence():Void {
        var fine = make(2);
        var coarse = make(2);
        for (_ in 0...100) fine.advanceTime(0.001);
        for (_ in 0...10) coarse.advanceTime(0.01);
        for (i in 0...fine.balls.length) {
            check('cadence x ball $i', near(fine.balls[i].pos.x, coarse.balls[i].pos.x));
            check('cadence y ball $i', near(fine.balls[i].pos.y, coarse.balls[i].pos.y));
        }
        check("cadence logical time", near(fine.getLogicalTime(), coarse.getLogicalTime()));
    }

    static function testSeededBlocks():Void {
        var a = make(12345);
        var b = make(12345);
        var c = make(54321);
        var click = new LocalPoint(200, 200);
        a.mouseDown(Gbloink.PLAY_AREA_UID, click);
        b.mouseDown(Gbloink.PLAY_AREA_UID, click);
        c.mouseDown(Gbloink.PLAY_AREA_UID, click);
        check("same seed block JSON", a.exportBlocksJson() == b.exportBlocksJson());
        check("different seed block JSON", a.exportBlocksJson() != c.exportBlocksJson());
    }

    static function testPauseAndInvalidDelta():Void {
        var app = make(9);
        var x = app.balls[0].pos.x;
        app.setPaused(true);
        app.advanceTime(1.0);
        check("pause freezes model", near(app.balls[0].pos.x, x) && near(app.getLogicalTime(), 0));
        app.setPaused(false);
        app.advanceTime(-1.0);
        app.advanceTime(Math.NaN);
        check("invalid delta ignored", near(app.balls[0].pos.x, x) && near(app.getLogicalTime(), 0));
    }

    static function testStateRoundTrip():Void {
        var source = make(77);
        source.mouseDown(Gbloink.PLAY_AREA_UID, new LocalPoint(250, 210));
        source.newValue(Gbloink.speedUid(0), 0.05);
        source.newValue(Gbloink.noteVelocityUid(2), 37.4);
        source.newValue(Gbloink.SCALE_SELECT_UID, 4);
        source.advanceTime(0.025);
        var restored = make(99);
        restored.importStateJson(source.exportStateJson());
        check("state block round trip", restored.exportBlocksJson() == source.exportBlocksJson());
        check("state logical time", near(restored.getLogicalTime(), source.getLogicalTime()));
        check("state ball position", near(restored.balls[0].pos.x, source.balls[0].pos.x));
        check("state ball speed", near(restored.getBallSpeed(0), 0.05));
        check("state scale", restored.getScaleIndex() == 4);
        check("state note velocity", restored.getNoteVelocity(2) == 37 && restored.getNoteVelocity(0) == Gbloink.DEFAULT_NOTE_VELOCITY);
    }

    static function testSemanticScaleSelection():Void {
        var app = make(13);
        app.newValue(Gbloink.SCALE_SELECT_UID, 3);
        check("gbloink semantic scale selection", app.getScaleName() == "harmonic_minor" && app.getScaleIndex() == 3);
    }

    static function testTransportEpochResetPreservesLayout():Void {
        var app = make(21);
        app.mouseDown(Gbloink.PLAY_AREA_UID, new LocalPoint(250, 210));
        app.advanceTime(0.25);
        var blocks = app.exportBlocksJson();
        app.resetTransport();
        check("running transport reset stays running", !app.isPaused());
        app.advanceTime(0.25);
        app.setPaused(true);
        app.resetTransport();
        check("transport reset returns to zero", near(app.getLogicalTime(), 0));
        check("transport reset preserves layout", app.exportBlocksJson() == blocks);
        var x = app.balls[0].pos.x;
        app.resyncTime(1.0);
        check("paused transport reset remains paused", near(app.balls[0].pos.x, x));
        app.setPaused(false);
        app.resyncTime(1.0);
        check("transport resumes from new epoch", near(app.getLogicalTime(), 1.0));
    }

    /** Each ball plays its notes at its own MIDI velocity. */
    static function testNoteVelocityPerBall():Void {
        var app = make(5);
        app.setEdgeNotesEnabled(true);
        app.newValue(Gbloink.noteVelocityUid(0), 20);
        app.newValue(Gbloink.noteVelocityUid(1), 200);
        app.newValue(Gbloink.noteVelocityUid(2), Math.NaN);
        var seen = new Map<Int, Int>();
        for (_ in 0...200) {
            app.advanceTime(0.05);
            for (e in app.events) if (e.type == worldofcake.EventType.NoteOn) seen.set(e.data1, e.data3);
        }
        check("red ball notes use its velocity", seen.get(1) == 20);
        check("velocity is clamped to 127", seen.get(2) == 127);
        check("invalid velocity ignored", seen.get(3) == Gbloink.DEFAULT_NOTE_VELOCITY);
    }

    public static function main():Void {
        testLegacyPacing();
        testCadenceIndependence();
        testSeededBlocks();
        testPauseAndInvalidDelta();
        testStateRoundTrip();
        testSemanticScaleSelection();
        testNoteVelocityPerBall();
        testTransportEpochResetPreservesLayout();
        if (failures > 0) {
            Sys.println('$failures Gbloink headless test(s) failed');
            Sys.exit(1);
        }
        Sys.println("All Gbloink headless tests passed");
    }
}
