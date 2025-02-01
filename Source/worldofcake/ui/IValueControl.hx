package worldofcake.ui;

interface IValueControl {
    public var value:Float;
    public var min:Float;
    public var max:Float;
    function onValueChange(newValue:Float):Void;
} 