package worldofcake.ui;

import worldofcake.IControlPanelView;
import worldofcake.WindowPoint;

interface IFullApp {
    // Platform event entry points
    public function handleMouseDown(windowPoint:WindowPoint):Void;
    public function handleMouseDrag(windowPoint:WindowPoint):Void;
    public function handleMouseUp(windowPoint:WindowPoint):Void;
    public function handleKeyPressed(key:String):Void;
    
    // View management
    public function getView():IControlPanelView;
    public function resize(width:Float, height:Float):Void;
} 