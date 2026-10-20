package worldofcake.bridge;
import zewp.ZewpSequencer;
import worldofcake.LocalPoint;
import worldofcake.SeededRandomSource;

/** One Zewp model owned by one native runner. */
class ZewpHarness {
    var inst:ZewpSequencer;
    public function new(width:Int, height:Int, seed:Int) inst = new ZewpSequencer(width, height, new SeededRandomSource(seed));
    public function destroy():Void inst = null;
    public function modelReady():Bool return inst != null && inst.getModelStatus().ready;
    public function stateRevision():Int return inst == null ? 0 : inst.getModelStatus().stateRevision;
    public function advanceTime(d:Float):Void if (inst != null) inst.advanceTime(d);
    public function discardPendingEvents():Void if (inst != null) inst.discardPendingEvents();
    public function click(x:Float,y:Float):Void if(inst!=null) inst.mouseDown(ZewpSequencer.PLAY_AREA_UID,new LocalPoint(x,y));
    public function drag(x:Float,y:Float):Void if(inst!=null) inst.mouseDragged(ZewpSequencer.PLAY_AREA_UID,new LocalPoint(x,y));
    public function dragTo(x:Float,y:Float):Void if(inst!=null) inst.dragTo(ZewpSequencer.PLAY_AREA_UID,new LocalPoint(x,y));
    public function release(x:Float,y:Float):Void if(inst!=null) inst.mouseUp(ZewpSequencer.PLAY_AREA_UID,new LocalPoint(x,y));
    public function setPopulation(v:Float):Void if(inst!=null) inst.newValue(ZewpSequencer.POPULATION_UID,v);
    public function setSpeed(v:Float):Void if(inst!=null) inst.newValue(ZewpSequencer.SPEED_UID,v);
    public function reset():Void if(inst!=null) inst.reset();
    public function setPaused(v:Bool):Void if(inst!=null){if(v)inst.pause();else inst.resume();}
    public function count():Int return inst==null?0:inst.getZewps().length;
    public function x(i:Int):Float return inst==null?0:inst.getZewps()[i].position.x;
    public function y(i:Int):Float return inst==null?0:inst.getZewps()[i].position.y;
    public function angle(i:Int):Float return inst==null?0:inst.getZewps()[i].angle;
    public function length(i:Int):Float return inst==null?0:inst.getZewps()[i].length;
    public function colour(i:Int):Int return inst==null?0:inst.getZewps()[i].color;
    public function inFront(i:Int):Bool return inst==null?false:inst.getZewps()[i].inFront;
    public function blockCount():Int return inst==null?0:inst.getBlocks().length;
    public function blockX(i:Int):Float return inst==null?0:inst.getBlocks()[i].bounds.center().x;
    public function blockY(i:Int):Float return inst==null?0:inst.getBlocks()[i].bounds.center().y;
    public function blockWidth(i:Int):Float return inst==null?0:inst.getBlocks()[i].bounds.width();
    public function blockHeight(i:Int):Float return inst==null?0:inst.getBlocks()[i].bounds.height();
    public function logicalTime():Float return inst==null?0:inst.getLogicalTime();
    public function paused():Bool return inst!=null&&inst.isPaused();
    public function population():Int return inst==null?0:inst.getZewps().length;
    public function speedMultiplier():Float return inst==null?1.0:inst.getSpeedMultiplier();
    public function exportStateJson():String return inst==null?'{}':inst.exportStateJson();
    public function importStateJson(s:String):Void if(inst!=null) inst.importStateJson(s);
}
