package worldofcake;

/** A complete compiled score ready for publication to a LoopingNotePlayer. */
class SequenceSnapshot {
    public var loopLengthTicks:Float;
    public var notes:Array<SequenceNote>;

    public function new(loopLengthTicks:Float, notes:Array<SequenceNote>) {
        if (!Math.isFinite(loopLengthTicks) || loopLengthTicks <= 0) {
            throw "SequenceSnapshot loopLengthTicks must be finite and positive";
        }
        this.loopLengthTicks = loopLengthTicks;
        this.notes = notes == null ? [] : notes.copy();
        for (note in this.notes) {
            if (note == null) throw "SequenceSnapshot cannot contain null notes";
            if (note.startTick >= loopLengthTicks) {
                throw "SequenceNote startTick must be inside the snapshot loop";
            }
        }
        this.notes.sort(function(a:SequenceNote, b:SequenceNote):Int {
            if (a.startTick < b.startTick) return -1;
            if (a.startTick > b.startTick) return 1;
            if (a.partId < b.partId) return -1;
            if (a.partId > b.partId) return 1;
            return a.pitch - b.pitch;
        });
    }
}
