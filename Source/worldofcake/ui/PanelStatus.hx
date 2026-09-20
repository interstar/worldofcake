package worldofcake.ui;

import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import worldofcake.CoordinateMapper;
import worldofcake.PanelPoint;

/** Passive status text owned by an app view, with no sequencer input. */
class PanelStatus extends Sprite {
    private var field:TextField;
    private var widthPixels:Float;
    private var heightPixels:Float;

    public function new(position:PanelPoint, size:PanelPoint, mapper:CoordinateMapper) {
        super();
        var windowPosition = mapper.backward(position.x, position.y);
        var windowSize = mapper.backward(size.x, size.y);
        x = windowPosition.x;
        y = windowPosition.y;
        widthPixels = windowSize.x;
        heightPixels = windowSize.y;
        field = new TextField();
        field.defaultTextFormat = new TextFormat("_sans", 12, 0xB43B3B, false);
        field.selectable = false;
        field.mouseEnabled = false;
        field.x = 2;
        field.y = 0;
        field.width = Math.max(1, widthPixels - 4);
        field.height = Math.max(1, heightPixels);
        addChild(field);
    }

    public function setText(value:String):Void field.text = value == null ? "" : value;
}
