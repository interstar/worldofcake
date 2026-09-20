package test;

import worldofcake.LoopingNotePlayer;
import worldofcake.SequenceNote;
import worldofcake.SequenceNoteEvent;
import worldofcake.SequenceSnapshot;

class TestSequencePlayerHeadless {
    static var errors:Int = 0;

    static function check(condition:Bool, message:String):Void {
        if (!condition) {
            trace("ERROR: " + message);
            errors++;
        }
    }

    static function main():Void {
        var snapshot = new SequenceSnapshot(100, [
            new SequenceNote(0, 60, 0, 150, 100),
            new SequenceNote(1, 64, 40, 10, 80)
        ]);
        var player = new LoopingNotePlayer(snapshot);
        check(player.getLoopLengthTicks() == 100, "loop length");

        check(player.hasEventBefore(0), "initial note-on is available");
        var first = player.getNextEvent();
        check(first.type == SequenceNoteEvent.NOTE_ON && first.pitch == 60, "initial note-on");

        player.advanceTicks(100);
        var sawLoopStart = false;
        var sawLongNoteOff = false;
        while (player.hasEventBefore(100)) {
            var event = player.getNextEvent();
            if (event.timestampTicks == 100 && event.type == SequenceNoteEvent.NOTE_ON && event.pitch == 60) sawLoopStart = true;
            if (event.timestampTicks == 50 && event.type == SequenceNoteEvent.NOTE_OFF && event.pitch == 64) sawLongNoteOff = true;
        }
        check(sawLoopStart, "note repeats at loop boundary");
        check(sawLongNoteOff, "short note-off is scheduled");

        var replacement = new SequenceSnapshot(80, [new SequenceNote(2, 67, 0, 5, 90)]);
        player.publish(replacement, 150);
        player.advanceTicks(100);
        var sawOldLongOff = false;
        var sawReplacement = false;
        while (player.hasEventBefore(200)) {
            var event = player.getNextEvent();
            if (event.pitch == 60 && event.type == SequenceNoteEvent.NOTE_OFF && event.timestampTicks == 150) sawOldLongOff = true;
            if (event.pitch == 67 && event.type == SequenceNoteEvent.NOTE_ON && event.timestampTicks == 150) sawReplacement = true;
        }
        check(sawOldLongOff, "old snapshot note-off survives replacement");
        check(sawReplacement, "replacement starts at requested boundary");

        player.stop();
        check(!player.isRunning(), "stop");
        if (errors == 0) trace("All sequence-player tests passed!");
        else trace(errors + " sequence-player tests failed");
    }
}
