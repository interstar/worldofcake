package worldofcake.ui;

interface IFullApp {
    // Platform event entry points
    function handleMouseDown(screenX:Float, screenY:Float):Void;
    function handleMouseDrag(screenX:Float, screenY:Float):Void;
    function handleMouseUp(screenX:Float, screenY:Float):Void;
    function handleKeyPressed(key:String):Void;
    
    // View management
    function getView():IControlPanelView;
    function resize(width:Float, height:Float):Void;
} 