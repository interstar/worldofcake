package worldofcake;

/**
 * UI- and Goldenpond-independent playback model for one looping multi-part
 * score. A compiler chooses the publication boundary; this class never thinks
 * in terms of chords or other higher-level musical structure.
 */
class LoopingNotePlayer {
    private var snapshot:SequenceSnapshot;
    private var pendingSnapshot:Null<SequenceSnapshot>;
    private var pendingApplyTick:Float;
    private var events:Array<SequenceNoteEvent>;
    private var activeNotes:Array<ActiveSequenceNote>;
    private var absoluteTick:Float;
    private var snapshotOriginTick:Float;
    private var active:Bool;

    public function new(?initialSnapshot:SequenceSnapshot) {
        events = [];
        activeNotes = [];
        absoluteTick = 0;
        snapshotOriginTick = 0;
        active = true;
        snapshot = initialSnapshot == null ? new SequenceSnapshot(1, []) : initialSnapshot;
        pendingSnapshot = null;
        pendingApplyTick = 0;
        emitStartsAt(0);
    }

    public function getPositionTicks():Float return absoluteTick;
    public function getSnapshot():SequenceSnapshot return snapshot;
    public function getLoopPositionTicks():Float return positiveModulo(absoluteTick - snapshotOriginTick, snapshot.loopLengthTicks);
    public function getLoopLengthTicks():Float return snapshot.loopLengthTicks;
    public function isRunning():Bool return active;

    public function start():Void {
        if (active) return;
        active = true;
        emitStartsAt(absoluteTick);
    }

    public function stop():Void {
        if (!active) return;
        emitAllNotesOff(absoluteTick);
        active = false;
    }

    public function reset():Void {
        emitAllNotesOff(absoluteTick);
        events = [];
        activeNotes = [];
        absoluteTick = 0;
        snapshotOriginTick = 0;
        pendingSnapshot = null;
        active = true;
        emitStartsAt(0);
    }

    /** Publish a complete score for application at an absolute tick boundary. */
    public function publish(next:SequenceSnapshot, applyAtTick:Float):Void {
        if (next == null) throw "LoopingNotePlayer cannot publish a null snapshot";
        if (!Math.isFinite(applyAtTick) || applyAtTick < absoluteTick) {
            throw "LoopingNotePlayer publication tick must be finite and not in the past";
        }
        if (applyAtTick == absoluteTick) {
            applySnapshot(next);
        } else {
            pendingSnapshot = next;
            pendingApplyTick = applyAtTick;
        }
    }

    /** Advance in musical ticks. Nothing is scheduled while stopped. */
    public function advanceTicks(deltaTicks:Float):Void {
        if (!active || !Math.isFinite(deltaTicks) || deltaTicks <= 0) return;
        var target = absoluteTick + deltaTicks;
        while (pendingSnapshot != null && pendingApplyTick <= target) {
            emitRange(absoluteTick, pendingApplyTick);
            absoluteTick = pendingApplyTick;
            var replacement = pendingSnapshot;
            pendingSnapshot = null;
            applySnapshot(replacement);
        }
        emitRange(absoluteTick, target);
        absoluteTick = target;
    }

    public function hasEventBefore(timeLimitTicks:Float):Bool {
        return events.length > 0 && events[0].timestampTicks <= timeLimitTicks;
    }

    public function getNextEvent():SequenceNoteEvent {
        return events.shift();
    }

    private function applySnapshot(next:SequenceSnapshot):Void {
        var oldLoopLength = snapshot.loopLengthTicks;
        var loopPhase = getLoopPositionTicks();
        var nextPhase = oldLoopLength > 0
            ? loopPhase / oldLoopLength * next.loopLengthTicks
            : 0.0;
        snapshot = next;
        snapshotOriginTick = absoluteTick - nextPhase;
        if (active) emitStartsAt(absoluteTick);
    }

    private function emitStartsAt(time:Float):Void {
        var loopIndex = Math.floor((time - snapshotOriginTick) / snapshot.loopLengthTicks);
        var loopStart = snapshotOriginTick + loopIndex * snapshot.loopLengthTicks;
        for (note in snapshot.notes) {
            if (Math.abs(loopStart + note.startTick - time) < 0.000001) {
                emitStart(time, note);
            }
        }
    }

    private function emitRange(startExclusive:Float, endInclusive:Float):Void {
        if (endInclusive <= startExclusive) return;
        var firstLoop = Math.floor((startExclusive - snapshotOriginTick) / snapshot.loopLengthTicks) - 1;
        var lastLoop = Math.floor((endInclusive - snapshotOriginTick) / snapshot.loopLengthTicks) + 1;
        for (loopIndex in firstLoop...lastLoop + 1) {
            var loopStart = snapshotOriginTick + loopIndex * snapshot.loopLengthTicks;
            for (note in snapshot.notes) {
                var noteStart = loopStart + note.startTick;
                if (noteStart > startExclusive && noteStart <= endInclusive) {
                    emitStart(noteStart, note);
                }
            }
        }

        var writeIndex = 0;
        for (readIndex in 0...activeNotes.length) {
            var activeNote = activeNotes[readIndex];
            if (activeNote.endTick > startExclusive && activeNote.endTick <= endInclusive) {
                emit(activeNote.endTick, SequenceNoteEvent.NOTE_OFF, activeNote.note, 0);
            } else if (activeNote.endTick > endInclusive) {
                activeNotes[writeIndex++] = activeNote;
            }
        }
        while (activeNotes.length > writeIndex) activeNotes.pop();
    }

    private function emitAllNotesOff(time:Float):Void {
        // Release only note instances that were actually started. This avoids
        // cutting an unrelated note when a host shares a channel or pitch.
        for (activeNote in activeNotes) {
            emit(time, SequenceNoteEvent.NOTE_OFF, activeNote.note, 0);
        }
        activeNotes = [];
    }

    private function emitStart(time:Float, note:SequenceNote):Void {
        emit(time, SequenceNoteEvent.NOTE_ON, note);
        activeNotes.push(new ActiveSequenceNote(note, time + note.durationTicks));
    }

    private function emit(time:Float, type:Int, note:SequenceNote, ?velocity:Null<Int>):Void {
        events.push(new SequenceNoteEvent(time, type, note.partId, note.pitch,
            velocity == null ? (type == SequenceNoteEvent.NOTE_ON ? note.velocity : 0) : velocity));
    }

    private static function positiveModulo(value:Float, divisor:Float):Float {
        var result = value % divisor;
        return result < 0 ? result + divisor : result;
    }
}

private class ActiveSequenceNote {
    public var note:SequenceNote;
    public var endTick:Float;

    public function new(note:SequenceNote, endTick:Float) {
        this.note = note;
        this.endTick = endTick;
    }
}
