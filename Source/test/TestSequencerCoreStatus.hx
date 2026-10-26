package test;

import worldofcake.SequencerCore;
import worldofcake.ISequencer;
import worldofcake.LocalPoint;
import gbloink.Gbloink;

class TestSequencerCoreStatus {
    static var errors:Int = 0;

    static function check(condition:Bool, message:String):Void {
        if (!condition) {
            trace("ERROR: " + message);
            errors++;
        }
    }

    static function main():Void {
        var sequencer = new Gbloink(new LocalPoint(700, 500));
        // Keep the variable interface-typed so these checks also verify that
        // the public ISequencer contract exposes the shared state methods.
        var contract:ISequencer = sequencer;
        check(!contract.isPaused(), "new sequencer is not paused");
        check(!contract.isMuted(), "new sequencer is not muted");
        contract.setPaused(true);
        check(contract.isPaused(), "pause is observable through ISequencer");
        sequencer.emitEvent(new worldofcake.Event(0, worldofcake.EventType.ControlChange, 2, 3, 4));
        check(sequencer.events.length == 0, "paused sequencer does not queue events");
        contract.setPaused(false);
        check(!contract.isPaused(), "resume is observable through ISequencer");
        sequencer.emitEvent(new worldofcake.Event(0, worldofcake.EventType.ControlChange, 2, 3, 4));
        check(sequencer.events.length == 1, "running sequencer queues events");
        contract.setMuted(true);
        check(contract.isMuted(), "mute is observable through ISequencer");
        check(sequencer.events.length == 0, "entering mute flushes queued events");
        sequencer.emitEvent(new worldofcake.Event(0, worldofcake.EventType.ControlChange, 2, 3, 4));
        check(sequencer.events.length == 0, "muted sequencer does not queue events");
        contract.setMuted(false);
        check(!contract.isMuted(), "unmute is observable through ISequencer");
        // Panels present lifecycle flags from the model and change them through newValue.
        var pauseUid = generated.gbloink.GbloinkControlIdsGenerated.PAUSE;
        var muteUid = generated.gbloink.GbloinkControlIdsGenerated.MUTE;
        check(sequencer.controlValue(pauseUid) == 0.0, "pause control reads the model");
        sequencer.newValue(pauseUid, 1.0);
        check(contract.isPaused() && sequencer.controlValue(pauseUid) == 1.0, "pause control sets the model");
        contract.setPaused(false);
        check(sequencer.controlValue(pauseUid) == 0.0, "pause control follows model changes");
        sequencer.newValue(muteUid, 1.0);
        check(contract.isMuted() && sequencer.controlValue(muteUid) == 1.0, "mute control sets the model");
        contract.setMuted(false);
        check(sequencer.controlValue(muteUid) == 0.0, "mute control follows model changes");
        check(sequencer.controlValue(generated.gbloink.GbloinkControlIdsGenerated.REDSPEED) == null, "other controls are not model-backed");
        check(contract.isTransportRunning(), "new sequencer transport is running");
        contract.setTransportRunning(false);
        check(!contract.isTransportRunning(), "transport stop is observable through ISequencer");
        check(!contract.isPaused(), "transport stop does not imply explicit pause");
        contract.setTransportRunning(true);
        check(contract.isTransportRunning(), "transport restart is observable through ISequencer");
        check(!contract.isPaused(), "transport restart does not change explicit pause");
        var first = sequencer.getModelStatus();
        var second = sequencer.getModelStatus();
        check(first.ready, "new sequencer is ready");
        check(first.stateRevision == 1, "initial state revision");
        check(first == second, "model status reference is cached");

        sequencer.markStateReplaced();
        check(sequencer.getModelStatus() == first, "status reference remains stable");
        check(first.stateRevision == 2, "state replacement increments revision");

        testNotes();
        testControlOutput();

        if (errors == 0) trace("All SequencerCore status tests passed!");
        else trace(errors + " SequencerCore status tests failed");
    }

