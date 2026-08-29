package worldofcake;

interface ISequencer {
    function advanceTime(delta:Float):Void;
    function hasEventBefore(timeLimit:Float):Bool;
    function getNextEvent():Event;

    /** Stop simulation and logical time until `resume()`. No-ops where inapplicable. */
    function pause():Void;

    /** Continue after `pause()`. No-ops where inapplicable. */
    function resume():Void;

    /**
        Return to this sequencer's default run state (e.g. clear user edits, new random layout).
        Meaning is app-specific; implementations may no-op.
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