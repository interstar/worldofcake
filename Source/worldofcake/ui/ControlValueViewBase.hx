package worldofcake.ui;

import openfl.display.Sprite;
import worldofcake.IControlPanelView;

class ControlValueViewBase extends Sprite implements IControlPanelView {
    private var valueControls:Array<IValueControl>;

    public function new() {
        super();
        valueControls = [];
    }

    public function redrawDirty():Void {}

    public function addValueControl(control:IValueControl):Void {
        valueControls.push(control);
        addChild(cast control);
    }

    public function redrawValueControl(uid:Int):Bool {
        for (control in valueControls) {
            if (control.getUID() == uid) {
                control.redraw();
                return true;
            }
        }
        return false;
    }
}
