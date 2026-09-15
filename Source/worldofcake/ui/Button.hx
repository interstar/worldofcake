package worldofcake.ui;

import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import worldofcake.CoordinateMapper;
import worldofcake.ISequencerControl;
import worldofcake.LocalPoint;
import worldofcake.PanelPoint;
import worldofcake.WindowPoint;

class Button extends Sprite implements IComponent {
    private var common:ComponentCommon;
    private var label:String;
    private var color:Int;
    private var pressed:Bool;

    public function new(uid:Int, panelPos:PanelPoint, panelSize:PanelPoint, windowToPanelMapper:CoordinateMapper,
                        sequencer:ISequencerControl, label:String, color:Int) {
        super();
        common = new ComponentCommon(uid, panelPos, panelSize, windowToPanelMapper,
            new LocalPoint(0, 0), new LocalPoint(panelSize.x, panelSize.y), sequencer);
        this.label = label;
        this.color = color;
        this.pressed = false;
        var windowPos = panelToWindow(panelPos);
        x = windowPos.x;
        y = windowPos.y;
        redraw();
    }

    public function handleMouseDown(point:WindowPoint):Bool {
        if (!common.inBounds(point)) return false;
        pressed = true;
        redraw();
        common.sequencer.buttonPressed(getUID());
        return true;
    }

    public function handleMouseDragged(point:WindowPoint):Bool return common.inBounds(point);

    public function handleMouseUp(point:WindowPoint):Bool {
        if (pressed) {
            pressed = false;
            redraw();
        }
        return true;
    }

    public function redraw():Void {
        graphics.clear();
        while (numChildren > 0) removeChildAt(0);
        var size = common.getWindowSize();
        graphics.lineStyle(pressed ? 3 : 1, 0x101010);
        graphics.beginFill(pressed ? darken(color) : color);
        graphics.drawRect(0, 0, size.x, size.y);
        graphics.endFill();
        addLabel(size.x, size.y);
    }

    private function darken(c:Int):Int {
        var r = Std.int(((c >> 16) & 0xFF) * 0.7);
        var g = Std.int(((c >> 8) & 0xFF) * 0.7);
        var b = Std.int((c & 0xFF) * 0.7);
        return (r << 16) | (g << 8) | b;
    }

    private function addLabel(width:Float, height:Float):Void {
        var field = new TextField();
        field.defaultTextFormat = new TextFormat("_sans", 12, 0xFFFFFF, true, null, null, null, null, "center");
        field.selectable = false;
        field.mouseEnabled = false;
        field.text = label;
        field.x = 0;
        field.y = Math.max(0, (height - 18) * 0.5);
        field.width = width;
        field.height = 20;
        addChild(field);
    }

    public function getUID():Int return common.uid;
    public function panelToWindow(p:PanelPoint):WindowPoint return common.panelToWindow(p);
    public function localToPanel(p:LocalPoint):PanelPoint return common.localToPanel(p);
    public function localToWindow(p:LocalPoint):WindowPoint return common.localToWindow(p);
    public function windowToLocal(p:WindowPoint):LocalPoint return common.windowToLocal(p);
    public function windowToPanel(p:WindowPoint):PanelPoint return common.windowToPanel(p);
    public function panelToLocal(p:PanelPoint):LocalPoint return common.panelToLocal(p);
    public function panelLengthToWindowLength(v:Float):Float return common.panelLengthToWindowLength(v);
    public function windowLengthToPanelLength(v:Float):Float return common.windowLengthToPanelLength(v);
    public function localLengthToWindowLength(v:Float):Float return common.localLengthToWindowLength(v);
    public function windowLengthToLocalLength(v:Float):Float return common.windowLengthToLocalLength(v);
    public function getPosition():PanelPoint return common.getPosition();
    public function getSize():PanelPoint return common.getSize();
    public function getMaxPoint():PanelPoint return common.getMaxPoint();
}
