package worldofcake;

interface ISequencer {
    /** Lifecycle state shared by all hosts and renderers. */
    function getModelStatus():ModelStatus;

    function advanceTime(delta:Float):Void;

    /** Logical model time in seconds since the last transport reset. */
    function getLogicalTime():Float;

    /**
        Synchronize forward to authoritative elapsed transport time in seconds.
        Hosts may call this instead of estimating elapsed time from callback cadence.
        The supplied time is monotonic between resets; paused hosts keep it fixed.
    **/
    function resyncTime(elapsedSeconds:Float):Void;

    /**
        Start a new host-transport epoch without resetting musical/editor state.
        Pending events are discarded and logical time returns to zero. Hosts use
        this for seeks, loop jumps, and transport restarts before resuming forward
        synchronization with `resyncTime()`. The explicit pause and mute state is
        preserved.
    **/
    function resetTransport():Void;

    function hasEventBefore(timeLimit:Float):Bool;
    function getNextEvent():Event;

    /**
        Correct an incoming MIDI note at logical sequencer time. Sequencers
        without a harmonic correction model return the input unchanged.
    **/
    function correctInputNote(note:Int, time:Float, previousNote:Int = -1):Int;

    /**
        Explicit pause: stop simulation and logical time while engaged. Pausing is
        an output boundary (sounding notes are released, pending events dropped).
    **/
    function setPaused(value:Bool):Void;

    /** Whether explicit user/model pause is currently engaged. */
    function isPaused():Bool;

    /**
        Mute musical output while the model, logical time, and visuals keep running.
        Muting is an output boundary like pause. Adapters that publish outputs other
        than events (e.g. CV derived from snapshots) must also honour `isMuted()`.
    **/
    function setMuted(value:Bool):Void;

    /** Whether musical output is muted while the model continues running. */
    function isMuted():Bool;

    /**
        Continuous controls the sequencer publishes, each a value from 0 to 1 with
        its MIDI routing (see `ControlOutput`). Hosts read `published` values and
        present them as a VST parameter, Rack CV, etc.; MIDI CC is already in the
        event stream. Empty for sequencers without continuous controls.
    **/
    function getControlOutputs():Array<ControlOutput>;

    /** Whether the host transport gate currently permits model advancement. */
    function isTransportRunning():Bool;

    /** Set the host transport gate without changing explicit pause state. */
    function setTransportRunning(value:Bool):Void;

    /**
        Return to this sequencer's default run state (e.g. clear user edits, new random layout).
        Meaning is app-specific; implementations may no-op. Logical time restarts, but the
        explicit pause and mute state is preserved (see `resetTransport()`).
    **/
    function reset():Void;

    /**
        Serialize recoverable runtime state as a JSON string (format is sequencer-specific;
        include a `"v"` version field when evolving). Hosts use this for patch persistence.
    **/
    function exportStateJson():String;

    /** Restore from `exportStateJson`; invalid or empty input should no-op or partially apply safely. */
    function importStateJson(json:String):Void;
} 
