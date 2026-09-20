package worldofcake;

class SequencerCore {
    public var events:Array<Event>;
    public var currentTime:Float;
    public var dirty:Bool;
    public var paused:Bool;

    public function new(initialDirty:Bool = true) {
        currentTime = 0.0;
        events = [];
        dirty = initialDirty;
        paused = false;
    }

    public function pause():Void {
        paused = true;
    }

    public function resume():Void {
        paused = false;
    }

    public function advanceTime(delta:Float):Void {
        if (paused || !Math.isFinite(delta) || delta <= 0) {
            return;
        }
        currentTime += delta;
        if (advanceModel(delta)) {
            dirty = true;
        }
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

    public function consumeDirty():Bool {
        var wasDirty = dirty;
        dirty = false;
        return wasDirty;
    }

    public function clearEvents():Void {
        events = [];
    }

    public function resetTransport(unpause:Bool = true):Void {
        currentTime = 0.0;
        events = [];
        if (unpause) {
            paused = false;
        }
        dirty = true;
    }
}
