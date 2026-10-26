package worldofcake.bridge;

import gbloink.Gbloink;
import worldofcake.LocalPoint;
import worldofcake.SeededRandomSource;

/** One ordinary bridge object owns one Gbloink model. */
class GbloinkHarness extends SequencerHarness {
    var instance:Gbloink;
    public function new(width:Float, height:Float, seed:Int) {
        var model = new Gbloink(new LocalPoint(width, height), new SeededRandomSource(seed));
        super(model);
        instance = model;
    }
    override public function destroy():Void { super.destroy(); instance = null; }
    public function click(x:Float, y:Float):Void if (instance != null) instance.mouseDown(Gbloink.PLAY_AREA_UID, new LocalPoint(x, y));
    public function setValue(uid:Int, value:Float):Void if (instance != null) instance.newValue(uid, value);
    public function edgeNotes():Bool return instance != null && instance.isEdgeNotesEnabled();
    public function scaleIndex():Int return instance == null ? 0 : instance.getScaleIndex();
    public function noteLength():Float return instance == null ? Gbloink.DEFAULT_NOTE_LENGTH : instance.getNoteLength();
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
    public function ballNoteVelocity(i:Int):Int return instance == null ? Gbloink.DEFAULT_NOTE_VELOCITY : instance.getNoteVelocity(i);
    public function blockCount():Int return instance == null ? 0 : instance.blocks.length;
    public function blockLeft(i:Int):Float return instance == null || i < 0 || i >= instance.blocks.length ? 0 : instance.blocks[i].bounds.left;
    public function blockTop(i:Int):Float return instance == null || i < 0 || i >= instance.blocks.length ? 0 : instance.blocks[i].bounds.top;
    public function blockRight(i:Int):Float return instance == null || i < 0 || i >= instance.blocks.length ? 0 : instance.blocks[i].bounds.right;
    public function blockBottom(i:Int):Float return instance == null || i < 0 || i >= instance.blocks.length ? 0 : instance.blocks[i].bounds.bottom;
    public function blockColour(i:Int):Int return instance == null || i < 0 || i >= instance.blocks.length ? 0x888888 : instance.blocks[i].colour;
}
