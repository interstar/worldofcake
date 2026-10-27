package test;

import gbloink.Gbloink;
import kdiagram.KDiagramSequencer;
import tileland.TileLandSequencer;
import timeslider.TimeSliderSequencer;
import zewp.ZewpSequencer;
import worldofcake.ISequencer;
import worldofcake.LocalPoint;
import worldofcake.SeededRandomSource;
import generated.timeslider.TimeSliderControlIdsGenerated;

/**
    Speeds are defined in real time: the same simulated second must give the same
    result whether a host ticks every millisecond (OpenFL, VST), every 1/60 s
    (Rack) or every 100 ms, so a knob means the same speed on every platform.
**/
class TestRealTime {
    static var errors:Int = 0;
    static var STEPS = [0.001, 1.0 / 60.0, 0.1];

    static function check(condition:Bool, message:String):Void {
        if (!condition) {
            trace("ERROR: " + message);
            errors++;
        }
    }

    static function run(model:ISequencer, seconds:Float, step:Float):Void {
        var t = 0.0;
        while (t < seconds - 1e-9) {
            var dt = Math.min(step, seconds - t);
            model.advanceTime(dt);
            t += dt;
        }
    }

    /** Runs a fresh model at each host step size and compares the fingerprints. */
    static function sameAtEveryStep(label:String, make:Void->ISequencer, fingerprint:ISequencer->Array<Float>, tolerance:Float):Void {
        var reference:Array<Float> = null;
        for (step in STEPS) {
            var model = make();
            run(model, 1.0, step);
            check(Math.abs(model.getLogicalTime() - 1.0) < 1e-9, label + ": one second of model time at step " + step);
            var print = fingerprint(model);
            if (reference == null) {
                reference = print;
                continue;
            }
            var worst = 0.0;
            for (i in 0...print.length) worst = Math.max(worst, Math.abs(print[i] - reference[i]));
            check(worst <= tolerance, label + ": step " + step + " differs from 1 ms by " + worst);
        }
    }

    static function main():Void {
        sameAtEveryStep("gbloink", function() {
            var g = new Gbloink(new LocalPoint(700, 500), new SeededRandomSource(7));
            g.mouseDown(Gbloink.PLAY_AREA_UID, new LocalPoint(300, 260)); // a block to collide with
            return g;
        }, function(m) {
            var g:Gbloink = cast m;
            return [for (b in g.balls) for (v in [b.pos.x, b.pos.y]) v];
        }, 0.5);

        sameAtEveryStep("zewp", function() return new ZewpSequencer(600, 560, new SeededRandomSource(7)), function(m) {
            var z:ZewpSequencer = cast m;
            return [for (a in z.getZewps()) for (v in [a.position.x, a.position.y]) v];
        }, 2.0);

        sameAtEveryStep("tileland", function() return new TileLandSequencer(new SeededRandomSource(7)), function(m) {
            var t:TileLandSequencer = cast m;
            return [for (c in t.getCursors()) for (v in [c.position.x, c.position.y]) v];
        }, 1e-6);

        sameAtEveryStep("kdiagram", function() return new KDiagramSequencer(new SeededRandomSource(7)), function(m) {
            var k:KDiagramSequencer = cast m;
            return [for (i in 0...3) for (v in [k.getCursorPosX(i), k.getCursorPosY(i)]) v];
        }, 1e-6);

        sameAtEveryStep("timeslider", function() {
            var s = new TimeSliderSequencer(800, 600, 120, 0.5);
            var track = s.getSliders()[0];
            s.mouseDown(TimeSliderControlIdsGenerated.LANE1TRACK, new LocalPoint(track.bounds.width() * 0.8, track.bounds.height() * 0.2));
            return s;
        }, function(m) {
            var s:TimeSliderSequencer = cast m;
            return [for (t in s.getSliders()) t.current];
        }, 1e-6);

        // Absolute speed: a ball at the default knob setting covers its speed in one second.
        var g = new Gbloink(new LocalPoint(700, 500), new SeededRandomSource(7));
        var ball = g.balls[0];
        var x0 = ball.pos.x, y0 = ball.pos.y;
        run(g, 1.0, 1.0 / 60.0);
        var travelled = Math.sqrt(Math.pow(ball.pos.x - x0, 2) + Math.pow(ball.pos.y - y0, 2));
        check(Math.abs(travelled - Gbloink.DEFAULT_BALL_SPEED) < 1.0, "gbloink default ball travels its speed per second, got " + travelled);

        // Absolute time: a TimeSlider glide takes its travel time in real seconds.
        var slider = new TimeSliderSequencer(800, 600, 120, 0.5);
        var track = slider.getSliders()[0];
        slider.mouseDown(TimeSliderControlIdsGenerated.LANE1TRACK, new LocalPoint(track.bounds.width(), track.bounds.height() * 0.1));
        var arrived = -1.0;
        var t = 0.0;
        while (t < 10 && arrived < 0) {
            slider.advanceTime(1.0 / 60.0);
            t += 1.0 / 60.0;
            if (!track.moving) arrived = t;
        }
        check(arrived > 0 && arrived <= 0.5 + 1.0 / 60.0 + 1e-9, "fastest TimeSlider glide arrives within its 0.5 s travel time, got " + arrived);

        if (errors == 0) trace("All real-time consistency tests passed!");
        else trace(errors + " real-time consistency tests failed");
    }
}
