package worldofcake.ui;

import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;

/** Colours and drawing shared by the panel widgets (light chrome around a dark play area). */
class Chrome {
    public static inline var FACE:Int = 0xFFFFFF;
    public static inline var FACE_ACTIVE:Int = 0xE3E6EB;
    public static inline var FACE_PRESSED:Int = 0xD3D7DE;
    public static inline var BORDER:Int = 0xC9CDD4;
    public static inline var BORDER_ACTIVE:Int = 0x8A93A3;
    public static inline var TEXT:Int = 0x3A3F48;
    public static inline var TRACK:Int = 0xD3D6DC;
    public static inline var CORNER:Float = 8;

    /** Rounded button face. `active` is a latched toggle; `pressed` is a held button. */
    public static function drawFace(target:Sprite, width:Float, height:Float, active:Bool, pressed:Bool):Void {
        var g = target.graphics;
        g.lineStyle(1, active ? BORDER_ACTIVE : BORDER);
        g.beginFill(pressed ? FACE_PRESSED : (active ? FACE_ACTIVE : FACE));
        g.drawRoundRect(0.5, 0.5, width - 1, height - 1, CORNER, CORNER);
        g.endFill();
        g.lineStyle();
    }

    /** The face's content: the icon when there is one, otherwise the text label. */
    public static function drawContent(target:Sprite, width:Float, height:Float, label:String, icon:Array<Float>, colour:Int):Void {
        if (icon != null) {
            var size = Math.min(width, height) * 0.55;
            IconPainter.draw(target.graphics, icon, (width - size) * 0.5, (height - size) * 0.5, size, colour);
            return;
        }
        var field = new TextField();
        field.defaultTextFormat = new TextFormat("_sans", 12, colour, true, null, null, null, null, "center");
        field.selectable = false;
        field.mouseEnabled = false;
        field.text = label;
        field.y = Math.max(0, (height - 18) * 0.5);
        field.width = width;
        field.height = 20;
        target.addChild(field);
    }
}
