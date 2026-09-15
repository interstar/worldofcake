package worldofcake.ui;

interface IValueControl extends IComponent {
    public function setValue(value:Float):Void;
    public function redraw():Void;
}
