package test;

import haxe.Json;
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
        var firstCorrectionKey = sequencer.getCorrectionKey(0.0);
        check(firstCorrectionKey >= 0, "correction key is valid at loop start");
        check(sequencer.getCorrectionKey(0.5) == firstCorrectionKey, "correction key is stable within a chord");
        check(sequencer.getCorrectionKey(2.0) != firstCorrectionKey, "correction key changes at a chord boundary");
        check(sequencer.makeCorrectionTable(0.0).length == 128, "neutral correction table has 128 entries");
        check(sequencer.makeBidirectionalCorrectionTable(0.0).length == 256, "bidirectional table has two 128-note columns");
        data.setCorrectionTarget(2);
        check(sequencer.getCorrectionKey(0.0) != firstCorrectionKey, "correction key changes when the target changes");
        sequencer.newValue(generated.goldenpond.GoldenpondControlIdsGenerated.CORRECTIONTARGET, 3);
        check(sequencer.getCorrectionTarget() == 3, "semantic correction-target control updates the project");
        sequencer.newValue(generated.goldenpond.GoldenpondControlIdsGenerated.KEYSELECT, 7);
        sequencer.newValue(generated.goldenpond.GoldenpondControlIdsGenerated.MODESELECT, 2);
        check(sequencer.getKeyIndex() == 7, "semantic key control updates the project root");
        check(sequencer.getModeIndex() == 2, "semantic scale control updates the project mode");
        sequencer.advanceTime(0.01);
        check(sequencer.hasEventBefore(1.0), "WoC sequencer exposes compiled note events");
        var looping = new GoldenpondSequencer(data);
        looping.advanceTime(9.0);
        check(looping.getPositionTicks() > snapshot.loopLengthTicks, "Goldenpond playback continues beyond one complete loop");
        var synced = new GoldenpondSequencer(data);
        synced.resyncTime(1.0);
        check(synced.getLogicalTime() == 1.0, "sequencer resync advances to authoritative host time");
        synced.resyncTime(1.0);
        check(synced.getLogicalTime() == 1.0, "repeated host time does not advance twice");
        synced.resyncTime(0.5);
        check(synced.getLogicalTime() == 1.0, "resync ignores a time earlier than the current timeline");
        var saved = sequencer.exportStateJson();
        var restored = new GoldenpondSequencer();
        restored.importStateJson(saved);
        check(restored.project.chordSequence == data.chordSequence, "sequencer persistence restores project text");
        check(restored.getCorrectionTarget() == 3, "sequencer persistence restores correction target");
        check(restored.getKeyIndex() == 7, "sequencer persistence restores the initial key");
        check(restored.getModeIndex() == 2, "sequencer persistence restores the scale");
        sequencer.textSubmitted(2, "62 71");
        var editedSave:Dynamic = Json.parse(sequencer.exportStateJson());
        var editedProject:Dynamic = Json.parse(editedSave.project);
        check(editedProject.chordSequence == "62 71", "save after edit exports fresh project JSON before recompilation");

        if (errors == 0) trace("All Goldenpond compiler tests passed!");
        else trace(errors + " Goldenpond compiler tests failed");
    }
}
