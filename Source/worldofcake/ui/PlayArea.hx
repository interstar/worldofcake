package worldofcake.ui;

import worldofcake.ISequencerControl;
import worldofcake.IControlPanel;
import worldofcake.CoordinateMapper;

class PlayArea extends BaseComponent {
    private var areaUid:Int;  // The uid used by the sequencer for this area
    
    public function new(uid:Int, x:Float, y:Float, width:Float, height:Float,
                       mapper:CoordinateMapper, sequencer:ISequencerControl,
                       areaUid:Int) {
        super(uid, x, y, width, height, mapper, sequencer);
        this.areaUid = areaUid;
        
        // Create mapper for panel->local space
        this.panelToLocalMapper = new CoordinateMapper(
            x, x + width,       // space1: panel x range
            y, y + height,      // space1: panel y range
            0, width,           // space2: local x range
            0, height          // space2: local y range
        );
    }
    
    override private function onLocalMouseDown(localX:Float, localY:Float):Bool {
        sequencer.mouseDown(areaUid, Std.int(localX), Std.int(localY));
        return true;
    }
    
    override private function onLocalMouseDrag(localX:Float, localY:Float):Bool {
        sequencer.mouseDragged(areaUid, Std.int(localX), Std.int(localY));
        return true;
    }
    
    override private function onLocalMouseUp(localX:Float, localY:Float):Bool {
        sequencer.mouseUp(areaUid, Std.int(localX), Std.int(localY));
        return true;
    }
} 