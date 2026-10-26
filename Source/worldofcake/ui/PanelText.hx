package worldofcake.ui;

import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import worldofcake.CoordinateMapper;
import worldofcake.PanelPoint;

/** A short piece of static text, centred in its cell (e.g. a column heading). */
class PanelText extends Sprite {
    public function new(position:PanelPoint, size:PanelPoint, mapper:CoordinateMapper, text:String, colour:Int) {
        super();
        mouseEnabled = false;
        mouseChildren = false;

        var windowPosition = mapper.backward(position.x, position.y);
        var windowSize = mapper.backward(size.x, size.y);
        x = windowPosition.x;
        y = windowPosition.y;

        var field = new TextField();
        field.defaultTextFormat = new TextFormat("_sans", 12, colour, false, null, null, null, null, "center");
        field.selectable = false;
        field.mouseEnabled = false;
        field.text = text;
        field.width = Math.max(1, windowSize.x);
        field.height = 18;
        field.y = Math.max(0, (windowSize.y - 18) * 0.5);
        addChild(field);
    }
}
