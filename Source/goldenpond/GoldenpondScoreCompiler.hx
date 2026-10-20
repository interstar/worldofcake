package goldenpond;

import haxe.Json;
import worldofcake.SequenceNote;
import worldofcake.SequenceSnapshot;
import GoldenData;
import ScoreUtilities.INote;

/** Converts Goldenpond's object model into WoC's plain score snapshot. */
class GoldenpondScoreCompiler {
    public static function chordLengthTicks(data:GoldenData):Float {
        if (data == null) throw "Goldenpond data cannot be null";
        var chords = data.makeChordProgression().toChordThings();
        if (chords == null || chords.length == 0) return 0.0;
        return data.makeTimeManipulator().chordTicks;
    }

    public static function compile(data:GoldenData):SequenceSnapshot {
        if (data == null) throw "Goldenpond data cannot be null";

        var time = data.makeTimeManipulator();
        var chords = data.makeChordProgression().toChordThings();
        // An empty progression is a valid editing state.  It lets the UI accept
        // rhythm patterns before the user chooses a chord progression and
        // publishes an empty score until chords are supplied.
        if (chords == null || chords.length == 0)
            return new SequenceSnapshot(1.0, []);

        var notes:Array<SequenceNote> = [];
        for (partId in 0...data.lines.length) {
            var line = data.lines[partId];
            var velocity = velocityFrom(line.instrumentContext);
            var generated:Array<INote> = data.makeLineGenerator(partId).generateNotes(0);
            for (note in generated) {
                notes.push(new SequenceNote(
                    partId,
                    note.getMidiNoteValue(),
                    note.getStartTime(),
                    note.getLength(),
                    velocity
                ));
            }
        }

        return new SequenceSnapshot(time.chordTicks * chords.length, notes);
    }

    private static function velocityFrom(context:Dynamic):Int {
        // Goldenpond's INote exposes pitch/time; its current context serializes
        // the constant velocity used for the whole part.
        if (context == null) return 100;
        try {
            var value:Dynamic = Json.parse(context.toJSON()).velocity;
            var velocity = Std.int(value);
            return velocity < 0 ? 0 : (velocity > 127 ? 127 : velocity);
        } catch (_:Dynamic) {
            return 100;
        }
    }
}
