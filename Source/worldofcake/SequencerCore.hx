package worldofcake;

class SequencerCore {
    public static inline var MIN_NOTE_DURATION:Float = 0.001;
    /** Step size for collision-style physics (see `maxStepSeconds`). */
    public static inline var PHYSICS_STEP_SECONDS:Float = 0.001;
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
    /**
        Largest model step in seconds (0 = unlimited). Hosts pass whatever real time
        elapsed; longer deltas are split into equal steps no larger than this, so
        motion and collisions do not depend on the host's tick rate.
    **/
    private var maxStepSeconds:Float = 0.0;
    /** Note-offs scheduled by `emitNote`, ordered by time, released as model time reaches them. */
    private var pendingNoteOffs:Array<Event>;
    /** Panel controls that present the pause/mute flags; -1 when the app has none. */
    private var pauseControlUid:Int = -1;
    private var muteControlUid:Int = -1;
    /** Continuous controls this sequencer publishes (see `ControlOutput`); empty unless declared. */
    private var controlOutputs:Array<ControlOutput> = [];

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
        pendingNoteOffs = [];
    }

    /**
        Pause, mute, and transport stop are output boundaries: publish note-offs
        for sounding notes and discard events prepared before the boundary rather
        than releasing them later.
    **/
    function flushOutput():Void {
        var cleanup = discardQueuedEvents();
        currentlyPlaying.flush(currentTime, cleanup);
        events = cleanup;
        // Notes waiting for a scheduled note-off were released by the flush above.
        pendingNoteOffs = [];
        // Receivers may miss control values across the boundary; resend them after it.
        for (output in controlOutputs) output.forgetSent();
    }

    /**
        Drop queued, undelivered events while keeping the note tracking exact:
        a queued note-on was never heard, so it no longer counts as sounding; a
        queued note-off is a release the host still needs, so it is kept and
        re-stamped to now. Returns the kept note-offs (also the new queue).
    **/
    function discardQueuedEvents():Array<Event> {
        var kept:Array<Event> = [];
        for (e in events) {
            if (e.type == NoteOn) currentlyPlaying.noteOff(e.data1, e.data2);
            else if (e.type == NoteOff) kept.push(new Event(Math.min(e.timestamp, currentTime), NoteOff, e.data1, e.data2, e.data3));
        }
        events = kept;
        return kept;
    }

    public function setPaused(value:Bool):Void {
        if (value && !paused) flushOutput();
        paused = value;
        dirty = true;
    }

    public function isPaused():Bool {
        return paused;
    }

    public function setMuted(value:Bool):Void {
        if (value && !muted) flushOutput();
        muted = value;
        dirty = true;
    }

    public function isMuted():Bool {
        return muted;
    }

    public function setTransportRunning(value:Bool):Void {
        if (!value && transportRunning) flushOutput();
        transportRunning = value;
    }

    public function isTransportRunning():Bool {
        return transportRunning;
    }

    /**
        Declare which panel controls present the pause and mute flags. The panel
        then reads their state through `controlValue()` and changes it through
        `newValue()`; it keeps no lifecycle state of its own.
    **/
    function bindLifecycleControls(pauseUid:Int, muteUid:Int = -1):Void {
        pauseControlUid = pauseUid;
        muteControlUid = muteUid;
    }

    /** Apply a panel value aimed at a lifecycle control. Returns true when handled. */
    function applyLifecycleValue(uid:Int, value:Float):Bool {
        if (uid == pauseControlUid) {
            setPaused(value > 0.5);
            return true;
        }
        if (uid == muteControlUid) {
            setMuted(value > 0.5);
            return true;
        }
        return false;
    }

    /** Model-backed value of a panel control, or null when the model does not own one. */
    public function controlValue(uid:Int):Null<Float> {
        if (uid == pauseControlUid) return paused ? 1.0 : 0.0;
        if (uid == muteControlUid) return muted ? 1.0 : 0.0;
        return null;
    }

    /** Advance by `delta` seconds of real time. */
    public function advanceTime(delta:Float):Void {
        if (paused || !transportRunning || !Math.isFinite(delta) || delta <= 0) {
            return;
        }
        var steps = maxStepSeconds > 0 ? Std.int(Math.ceil(delta / maxStepSeconds - 1e-9)) : 1;
        if (steps < 1) steps = 1;
        var step = delta / steps;
        for (i in 0...steps) {
            currentTime += step;
            if (advanceModel(step)) {
                dirty = true;
            }
            releaseDueNoteOffs();
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

    public function getModelStatus():ModelStatus return modelStatus;

    /** Called by concrete sequencers after replacing/restoring model state. */
    public function markStateReplaced():Void {
        stateRevision++;
        modelStatus.stateRevision = stateRevision;
        dirty = true;
    }

    public function consumeDirty():Bool {
        var wasDirty = dirty;
        dirty = false;
        return wasDirty;
    }

    /** Discard queued musical events; pending releases are kept (see `discardQueuedEvents`). */
    public function clearEvents():Void {
        discardQueuedEvents();
    }

    function canEmit():Bool {
        return !muted && !paused && transportRunning;
    }

    /** Publish a musical event only while the sequencer is actively running.
        Paused, muted, and transport-stopped states are output boundaries.
        The queue stays ordered by timestamp; equal times keep arrival order.
        A note-off for a note that is not sounding (already released at a
        boundary) is dropped, so it cannot cut short a later note. */
    public function emitEvent(event:Event):Void {
        if (!canEmit()) return;
        if (event.type == NoteOff && !currentlyPlaying.noteOff(event.data1, event.data2)) return;
        if (event.type == NoteOn) currentlyPlaying.noteOn(event.data1, event.data2);
        var i = events.length;
        while (i > 0 && events[i - 1].timestamp > event.timestamp) i--;
        events.insert(i, event);
    }

    /**
        Emit a complete note: the note-on at `time` and its note-off `duration`
        seconds later. Apps play notes through here (or emit explicit note-offs)
        so the model always knows which notes are sounding and can release them
        at output boundaries. Retriggering a sounding note ends the earlier one.
    **/
    public function emitNote(time:Float, channel:Int, note:Int, velocity:Int, duration:Float):Void {
        if (!canEmit()) return;
        for (i in 0...pendingNoteOffs.length) {
            var earlier = pendingNoteOffs[i];
            if (earlier.data1 == channel && earlier.data2 == note) {
                pendingNoteOffs.splice(i, 1);
                emitEvent(new Event(Math.min(earlier.timestamp, time), NoteOff, channel, note, 0));
                break;
            }
        }
        emitEvent(new Event(time, NoteOn, channel, note, velocity));
        var off = new Event(time + Math.max(MIN_NOTE_DURATION, duration), NoteOff, channel, note, 0);
        var j = pendingNoteOffs.length;
        while (j > 0 && pendingNoteOffs[j - 1].timestamp > off.timestamp) j--;
        pendingNoteOffs.insert(j, off);
    }

    /** Declare this sequencer's control outputs (generated from the app's EDN `:outputs`). */
    function declareControlOutputs(outputs:Array<ControlOutput>):Void {
        controlOutputs = outputs;
    }

    public function getControlOutputs():Array<ControlOutput> {
        return controlOutputs;
    }

    /**
        Set a control output to a value from 0 to 1. While output is open the value
        is published to hosts, and a change in its 7-bit value is sent as a MIDI CC
        on the output's channel, at the current model time.
    **/
    function setControlOutput(index:Int, value:Float):Void {
        if (index < 0 || index >= controlOutputs.length) return;
        var output = controlOutputs[index];
        var cc = output.update(value, canEmit());
        if (cc >= 0) emitEvent(new Event(currentTime, ControlChange, output.channel, output.ccNumber, cc));
    }

    function releaseDueNoteOffs():Void {
        while (pendingNoteOffs.length > 0 && pendingNoteOffs[0].timestamp <= currentTime) {
            emitEvent(pendingNoteOffs.shift());
        }
    }

    /**
        Reset logical time without changing an explicit pause/mute choice.
        Sounding notes are released at the start of the new timeline, so hosts
        that drain events by logical time deliver the note-offs immediately.
    **/
    public function resetTransport():Void {
        currentTime = 0.0;
        flushOutput();
        dirty = true;
    }
}
