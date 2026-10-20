package worldofcake.bridge;

import gbloink.Gbloink;
import worldofcake.LocalPoint;
import worldofcake.SeededRandomSource;

/** One ordinary bridge object owns one Gbloink model. */
class GbloinkHarness {
    var instance:Gbloink;
    public function new(width:Float, height:Float, seed:Int) {
        instance = new Gbloink(new LocalPoint(width, height), new SeededRandomSource(seed));
    }
    public function destroy():Void instance = null;
    public function modelReady():Bool return instance != null && instance.getModelStatus().ready;
    public function stateRevision():Int return instance == null ? 0 : instance.getModelStatus().stateRevision;
    public function advanceTime(delta:Float):Void if (instance != null) instance.advanceTime(delta);
    public function resyncTime(elapsedSeconds:Float):Void if (instance != null) instance.resyncTime(elapsedSeconds);
    public function resetTransport(unpause:Bool = true):Void if (instance != null) instance.resetTransport(unpause);
    public function resetTransportPreservingState():Void if (instance != null) instance.resetTransportPreservingState();
    public function click(x:Float, y:Float):Void if (instance != null) instance.mouseDown(Gbloink.PLAY_AREA_UID, new LocalPoint(x, y));
    public function setValue(uid:Int, value:Float):Void if (instance != null) instance.newValue(uid, value);
    public function setPaused(value:Bool):Void if (instance != null) instance.setPaused(value);
    public function reset():Void if (instance != null) instance.reset();
    public function exportStateJson():String return instance == null ? "{}" : instance.exportStateJson();
    public function importStateJson(value:String):Void if (instance != null) instance.importStateJson(value);
    public function logicalTime():Float return instance == null ? 0.0 : instance.getLogicalTime();
    public function paused():Bool return instance != null && instance.isPaused();
    public function muted():Bool return instance != null && instance.isMuted();
    public function edgeNotes():Bool return instance != null && instance.isEdgeNotesEnabled();
    public function scaleIndex():Int return instance == null ? 0 : instance.getScaleIndex();
    public function hasEventBefore(timeLimit:Float):Bool return instance != null && instance.hasEventBefore(timeLimit);
    public function nextEventTimestamp():Float return instance == null || instance.events.length == 0 ? 0 : instance.events[0].timestamp;
    public function nextEventType():Int return instance == null || instance.events.length == 0 ? -1 : instance.events[0].type;
    public function nextEventChannel():Int return instance == null || instance.events.length == 0 ? 0 : instance.events[0].data1;
    public function nextEventData2():Int return instance == null || instance.events.length == 0 ? 0 : instance.events[0].data2;
    public function nextEventData3():Int return instance == null || instance.events.length == 0 ? 0 : instance.events[0].data3;
    public function popEvent():Void if (instance != null && instance.events.length > 0) instance.getNextEvent();
    public function ballX(i:Int):Float return instance == null || i < 0 || i >= instance.balls.length ? 0 : instance.balls[i].pos.x;
    public function ballY(i:Int):Float return instance == null || i < 0 || i >= instance.balls.length ? 0 : instance.balls[i].pos.y;
    public function ballRadius(i:Int):Float return instance == null || i < 0 || i >= instance.balls.length ? 0 : instance.balls[i].rad;
    public function ballColour(i:Int):Int return instance == null || i < 0 || i >= instance.balls.length ? 0xffffff : instance.balls[i].colour;
    public function ballSpeed(i:Int):Float return instance == null ? 0.0 : instance.getBallSpeed(i);
    public function blockCount():Int return instance == null ? 0 : instance.blocks.length;
    public function blockLeft(i:Int):Float return instance == null || i < 0 || i >= instance.blocks.length ? 0 : instance.blocks[i].bounds.left;
    public function blockTop(i:Int):Float return instance == null || i < 0 || i >= instance.blocks.length ? 0 : instance.blocks[i].bounds.top;
    public function blockRight(i:Int):Float return instance == null || i < 0 || i >= instance.blocks.length ? 0 : instance.blocks[i].bounds.right;
    public function blockBottom(i:Int):Float return instance == null || i < 0 || i >= instance.blocks.length ? 0 : instance.blocks[i].bounds.bottom;
    public function blockColour(i:Int):Int return instance == null || i < 0 || i >= instance.blocks.length ? 0x888888 : instance.blocks[i].colour;
}
