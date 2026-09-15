package worldofcake.ui;

import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import worldofcake.CoordinateMapper;
import worldofcake.PanelPoint;

class PanelTitle extends Sprite {
    public function new(position:PanelPoint, size:PanelPoint, mapper:CoordinateMapper, text:String) {
        super();

        var windowPosition = mapper.backward(position.x, position.y);
        var windowSize = mapper.backward(size.x, size.y);
        x = windowPosition.x;
        y = windowPosition.y;

        var field = new TextField();
        field.defaultTextFormat = new TextFormat("_sans", 24, 0x4A453C, true, null, null, null, null, "left");
        field.selectable = false;
        field.mouseEnabled = false;
        field.text = text;
        field.x = 0;
        field.y = 0;
        field.width = Math.max(1, windowSize.x - 5);
        field.height = Math.max(1, windowSize.y);
        addChild(field);
    }
}