    /** A control output sends a CC only when its 7-bit value changes, and only while output is open. */
    static function testControlOutput():Void {
        var output = new worldofcake.ControlOutput("x", "X", 3, 7);
        check(output.update(0.5, true) == 64, "first value is sent");
        check(output.update(0.501, true) == -1, "same 7-bit value is not resent");
        check(output.update(2.0, true) == 127 && output.value == 1.0, "values clamp to 0..1");
        check(output.update(Math.NaN, true) == -1 && output.value == 1.0, "invalid values are ignored");
        check(output.update(0.0, false) == -1 && output.value == 0.0 && output.published == 1.0,
            "closed output records the value but publishes nothing");
        check(output.update(0.0, true) == 0 && output.published == 0.0, "reopened output publishes and sends");
        output.forgetSent();
        check(output.update(0.0, true) == 0, "after a boundary the value is resent");
        output.setChannel(20);
        check(output.channel == 16 && output.update(0.0, true) == 0, "a new channel clamps and resends");
    }

    /** Consume every queued event, as a host would. */
    static function drain(app:Gbloink):Void {
        while (app.hasEventBefore(1e12)) app.getNextEvent();
    }

    static function countType(events:Array<worldofcake.Event>, type:Int):Int {
        var n = 0;
        for (e in events) if (e.type == type) n++;
        return n;
    }

    /** Every note-on gets a model-scheduled note-off; output boundaries release pending notes. */
    static function testNotes():Void {
        var app = new Gbloink(new LocalPoint(700, 500));
        app.emitNote(0, 1, 60, 100, 0.05);
        check(app.events.length == 1 && app.events[0].type == worldofcake.EventType.NoteOn, "emitNote queues the note-on now");
        app.advanceTime(0.04);
        check(app.events.length == 1, "note-off waits for its duration");
        app.advanceTime(0.02);
        check(app.events.length == 2 && app.events[1].type == worldofcake.EventType.NoteOff && Math.abs(app.events[1].timestamp - 0.05) < 1e-9,
            "note-off released at note-on time + duration");
        drain(app);

        app.emitNote(app.getLogicalTime(), 1, 62, 100, 0.05);
        drain(app); // the note-on reaches the host, so the note is sounding
        app.setPaused(true);
        check(countType(app.events, 2) == 1 && app.events[app.events.length - 1].data2 == 62, "pause releases a sounding note");
        app.setPaused(false);
        drain(app);
        app.advanceTime(0.1);
        check(app.events.length == 0, "a released note gets no stray note-off");

        var t = app.getLogicalTime();
        app.emitNote(t, 1, 64, 100, 0.05);
        app.emitNote(t + 0.01, 1, 64, 100, 0.05);
        app.advanceTime(0.2);
        check(countType(app.events, 0) == 2 && countType(app.events, 2) == 2, "a retriggered note ends the earlier one");
        drain(app);
        app.emitNote(app.getLogicalTime(), 2, 70, 100, 0.05);
        drain(app);
        app.resetTransport();
        check(app.hasEventBefore(0) && app.events[app.events.length - 1].type == worldofcake.EventType.NoteOff && app.events[app.events.length - 1].timestamp == 0,
            "transport reset releases sounding notes at the new time origin");
        drain(app);
        app.emitEvent(new worldofcake.Event(app.getLogicalTime(), worldofcake.EventType.NoteOff, 3, 40, 0));
        check(app.events.length == 0, "a note-off for a note that is not sounding is dropped");
        // Boundaries keep queued releases and forget undelivered note-ons.
        drain(app);
        app.emitNote(app.getLogicalTime(), 1, 50, 100, 0.01);
        drain(app);                       // note-on delivered
        app.advanceTime(0.05);            // note-off released into the queue, not yet delivered
        app.setPaused(true);
        check(countType(app.events, 2) == 1 && app.events[0].data2 == 50, "pause keeps a queued note-off");
        app.setPaused(false);
        drain(app);
        app.emitEvent(new worldofcake.Event(app.getLogicalTime(), worldofcake.EventType.NoteOn, 1, 52, 100)); // queued, never delivered
        app.setMuted(true);
        check(app.events.length == 0, "an undelivered note-on gets no note-off at a boundary");
    }
}
