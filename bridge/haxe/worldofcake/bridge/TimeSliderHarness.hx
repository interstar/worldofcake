package worldofcake.bridge;
import timeslider.TimeSliderSequencer;
import worldofcake.LocalPoint;
/** One TimeSlider model owned by one native runner. */
class TimeSliderHarness extends SequencerHarness {
 var instance:TimeSliderSequencer;
 /** The lane count is the target's (generated); travel times default to the app's. */
 public function new() { var model = new TimeSliderSequencer(); super(model); instance = model; }
 override public function destroy():Void { super.destroy(); instance = null; }
 /** A click in a lane's own space: x 0 (left) .. 1 (right), y 0 (bottom) .. 1 (top). */
 public function click(uid:Int,x:Float,y:Float):Void if(instance!=null)instance.mouseDown(uid,new LocalPoint(x,y));
 public function setValue(uid:Int,value:Float):Void if(instance!=null)instance.newValue(uid,value);
 public function sliderChannel(i:Int):Int return valid(i)?instance.getChannel(i):1;
 public function sliderCcNumber(i:Int):Int return valid(i)?instance.getCcNumber(i):0;
 public function sliderLabel(i:Int):String return valid(i)?instance.getLabel(i):"";
 public function submitText(uid:Int,text:String):Void if(instance!=null)instance.textSubmitted(uid,text);
 public function sliderCount():Int return instance==null?0:instance.getSliders().length;
 /** Lane value and target, 0 (bottom) .. 1 (top). */
 public function sliderValue(i:Int):Float return valid(i)?instance.getSliders()[i].value:0;
 public function sliderTarget(i:Int):Float return valid(i)?instance.getSliders()[i].target:0;
 public function sliderMoving(i:Int):Bool return valid(i)&&instance.getSliders()[i].moving;
 public function hasEventBefore(t:Float):Bool return instance!=null&&instance.hasEventBefore(t);
 public function nextEventTimestamp():Float return instance==null||instance.events.length==0?0:instance.events[0].timestamp;
 public function nextEventType():Int return instance==null||instance.events.length==0?-1:instance.events[0].type;
 public function nextEventChannel():Int return instance==null||instance.events.length==0?0:instance.events[0].data1;
 public function nextEventData2():Int return instance==null||instance.events.length==0?0:instance.events[0].data2;
 public function nextEventData3():Int return instance==null||instance.events.length==0?0:instance.events[0].data3;
 public function popEvent():Void if(instance!=null&&instance.events.length>0) instance.getNextEvent();
 function valid(i:Int):Bool return instance!=null&&i>=0&&i<instance.getSliders().length;
}
