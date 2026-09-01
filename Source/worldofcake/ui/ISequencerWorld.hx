package worldofcake.ui;

import worldofcake.IControlPanelView;
import worldofcake.ISequencer;
import worldofcake.WindowPoint;

interface ISequencerWorld {
    // Platform event entry points
    public function handleMouseDown(windowPoint:WindowPoint):Void;
    public function handleMouseDrag(windowPoint:WindowPoint):Void;
    public function handleMouseUp(windowPoint:WindowPoint):Void;
    public function handleKeyPressed(key:String):Void;

    // View and sequencer access
    public function getView():IControlPanelView;
    public function getSequencer():ISequencer;
    public function resize(width:Float, height:Float):Void;
}
