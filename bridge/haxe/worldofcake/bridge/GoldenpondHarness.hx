package worldofcake.bridge;

import goldenpond.GoldenpondSequencer;

class GoldenpondHarness {
    var instance:GoldenpondSequencer;
    public function new() instance = new GoldenpondSequencer();
    public function destroy():Void instance = null;
    public function advanceTime(delta:Float):Void if (instance != null) instance.advanceTime(delta);
    public function servicePendingCompile(delta:Float):Void if (instance != null) instance.servicePendingCompile(delta);
    public function setValue(uid:Int, value:Float):Void if (instance != null) instance.newValue(uid, value);
    public function textSubmitted(uid:Int, text:String):Void if (instance != null) instance.textSubmitted(uid, text);
    public function setPaused(value:Bool):Void if (instance != null) { if (value) instance.pause(); else instance.resume(); }
    public function reset():Void if (instance != null) instance.reset();
    public function exportStateJson():String return instance == null ? "{}" : instance.exportStateJson();
    public function importStateJson(value:String):Void if (instance != null) instance.importStateJson(value);
    public function positionTicks():Float return instance == null ? 0.0 : instance.getPositionTicks();
    public function loopLengthTicks():Float return instance == null ? 1.0 : instance.getSnapshot().loopLengthTicks;
    public function noteCount():Int return instance == null ? 0 : instance.getSnapshot().notes.length;
    public function notePart(i:Int):Int return instance == null || i < 0 || i >= instance.getSnapshot().notes.length ? 0 : instance.getSnapshot().notes[i].partId;
    public function notePitch(i:Int):Int return instance == null || i < 0 || i >= instance.getSnapshot().notes.length ? 0 : instance.getSnapshot().notes[i].pitch;
    public function noteVelocity(i:Int):Int return instance == null || i < 0 || i >= instance.getSnapshot().notes.length ? 100 : instance.getSnapshot().notes[i].velocity;
    public function noteStart(i:Int):Float return instance == null || i < 0 || i >= instance.getSnapshot().notes.length ? 0.0 : instance.getSnapshot().notes[i].startTick;
    public function noteDuration(i:Int):Float return instance == null || i < 0 || i >= instance.getSnapshot().notes.length ? 0.0 : instance.getSnapshot().notes[i].durationTicks;
    public function logicalTime():Float return instance == null ? 0.0 : instance.getLogicalTime();
    public function paused():Bool return instance != null && instance.isPaused();
    public function correctInputNote(note:Int, time:Float, previousNote:Int = -1):Int return instance == null ? note : instance.correctInputNote(note, time, previousNote);
    public function correctionRevision():Int return instance == null ? 0 : instance.getCorrectionRevision();
    public function correctionChordIndex(time:Float):Int return instance == null ? -1 : instance.getCorrectionChordIndex(time);
    public function correctionTable(time:Float):Array<Int> return instance == null ? [] : instance.makeCorrectionTable(time, -1);
    public function chordInput():String return instance == null ? "" : instance.project.chordSequence;
    public function rhythmInput(i:Int):String return instance == null || i < 0 || i >= instance.project.lines.length ? "" : instance.project.lines[i].pattern;
    public function hasEventBefore(timeLimit:Float):Bool return instance != null && instance.hasEventBefore(timeLimit);
    public function nextEventTimestamp():Float return instance == null || instance.events.length == 0 ? 0 : instance.events[0].timestamp;
    public function nextEventType():Int return instance == null || instance.events.length == 0 ? -1 : instance.events[0].type;
    public function nextEventChannel():Int return instance == null || instance.events.length == 0 ? 0 : instance.events[0].data1;
    public function nextEventData2():Int return instance == null || instance.events.length == 0 ? 0 : instance.events[0].data2;
    public function nextEventData3():Int return instance == null || instance.events.length == 0 ? 0 : instance.events[0].data3;
    public function popEvent():Void if (instance != null && instance.events.length > 0) instance.getNextEvent();
}
