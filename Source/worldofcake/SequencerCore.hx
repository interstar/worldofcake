package worldofcake;

class SequencerCore {
    public var events:Array<Event>;
    public var currentTime:Float;
    public var dirty:Bool;
    public var paused:Bool;
    /** Suppresses musical output while leaving model time and visuals running. */
    public var muted:Bool;
    /** Host transport gate, independent from the user's explicit pause choice. */
    public var transportRunning:Bool;
    private var modelReady:Bool;
    private var stateRevision:Int;
    private var modelStatus:ModelStatus;
    private var currentlyPlaying:CurrentlyPlaying;

    public function new(initialDirty:Bool = true) {
        currentTime = 0.0;
        events = [];
        dirty = initialDirty;
        paused = false;
        muted = false;
        transportRunning = true;
        modelReady = true;
        stateRevision = 1;
        modelStatus = { ready: modelReady, stateRevision: stateRevision };
        currentlyPlaying = new CurrentlyPlaying();
    }

    public function pause():Void {
        var cleanup:Array<Event> = [];
        currentlyPlaying.flush(currentTime, cleanup);
        paused = true;
        // A pause is an output boundary.  Do not leave note/CC events
        // prepared before the pause to be emitted when the host resumes.
        events = cleanup;
    }

    public function resume():Void {
        paused = false;
    }

    public function advanceTime(delta:Float):Void {
        if (paused || !transportRunning || !Math.isFinite(delta) || delta <= 0) {
            return;
        }
        currentTime += delta;
        if (advanceModel(delta)) {
            dirty = true;
        }
    }

    public function resyncTime(elapsedSeconds:Float):Void {
        if (!Math.isFinite(elapsedSeconds) || elapsedSeconds <= currentTime) return;
        advanceTime(elapsedSeconds - currentTime);
    }

    function advanceModel(delta:Float):Bool {
        return false;
    }

    public function hasEventBefore(timeLimit:Float):Bool {
        return events.length > 0 && events[0].timestamp <= timeLimit;
    }

    public function getNextEvent():Event {
        return events.shift();
    }

    public function correctInputNote(note:Int, time:Float, previousNote:Int = -1):Int {
        return note;
    }

    public function getLogicalTime():Float {
        return currentTime;
    }

    public function isPaused():Bool {
        return paused;
    }

    public function getModelStatus():ModelStatus return modelStatus;

    /** Called by concrete sequencers after replacing/restoring model state. */
    public function markStateReplaced():Void {
        stateRevision++;
        modelStatus.stateRevision = stateRevision;
        dirty = true;
    }

    public function setMuted(value:Bool):Void {
        if (value && !muted) {
            var cleanup:Array<Event> = [];
            currentlyPlaying.flush(currentTime, cleanup);
            // Muting is also an output boundary: discard events prepared
            // before the mute rather than releasing them after unmuting.
            events = cleanup;
        }
        muted = value;
        dirty = true;
    }

    public function isMuted():Bool {
        return muted;
    }

    public function setTransportRunning(value:Bool):Void {
        if (!value && transportRunning) {
            // Publish lifecycle note-offs before discarding ordinary events.
            var cleanup:Array<Event> = [];
            currentlyPlaying.flush(currentTime, cleanup);
            events = cleanup;
        }
        transportRunning = value;
    }

    public function isTransportRunning():Bool {
        return transportRunning;
    }

    public function consumeDirty():Bool {
        var wasDirty = dirty;
        dirty = false;
        return wasDirty;
    }

    public function clearEvents():Void {
        events = [];
    }

    /** Publish a musical event only while the sequencer is actively running.
        Paused, muted, and transport-stopped states are output boundaries. */
    public function emitEvent(event:Event):Void {
        if (!muted && !paused && transportRunning) {
            events.push(event);
            if (event.type == 0) currentlyPlaying.noteOn(event.data1, event.data2);
            else if (event.type == 2) currentlyPlaying.noteOff(event.data1, event.data2);
        }
    }

    public function resetTransport(unpause:Bool = true):Void {
        var cleanup:Array<Event> = [];
        currentlyPlaying.flush(currentTime, cleanup);
        currentTime = 0.0;
        events = cleanup;
        paused = !unpause;
        dirty = true;
    }

    /** Reset logical time without changing an explicit pause/mute choice. */
    public function resetTransportPreservingState():Void {
        var cleanup:Array<Event> = [];
        currentlyPlaying.flush(currentTime, cleanup);
        currentTime = 0.0;
        events = cleanup;
        dirty = true;
    }
}
