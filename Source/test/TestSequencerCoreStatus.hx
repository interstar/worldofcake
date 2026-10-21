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
        contract.pause();
        check(contract.isPaused(), "pause is observable through ISequencer");
        sequencer.emitEvent(new worldofcake.Event(0, 1, 2, 3, 4));
        check(sequencer.events.length == 0, "paused sequencer does not queue events");
        contract.resume();
        check(!contract.isPaused(), "resume is observable through ISequencer");
        sequencer.emitEvent(new worldofcake.Event(0, 1, 2, 3, 4));
        check(sequencer.events.length == 1, "running sequencer queues events");
        sequencer.setMuted(true);
        check(contract.isMuted(), "mute is observable through ISequencer");
        check(sequencer.events.length == 0, "entering mute flushes queued events");
        sequencer.emitEvent(new worldofcake.Event(0, 1, 2, 3, 4));
        check(sequencer.events.length == 0, "muted sequencer does not queue events");
        sequencer.setMuted(false);
        check(!contract.isMuted(), "unmute is observable through ISequencer");
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

        if (errors == 0) trace("All SequencerCore status tests passed!");
        else trace(errors + " SequencerCore status tests failed");
    }
}
