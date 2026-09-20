package test;

import goldenpond.GoldenpondScoreCompiler;
import goldenpond.GoldenpondSequencer;
import GoldenData;
import TimedSequence.MidiInstrumentContext;

class TestGoldenpondScoreCompiler {
    static var errors:Int = 0;

    static function check(condition:Bool, message:String):Void {
        if (!condition) {
            trace("ERROR: " + message);
            errors++;
        }
    }

    public static function main():Void {
        var data = new GoldenData();
        data.root = 60;
        data.chordSequence = "62 72 5ii 71";
        data.chordDuration = 4;
        data.ppq = 960;
        data.addLine("3%8 > 2", new MidiInstrumentContext(0, 73, 1.0, 0));
        data.addLine("1.1.Cr 2", new MidiInstrumentContext(1, 91, 0.8, 0));

        var snapshot = GoldenpondScoreCompiler.compile(data);
        check(snapshot.loopLengthTicks == 15360, "loop length is chord ticks times chord count");
        check(snapshot.notes.length > 0, "compiled notes are present");
        if (snapshot.notes.length > 0) {
            check(snapshot.notes[0].partId == 0, "first line becomes part zero");
            check(snapshot.notes[0].velocity == 73, "first line velocity comes from instrument context");
        }
        var sawSecondPart = false;
        var sawSecondVelocity = false;
        for (note in snapshot.notes) {
            if (note.partId == 1) {
                sawSecondPart = true;
                if (note.velocity == 91) sawSecondVelocity = true;
            }
        }
        check(sawSecondPart, "second rhythm line becomes part one");
        check(sawSecondVelocity, "second line velocity comes from instrument context");

        var sequencer = new GoldenpondSequencer(data);
        check(sequencer.getCorrectionChordIndex(0) == 0, "correction starts on first chord");
        check(sequencer.getCorrectionChordIndex(2.0) == 1, "correction advances at chord duration");
        check(sequencer.getCorrectionChordIndex(8.0) == 0, "correction chord index wraps with progression");
        sequencer.advanceTime(0.01);
        check(sequencer.hasEventBefore(1.0), "WoC sequencer exposes compiled note events");
        var looping = new GoldenpondSequencer(data);
        looping.advanceTime(9.0);
        check(looping.getPositionTicks() > snapshot.loopLengthTicks, "Goldenpond playback continues beyond one complete loop");
        var saved = sequencer.exportStateJson();
        var restored = new GoldenpondSequencer();
        restored.importStateJson(saved);
        check(restored.project.chordSequence == data.chordSequence, "sequencer persistence restores project text");

        if (errors == 0) trace("All Goldenpond compiler tests passed!");
        else trace(errors + " Goldenpond compiler tests failed");
    }
}
