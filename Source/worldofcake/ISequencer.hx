package worldofcake;

interface ISequencer {
    function advanceTime(delta:Float):Void;
    function hasEventBefore(timeLimit:Float):Bool;
    function getNextEvent():Event;
} 