package worldofcake;

interface IControlPanelView {
    function needsRedraw(uid:Int):Bool;
    function redraw(uid:Int):Void;
    function redrawDirty():Void;

} 