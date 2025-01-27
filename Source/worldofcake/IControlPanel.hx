package worldofcake;

interface IControlPanel {
    function textSubmitted(uid:Int, text:String):Void;
    function mouseDragged(uid:Int, x:Int, y:Int):Void;
    function mouseDown(uid:Int, x:Int, y:Int):Void;
    function mouseUp(uid:Int, x:Int, y:Int):Void;
    function newValue(uid:Int, value:Float):Void;
    function buttonPressed(uid:Int):Void;
} 