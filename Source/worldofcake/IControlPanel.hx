package worldofcake;

interface IControlPanel {
    function textSubmitted(uid:Int, text:String):Void;
    function mouseDragged(uid:Int, point:LocalPoint):Void;
    function mouseDown(uid:Int, point:LocalPoint):Void;
    function mouseUp(uid:Int, point:LocalPoint):Void;
    function newValue(uid:Int, value:Float):Void;
    function buttonPressed(uid:Int):Void;
    function keyPressed(uid:Int, key:String):Void;

} 