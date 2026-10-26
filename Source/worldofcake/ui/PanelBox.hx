package worldofcake.ui;

import openfl.display.Sprite;
import worldofcake.CoordinateMapper;
import worldofcake.PanelPoint;

/**
 * A filled, optionally bordered rectangle: the `:box` component of a labelled
 * Layla container, drawn behind that container's controls. Purely decorative.
 */
class PanelBox extends Sprite {
    public function new(position:PanelPoint, size:PanelPoint, mapper:CoordinateMapper,
                        fill:Int, fillAlpha:Float, border:Int, borderAlpha:Float) {
        super();
        mouseEnabled = false;
        mouseChildren = false;

        var windowPosition = mapper.backward(position.x, position.y);
        var windowSize = mapper.backward(size.x, size.y);
        x = windowPosition.x;
        y = windowPosition.y;

        if (borderAlpha > 0) graphics.lineStyle(1, border, borderAlpha);
        graphics.beginFill(fill, fillAlpha);
        graphics.drawRoundRect(0.5, 0.5, windowSize.x - 1, windowSize.y - 1, Chrome.CORNER * 1.5, Chrome.CORNER * 1.5);
        graphics.endFill();
    }
}
