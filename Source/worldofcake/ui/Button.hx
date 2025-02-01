package worldofcake.ui;

import worldofcake.CoordinateMapper;
import worldofcake.ISequencerControl;

class Button extends BaseComponent {
    private var label:String;
    
    public function new(uid:Int, x:Float, y:Float, width:Float, height:Float, 
                       mapper:CoordinateMapper, sequencer:ISequencerControl, 
                       label:String) {
        super(uid, x, y, width, height, mapper, sequencer);
        this.label = label;
    }
    
    override private function onLocalMouseDown(relX:Float, relY:Float):Bool {
        // Button just needs to notify sequencer when clicked
        sequencer.buttonPressed(uid);
        return true;
    }
} 