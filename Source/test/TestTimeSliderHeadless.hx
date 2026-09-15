package test;

import timeslider.TimeSliderSequencer;
import worldofcake.LocalPoint;

class TestTimeSliderHeadless {
    static var failures = 0;

    static function check(name:String, condition:Bool):Void {
        Sys.println((condition ? "PASS " : "FAIL ") + name);
        if (!condition) failures++;
    }

    static function near(a:Float, b:Float, epsilon:Float = 0.000001):Bool {
        return Math.abs(a - b) <= epsilon;
    }

    static function make():TimeSliderSequencer {
        return new TimeSliderSequencer(800, 600, 120, 0.5);
    }

    static function clickFirst(app:TimeSliderSequencer):Void {
        app.mouseDown(app.getSliders()[0].uid, new LocalPoint(176, 52));
    }

    static function testCadence():Void {
        var fine = make();
        var coarse = make();
        clickFirst(fine);
        clickFirst(coarse);
        for (_ in 0...100) fine.advanceTime(0.001);
        for (_ in 0...10) coarse.advanceTime(0.01);
        check("timeslider cadence current", near(fine.getSliders()[0].current, coarse.getSliders()[0].current));
        check("timeslider cadence logical time", near(fine.getLogicalTime(), coarse.getLogicalTime()));
        check("timeslider moved", fine.getSliders()[0].current < 252.0);
    }

    static function testPauseAndInvalidDelta():Void {
        var app = make();
        clickFirst(app);
        var before = app.getSliders()[0].current;
        app.pause();
        app.advanceTime(1.0);
        check("timeslider pause", near(app.getSliders()[0].current, before));
        app.resume();
        app.advanceTime(-1.0);
        app.advanceTime(Math.NaN);
        check("timeslider invalid delta", near(app.getSliders()[0].current, before));
    }

    static function testStateRoundTrip():Void {
        var source = make();
        clickFirst(source);
        source.advanceTime(0.25);
        var restored = make();
        restored.importStateJson(source.exportStateJson());
        check("timeslider state current", near(source.getSliders()[0].current, restored.getSliders()[0].current));
        check("timeslider state destination", near(source.getSliders()[0].destination, restored.getSliders()[0].destination));
        check("timeslider state logical time", near(source.getLogicalTime(), restored.getLogicalTime()));
    }

    public static function main():Void {
        testCadence();
        testPauseAndInvalidDelta();
        testStateRoundTrip();
        if (failures > 0) {
            Sys.println('$failures TimeSlider headless test(s) failed');
            Sys.exit(1);
        }
        Sys.println("All TimeSlider headless tests passed");
    }
}
