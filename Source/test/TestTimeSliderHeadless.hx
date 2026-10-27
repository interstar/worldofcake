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
        check("timeslider moved", fine.getSliders()[0].current < fine.getSliders()[0].bounds.height() / 2);
    }

    static function testPauseAndInvalidDelta():Void {
        var app = make();
        clickFirst(app);
        var before = app.getSliders()[0].current;
        app.setPaused(true);
        app.advanceTime(1.0);
        check("timeslider pause", near(app.getSliders()[0].current, before));
        app.setPaused(false);
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

    /** Each lane sends its CCs on its own MIDI channel, kept across save/restore and reset. */
    static function testChannels():Void {
        var app = make();
        check("timeslider default channels", [for (i in 0...4) app.getChannel(i)].join(",") == "1,1,1,1");
        app.newValue(TimeSliderSequencer.channelUid(1), 10);
        app.newValue(TimeSliderSequencer.channelUid(2), 40);
        check("timeslider channel set", app.getChannel(1) == 10);
        check("timeslider channel clamped", app.getChannel(2) == 16);
        app.events = [];
        app.mouseDown(app.getSliders()[1].uid, new LocalPoint(176, 52));
        app.advanceTime(0.05);
        var lane = app.getControlOutputs()[1];
        var ccs = [for (e in app.events) if (e.type == worldofcake.EventType.ControlChange && e.data2 == lane.ccNumber) e];
        check("timeslider CC sent on lane channel", ccs.length > 0 && ccs.filter(e -> e.data1 != 10).length == 0);
        var values = [for (e in ccs) e.data3];
        check("timeslider CC only when the 7-bit value changes", [for (i in 1...values.length) if (values[i] == values[i - 1]) i].length == 0);
        check("timeslider output follows the lane", Math.abs(lane.published - app.getSliders()[1].normalizedValue()) < 1e-9);
        var restored = make();
        restored.importStateJson(app.exportStateJson());
        check("timeslider channel restored", restored.getChannel(1) == 10 && restored.getChannel(2) == 16);
        app.reset();
        check("timeslider reset keeps channels", app.getChannel(1) == 10 && app.getChannel(2) == 16);
    }

    /** Each lane's CC number and label are the user's; both are saved and survive reset. */
    static function testCcNumbersAndLabels():Void {
        var app = make();
        check("timeslider default CC numbers", [for (i in 0...4) app.getCcNumber(i)].join(",") == "1,2,3,4");
        app.newValue(TimeSliderSequencer.ccUid(0), 74);
        app.newValue(TimeSliderSequencer.ccUid(3), 300);
        check("timeslider CC number set", app.getCcNumber(0) == 74);
        check("timeslider CC number clamped", app.getCcNumber(3) == 127);
        app.textSubmitted(TimeSliderSequencer.labelUid(2), 'Filter "cutoff"');
        app.events = [];
        clickFirst(app);
        app.advanceTime(0.05);
        check("timeslider sends the chosen CC number",
            app.events.filter(e -> e.type == worldofcake.EventType.ControlChange && e.data2 == 74).length > 0);
        var restored = make();
        restored.importStateJson(app.exportStateJson());
        check("timeslider CC number restored", restored.getCcNumber(0) == 74 && restored.getCcNumber(3) == 127);
        check("timeslider label restored", restored.getLabel(2) == 'Filter "cutoff"' && restored.getLabel(0) == "");
        app.reset();
        check("timeslider reset keeps CC numbers and labels", app.getCcNumber(0) == 74 && app.getLabel(2) == 'Filter "cutoff"');
    }

    /** Muting holds the published value and sends nothing; unmuting resumes from the live value. */
    static function testMutedOutputs():Void {
        var app = make();
        clickFirst(app);
        app.advanceTime(0.02);
        var lane = app.getControlOutputs()[0];
        var held = lane.published;
        app.setMuted(true);
        app.advanceTime(0.05);
        check("timeslider muted output holds", lane.published == held && lane.value != held);
        check("timeslider muted output sends no CC", app.events.filter(e -> e.type == worldofcake.EventType.ControlChange).length == 0);
        app.setMuted(false);
        app.advanceTime(0.01);
        check("timeslider unmuted output resumes", lane.published == lane.value
            && app.events.filter(e -> e.type == worldofcake.EventType.ControlChange).length > 0);
    }

    public static function main():Void {
        testCadence();
        testPauseAndInvalidDelta();
        testStateRoundTrip();
        testChannels();
        testCcNumbersAndLabels();
        testMutedOutputs();
        if (failures > 0) {
            Sys.println('$failures TimeSlider headless test(s) failed');
            Sys.exit(1);
        }
        Sys.println("All TimeSlider headless tests passed");
    }
}
