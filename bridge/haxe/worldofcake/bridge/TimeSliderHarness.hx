package worldofcake.bridge;
import timeslider.TimeSliderSequencer;
import worldofcake.LocalPoint;
/** One TimeSlider model owned by one native runner. */
class TimeSliderHarness {
 var instance:TimeSliderSequencer;
 public function new(w:Int,h:Int,slow:Float,fast:Float) instance=new TimeSliderSequencer(w,h,slow,fast);
 public function destroy():Void instance=null;
 public function modelReady():Bool return instance != null && instance.getModelStatus().ready;
 public function stateRevision():Int return instance == null ? 0 : instance.getModelStatus().stateRevision;
 public function advanceTime(d:Float):Void if(instance!=null)instance.advanceTime(d);
 public function click(uid:Int,x:Float,y:Float):Void if(instance!=null)instance.mouseDown(uid,new LocalPoint(x,y));
 public function reset():Void if(instance!=null)instance.reset();
 public function setPaused(v:Bool):Void if(instance!=null){if(v)instance.pause();else instance.resume();}
 public function logicalTime():Float return instance==null?0:instance.getLogicalTime();
 public function paused():Bool return instance!=null&&instance.isPaused();
 public function sliderCount():Int return instance==null?0:instance.getSliders().length;
 public function sliderX(i:Int):Float return valid(i)?instance.getSliders()[i].bounds.left:0;
 public function sliderY(i:Int):Float return valid(i)?instance.getSliders()[i].bounds.top:0;
 public function sliderWidth(i:Int):Float return valid(i)?instance.getSliders()[i].bounds.width():0;
 public function sliderHeight(i:Int):Float return valid(i)?instance.getSliders()[i].bounds.height():0;
 public function sliderCurrent(i:Int):Float return valid(i)?instance.getSliders()[i].current:0;
 public function sliderDestination(i:Int):Float return valid(i)?instance.getSliders()[i].destination:0;
 public function sliderMidiValue(i:Int):Int return valid(i)?instance.getSliders()[i].getValue():0;
 public function hasEventBefore(t:Float):Bool return instance!=null&&instance.hasEventBefore(t);
 public function nextEventTimestamp():Float return instance==null||instance.events.length==0?0:instance.events[0].timestamp;
 public function nextEventType():Int return instance==null||instance.events.length==0?-1:instance.events[0].type;
 public function nextEventChannel():Int return instance==null||instance.events.length==0?0:instance.events[0].data1;
 public function nextEventData2():Int return instance==null||instance.events.length==0?0:instance.events[0].data2;
 public function nextEventData3():Int return instance==null||instance.events.length==0?0:instance.events[0].data3;
 public function popEvent():Void if(instance!=null&&instance.events.length>0) instance.getNextEvent();
 public function exportStateJson():String return instance==null?'{}':instance.exportStateJson();
 public function importStateJson(j:String):Void if(instance!=null)instance.importStateJson(j);
 function valid(i:Int):Bool return instance!=null&&i>=0&&i<instance.getSliders().length;
}
