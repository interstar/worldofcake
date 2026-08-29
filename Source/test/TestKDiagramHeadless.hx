package test;

import kdiagram.KDiagramSequencer;
import worldofcake.SeededRandomSource;
import worldofcake.LocalPoint;

class TestKDiagramHeadless {
    static var failures = 0;
    static function check(name:String, condition:Bool):Void {
        Sys.println((condition ? "PASS " : "FAIL ") + name);
        if (!condition) failures++;
    }
    static function near(a:Float, b:Float, epsilon:Float = 0.000001):Bool return Math.abs(a - b) <= epsilon;
    static function make(seed:Int = 12345):KDiagramSequencer return new KDiagramSequencer(new SeededRandomSource(seed));

    static function testSeedAndCadence():Void {
        var sameA = make();
        var sameB = make();
        var different = make(54321);
        check("kdiag same seed graph", sameA.exportStateJson() == sameB.exportStateJson());
        check("kdiag different seed graph", sameA.exportStateJson() != different.exportStateJson());

        var fine = make();
        var coarse = make();
        for (app in [fine, coarse]) {
            app.setCursorSpeed(0, 8.0);
            app.setCursorSpeed(1, 0.0);
            app.setCursorSpeed(2, 0.0);
        }
        for (_ in 0...100) fine.advanceTime(0.01);
        coarse.advanceTime(1.0);
        check("kdiag cadence cursor position", near(fine.getCursorPosX(0), coarse.getCursorPosX(0))
              && near(fine.getCursorPosY(0), coarse.getCursorPosY(0)));
        check("kdiag cadence target", near(fine.getCursorTargetX(0), coarse.getCursorTargetX(0))
              && near(fine.getCursorTargetY(0), coarse.getCursorTargetY(0)));
        check("kdiag cadence logical time", near(fine.getLogicalTime(), coarse.getLogicalTime()));
    }

    static function testControlsPauseState():Void {
        var app = make();
        app.setCursorSpeed(0, 3.0);
        app.setBaseMidiChannel(7);
        app.setSelectedCursorIndex(2);
        app.rotateNetwork(0.1);
        check("kdiag speed", near(app.getCursorSpeed(0), 3.0));
        check("kdiag channel", app.getBaseMidiChannel() == 7);
        check("kdiag selection", app.getSelectedCursorIndex() == 2);
        var x = app.getCursorPosX(0);
        app.pause(); app.advanceTime(1.0);
        check("kdiag pause", near(x, app.getCursorPosX(0)));
        app.resume(); app.advanceTime(-1); app.advanceTime(Math.NaN);
        check("kdiag invalid delta", near(x, app.getCursorPosX(0)));

        app.advanceTime(0.25);
        var restored = make(999);
        restored.importStateJson(app.exportStateJson());
        check("kdiag state round trip", restored.exportStateJson() == app.exportStateJson());
    }

    static function testNodeClickRestartsSelectedCursor():Void {
        var app = make();
        app.setSelectedCursorIndex(2);
        var node = app.getNetwork().getNode(0);
        app.mouseDown(KDiagramSequencer.PLAY_AREA_UID, new LocalPoint(node.pos.x, node.pos.y));
        check("kdiag click relocates selected cursor", near(app.getCursorPosX(2), node.pos.x) && near(app.getCursorPosY(2), node.pos.y));
        check("kdiag click follows outgoing arc or stops at sink", app.getCursorIsMoving(2) == (node.arcs.length > 0));
    }

    static function testSemanticCursorSelection():Void {
        var app = make();
        app.newValue(KDiagramSequencer.CURSOR_SELECT_UID, 2);
        check("kdiag semantic cursor selection", app.getSelectedCursorIndex() == 2);
    }

    public static function main():Void {
        testSeedAndCadence();
        testControlsPauseState();
        testNodeClickRestartsSelectedCursor();
        testSemanticCursorSelection();
        if (failures > 0) { Sys.println('$failures K-Diag headless test(s) failed'); Sys.exit(1); }
        Sys.println("All K-Diag headless tests passed");
    }
}
