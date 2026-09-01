package worldofcake.bridge;
import kdiagram.KDiagramSequencer;
import worldofcake.SeededRandomSource;
/** One KDiagram model owned by one native runner. */
class KDiagramHarness {
 var inst:KDiagramSequencer;
 public function new(seed:Int) inst = new KDiagramSequencer(new SeededRandomSource(seed));
 public function destroy():Void inst=null;
 public function advanceTime(d:Float):Void if(inst!=null)inst.advanceTime(d);
 public function click(x:Float,y:Float):Void if(inst!=null)inst.playAreaMouseDown(x,y);
 public function setValue(i:Int,v:Float):Void if(inst!=null)inst.newValue(i,v);
 public function reset():Void if(inst!=null)inst.reset();
 public function setPaused(v:Bool):Void if(inst!=null){if(v)inst.pause();else inst.resume();}
 public function setSelected(i:Int):Void if(inst!=null)inst.setSelectedCursorIndex(i);
 public function rotate(d:Float):Void if(inst!=null)inst.rotateNetwork(d);
 public function hasEventBefore(t:Float):Bool return inst!=null&&inst.hasEventBefore(t);
 public function eventType():Int return inst==null?-1:inst.peekNextEventType();
 public function eventTimestamp():Float return inst==null?0:inst.peekNextEventTimestamp();
 public function eventChannel():Int return inst==null?0:inst.peekNextEventData1();
 public function eventData2():Int return inst==null?0:inst.peekNextEventData2();
 public function eventData3():Int return inst==null?0:inst.peekNextEventData3();
 public function popEvent():Void if(inst!=null)inst.popNextEvent();
 public function logicalTime():Float return inst==null?0:inst.getLogicalTime();
 public function paused():Bool return inst!=null&&inst.isPaused();
 public function radius():Float return inst==null?0.9:inst.getNetworkRadius();
 public function selected():Int return inst==null?0:inst.getSelectedCursorIndex();
 public function scaleIndex():Int return inst==null?0:inst.getScaleIndex();
 public function nodeCount():Int return inst==null?0:inst.getNodeCount();
 public function nodeX(i:Int):Float return inst==null?0:inst.getNodePosX(i);
 public function nodeY(i:Int):Float return inst==null?0:inst.getNodePosY(i);
 public function nodeArcCount(i:Int):Int return inst==null?0:inst.getNodeArcCount(i);
 public function arcDestination(n:Int,a:Int):Int return inst==null?-1:inst.getArcDestination(n,a);
 public function cursorX(i:Int):Float return inst==null?0:inst.getCursorPosX(i);
 public function cursorY(i:Int):Float return inst==null?0:inst.getCursorPosY(i);
 public function cursorTargetX(i:Int):Float return inst==null?0:inst.getCursorTargetX(i);
 public function cursorTargetY(i:Int):Float return inst==null?0:inst.getCursorTargetY(i);
 public function cursorColour(i:Int):Int return inst==null?0:inst.getCursorColourRgb(i);
 public function cursorChannel(i:Int):Int return inst==null?1:inst.getCursorChannel(i);
 public function cursorSpeed(i:Int):Float return inst==null?0:inst.getCursorSpeed(i);
 public function cursorMoving(i:Int):Bool return inst!=null&&inst.getCursorIsMoving(i);
 public function exportStateJson():String return inst==null?'{}':inst.exportStateJson();
 public function importStateJson(j:String):Void if(inst!=null)inst.importStateJson(j);
}
