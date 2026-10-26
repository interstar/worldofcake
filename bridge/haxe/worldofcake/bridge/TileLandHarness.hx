package worldofcake.bridge;
import tileland.TileLandSequencer;
import tileland.TileOrientation;
import worldofcake.LocalPoint;
/** One TileLand model owned by one native runner. */
class TileLandHarness extends SequencerHarness {
 var inst:TileLandSequencer;
 public function new(seed:Int) { var model = new TileLandSequencer(new worldofcake.SeededRandomSource(seed)); super(model); inst = model; }
 override public function destroy():Void { super.destroy(); inst = null; }
 public function discardPendingEvents():Void if(inst!=null)inst.events=[];
 public function click(x:Float,y:Float):Void if(inst!=null)inst.mouseDown(TileLandSequencer.PLAY_AREA_UID,new LocalPoint(x,y));
 public function setSpeed(i:Int,v:Float):Void if(inst!=null&&i>=0&&i<3)inst.newValue(TileLandSequencer.speedUid(i),v);
 public function rows():Int return inst==null?0:inst.getRows(); public function cols():Int return inst==null?0:inst.getCols();
 public function tileType(x:Int,y:Int):Int return inst==null?0:(inst.getTile(x,y).type==TileOrientation.A?1:2);
 public function tileVisualVersion():Int return inst==null?0:inst.getVisualVersion();
 public function cursorX(i:Int):Float return inst==null?0:inst.getCursors()[i].position.x; public function cursorY(i:Int):Float return inst==null?0:inst.getCursors()[i].position.y;
 public function cursorColour(i:Int):Int return inst==null?0:inst.getCursors()[i].color; public function cursorSpeed(i:Int):Float return inst==null?0:inst.getCursorSpeed(i);
}
