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
        app.setPaused(true); app.advanceTime(1.0);
        check("kdiag pause", near(x, app.getCursorPosX(0)));
        app.setPaused(false); app.advanceTime(-1); app.advanceTime(Math.NaN);
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

    static function testScaleAndNotePitch():Void {
        var app = make();
        app.newValue(KDiagramSequencer.SCALE_SELECT_UID, 1);
        check("kdiag semantic scale selection", app.getScaleIndex() == 1);
        app.setCursorSpeed(0, 8.0);
        app.setCursorSpeed(1, 0.0);
        app.setCursorSpeed(2, 0.0);
        var targetY = app.getCursorTargetY(0);
        var expected = app.noteForLocalY(targetY);
        app.advanceTime(1.0);
        var found = false;
        while (app.hasEventBefore(app.getLogicalTime())) {
            var event = app.getNextEvent();
            if (event.type == worldofcake.EventType.NoteOn && event.data1 == app.getBaseMidiChannel()) {
                found = true;
                check("kdiag note pitch uses cursor y", event.data2 == expected);
                break;
            }
        }
        check("kdiag note pitch event generated", found);

        var restored = make(999);
        restored.importStateJson(app.exportStateJson());
        check("kdiag scale state round trip", restored.getScaleIndex() == app.getScaleIndex());
    }

    /** Each cursor's X and Y are control outputs 0..1, sent as in-range CCs on that cursor's channel. */
    static function testControlOutputs():Void {
        var app = make();
        app.setBaseMidiChannel(5);
        app.events = [];
        app.advanceTime(0.5);
        var outputs = app.getControlOutputs();
        check("kdiag six control outputs", outputs.length == 6);
        check("kdiag outputs follow cursors", Math.abs(outputs[0].published - (app.getCursorPosX(0) + 1) / 2) < 1e-9
            && Math.abs(outputs[5].published - (app.getCursorPosY(2) + 1) / 2) < 1e-9);
        var ccs = app.events.filter(e -> e.type == worldofcake.EventType.ControlChange);
        check("kdiag CCs are sent", ccs.length > 0);
        check("kdiag CC values are 7-bit", ccs.filter(e -> e.data3 < 0 || e.data3 > 127).length == 0);
        check("kdiag CCs on cursor channels", ccs.filter(e -> e.data1 < 5 || e.data1 > 7).length == 0);
        check("kdiag CC numbers are X=1, Y=2", ccs.filter(e -> e.data2 != 1 && e.data2 != 2).length == 0);
        app.newValue(KDiagramSequencer.CHANNEL_UID, 9);
        check("kdiag channel control moves outputs", outputs[0].channel == 9 && outputs[5].channel == 11);
    }

    static function testNodeTypes():Void {
        var seen = [false, false, false, false];
        for (seed in 0...12) {
            var app = make(seed);
            var valid = true;
            for (node in app.getNetwork().nodes) {
                var kind:Int = node.type;
                if (kind < 0 || kind > 3) valid = false;
                else seen[kind] = true;
            }
            check("node types in range", valid);
            var saved = app.exportStateJson();
            var restored = make(99);
            restored.importStateJson(saved);
            check("shapes survive restore", saved == restored.exportStateJson());
            var legacy:Dynamic = haxe.Json.parse(saved);
            var nodes:Array<Dynamic> = legacy.nodes;
            for (node in nodes) Reflect.deleteField(node, "type");
            restored.importStateJson(haxe.Json.stringify(legacy));
            check("old nodes default to circles", restored.getNetwork().nodes.filter(n -> n.type != kdiagram.NodeType.Circle && n.type != kdiagram.NodeType.Terminus).length == 0);
        }
        check("random generation includes all shapes", seen[0] && seen[1] && seen[2] && seen[3]);
    }

    static function testNodeSpread():Void {
        var inside = true, separated = true, covered = true;
        for (seed in 0...100) {
            var network = make(seed).getNetwork();
            var left = false, right = false, top = false, bottom = false;
            for (i in 0...network.nodes.length) {
                var p = network.nodes[i].pos;
                if (p.x*p.x + p.y*p.y > Math.pow(network.radius * 0.92, 2) + 1e-9) inside = false;
                if (p.x < -network.radius * 0.5) left = true;
                if (p.x > network.radius * 0.5) right = true;
                if (p.y < -network.radius * 0.5) top = true;
                if (p.y > network.radius * 0.5) bottom = true;
                for (j in 0...i) {
                    var q = network.nodes[j].pos;
                    if ((p.x-q.x)*(p.x-q.x) + (p.y-q.y)*(p.y-q.y) < Math.pow(kdiagram.Node.HIT_RADIUS * 2, 2)) separated = false;
                }
            }
            if (!(left && right && top && bottom)) covered = false;
        }
        check("100 seeds keep nodes within paper margin", inside);
        check("100 seeds keep node hit regions separate", separated);
        check("100 seeds spread nodes towards all four sides", covered);
    }

    static function arrivalFixture(shape:Int):KDiagramSequencer {
        var app = make();
        var state:Dynamic = haxe.Json.parse(app.exportStateJson());
        state.currentTime = 0;
        state.nodes = [
            {angle: 0, d: 0.1, type: shape, arcs: [{dest: 1, l1: 1, l2: 1, count: 0}]},
            {angle: 0, d: 0.8, type: 0, arcs: []}
        ];
        var cursors:Array<Dynamic> = state.cursors;
        for (c in cursors) { c.isMoving = false; c.waitRemaining = 0; }
        cursors[0].pos = {x: 0.0, y: 0.0};
        cursors[0].target = {x: 0.1, y: 0.0};
        cursors[0].currentNode = 0;
        cursors[0].cursorSpeed = 1.0;
        cursors[0].isMoving = true;
        app.importStateJson(haxe.Json.stringify(state));
        app.events = [];
        return app;
    }

    static function testShapeResidence():Void {
        for (shape in 0...3) {
            var app = arrivalFixture(shape);
            app.advanceTime(0.1);
            var saved:Dynamic = haxe.Json.parse(app.exportStateJson());
            var wait:Float = saved.cursors[0].waitRemaining;
            check('shape $shape residence range', shape == 0 ? wait == 0 :
                (shape == 1 ? wait >= 2 && wait <= 4 : wait >= 4 && wait <= 8));
            var ons = app.events.filter(e -> e.type == worldofcake.EventType.NoteOn);
            check('shape $shape note on arrival', ons.length == 1 && near(ons[0].timestamp, 0.1));
            var minDuration = shape == 0 ? app.getNoteLength() : (shape == 1 ? 0.5 : 1.0);
            var maxDuration = shape == 0 ? app.getNoteLength() : (shape == 1 ? 1.0 : 2.0);
            app.events = [];
            app.advanceTime(minDuration - 0.001);
            check('shape $shape note held for minimum duration', app.events.filter(e -> e.type == worldofcake.EventType.NoteOff).length == 0);
            app.advanceTime(maxDuration - minDuration + 0.002);
            var offs = app.events.filter(e -> e.type == worldofcake.EventType.NoteOff);
            check('shape $shape note duration range', offs.length == 1 &&
                offs[0].timestamp >= 0.1 + minDuration - 1e-9 && offs[0].timestamp <= 0.1 + maxDuration + 1e-9);
            if (shape != 0) {
                check('shape $shape cursor waits after note ends', near(app.getCursorPosX(0), 0.1));
                var restored = make(99);
                restored.importStateJson(app.exportStateJson());
                check('shape $shape remaining wait persists', restored.exportStateJson() == app.exportStateJson());
                app.setPaused(true);
                var pausedState = app.exportStateJson();
                app.advanceTime(1);
                check('shape $shape pause freezes wait', app.exportStateJson() == pausedState);
                app.setPaused(false);
                app.events = [];
                app.advanceTime(wait - maxDuration - 0.001);
                check('shape $shape stays through full residence', near(app.getCursorPosX(0), 0.1));
                app.advanceTime(0.002);
            }
            check('shape $shape cursor continues', app.getCursorPosX(0) > 0.1);
        }
        for (shape in 1...3) {
            var fine = arrivalFixture(shape);
            var coarse = arrivalFixture(shape);
            for (_ in 0...600) fine.advanceTime(0.01);
            coarse.advanceTime(6.0);
            check('shape $shape wait is independent of host cadence',
                near(fine.getCursorPosX(0), coarse.getCursorPosX(0)) &&
                near(fine.getCursorPosY(0), coarse.getCursorPosY(0)));
            var muted = arrivalFixture(shape);
            muted.setMuted(true);
            muted.advanceTime(0.5);
            check('shape $shape mute preserves residence without notes',
                near(muted.getCursorPosX(0), 0.1) && muted.events.length == 0);
        }
    }

    static function testTerminusToggle():Void {
        var first = new kdiagram.Network(0.9, 2, 1, 0, new SeededRandomSource(77));
        check("disabled new network still designates diamond", first.getTerminusIndex() == 0);
        check("first-node diamond exits to node one", first.nodes[0].arcs.length == 1 && first.nodes[0].arcs[0].destination == 1);
        first.setTerminusEnabled(true);
        first.setTerminusEnabled(false);
        check("first-node fallback remains stable", first.nodes[0].arcs.length == 1 && first.nodes[0].arcs[0].destination == 1);
        for (seed in 0...12) {
            var app = make(seed);
            var nodes = app.getNetwork().nodes;
            check("one terminus by default", nodes.filter(n -> n.arcs.length == 0).length == 1);
            var terminusIndex = app.getNetwork().getTerminusIndex();
            check("one designated diamond", nodes.filter(n -> n.type == kdiagram.NodeType.Terminus).length == 1);
            var untouched = haxe.Json.stringify(nodes.map(n -> n == nodes[terminusIndex] ? [] : n.arcs.map(a -> a.destination)));
            var positions = nodes.map(n -> [n.pos.x, n.pos.y, (n.type:Int)]);
            app.newValue(KDiagramSequencer.TERMINUS_UID, 0);
            check("terminus off gives every node an exit", nodes.filter(n -> n.arcs.length == 0).length == 0);
            check("diamond exit goes to first other node", nodes[terminusIndex].arcs.length == 1 &&
                nodes[terminusIndex].arcs[0].destination == (terminusIndex == 0 ? 1 : 0));
            for (_ in 0...5) { app.setTerminusEnabled(true); app.setTerminusEnabled(false); }
            check("toggle keeps designated node", app.getNetwork().getTerminusIndex() == terminusIndex);
            check("toggle keeps all other connections", untouched ==
                haxe.Json.stringify(nodes.map(n -> n == nodes[terminusIndex] ? [] : n.arcs.map(a -> a.destination))));
            check("repeat toggle restores same exit", nodes[terminusIndex].arcs.length == 1 &&
                nodes[terminusIndex].arcs[0].destination == (terminusIndex == 0 ? 1 : 0));
            check("terminus control is model backed", app.controlValue(KDiagramSequencer.TERMINUS_UID) == 0);
            var saved = app.exportStateJson();
            var restored = make(99);
            restored.importStateJson(saved);
            check("terminus preference restores", !restored.isTerminusEnabled() && restored.exportStateJson() == saved);
            restored.reset();
            check("reset respects no terminus", restored.getNetwork().nodes.filter(n -> n.arcs.length == 0).length == 0);
            app.newValue(KDiagramSequencer.TERMINUS_UID, 1);
            check("terminus on makes exactly one sink", nodes.filter(n -> n.arcs.length == 0).length == 1);
            check("toggle preserves positions and shapes", haxe.Json.stringify(positions) ==
                haxe.Json.stringify(nodes.map(n -> [n.pos.x, n.pos.y, (n.type:Int)])));
        }
        var app = arrivalFixture(0);
        app.advanceTime(2);
        check("fixture cursor reached sink", !app.getCursorIsMoving(0));
        app.setTerminusEnabled(false);
        check("removing terminus restarts stranded cursor", app.getCursorIsMoving(0));
        app.setTerminusEnabled(true);
        check("re-enabling terminus stops cursor still at diamond", !app.getCursorIsMoving(0));
        app.setTerminusEnabled(false);
        var state:Dynamic = haxe.Json.parse(app.exportStateJson());
        Reflect.deleteField(state, "terminusEnabled");
        var restored = make();
        restored.importStateJson(haxe.Json.stringify(state));
        check("legacy patch infers no terminus from topology", !restored.isTerminusEnabled());
    }

    static function testRotationDirection():Void {
        var app = arrivalFixture(0);
        // Node zero starts on the positive X axis; positive model Y is upwards on screen.
        app.buttonPressed(KDiagramSequencer.ROTATE_LEFT_UID);
        check("left button rotates anticlockwise", app.getNodePosY(0) > 0);
        app.buttonPressed(KDiagramSequencer.ROTATE_RIGHT_UID);
        check("opposite buttons undo rotation", near(app.getNodePosX(0), 0.1) && near(app.getNodePosY(0), 0));
        app.buttonPressed(KDiagramSequencer.ROTATE_RIGHT_UID);
        check("right button rotates clockwise", app.getNodePosY(0) < 0);
        app.keyPressed(KDiagramSequencer.PLAY_AREA_UID, "[");
        check("keyboard matches button rotation", near(app.getNodePosY(0), 0));
    }

    public static function main():Void {
        testRotationDirection();
        testTerminusToggle();
        testShapeResidence();
        testNodeSpread();
        testNodeTypes();
        testSeedAndCadence();
        testControlsPauseState();
        testNodeClickRestartsSelectedCursor();
        testSemanticCursorSelection();
        testScaleAndNotePitch();
        testControlOutputs();
        if (failures > 0) { Sys.println('$failures K-Diag headless test(s) failed'); Sys.exit(1); }
        Sys.println("All K-Diag headless tests passed");
    }
}
