package worldofcake.ui;

import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import worldofcake.CoordinateMapper;
import worldofcake.ISequencerControl;
import worldofcake.LocalPoint;
import worldofcake.PanelPoint;
import worldofcake.WindowPoint;

class Toggle extends Sprite implements IComponent {
    private var common:ComponentCommon;
    private var label:String;
    private var color:Int;
    private var value:Bool;

    public function new(uid:Int, panelPos:PanelPoint, panelSize:PanelPoint, windowToPanelMapper:CoordinateMapper,
                        sequencer:ISequencerControl, label:String, defaultValue:Bool, color:Int) {
        super();
        common = new ComponentCommon(uid, panelPos, panelSize, windowToPanelMapper,
            new LocalPoint(0, 0), new LocalPoint(panelSize.x, panelSize.y), sequencer);
        this.label = label;
        this.value = defaultValue;
        this.color = color;
        var windowPos = panelToWindow(panelPos);
        x = windowPos.x;
        y = windowPos.y;
        redraw();
    }

    public function setValue(v:Bool):Void {
        if (value != v) {
            value = v;
            redraw();
        }
    }

    public function handleMouseDown(point:WindowPoint):Bool {
        if (!common.inBounds(point)) return false;
        value = !value;
        redraw();
        common.sequencer.newValue(getUID(), value ? 1.0 : 0.0);
        return true;
    }

    public function handleMouseDragged(point:WindowPoint):Bool return false;
    public function handleMouseUp(point:WindowPoint):Bool return true;

    public function redraw():Void {
        graphics.clear();
        while (numChildren > 0) removeChildAt(0);
        var size = common.getWindowSize();
        graphics.lineStyle(value ? 3 : 1, value ? 0xFFFFFF : 0x202020);
        graphics.beginFill(value ? color : 0x30343A, value ? 1.0 : 0.65);
        graphics.drawRect(0, 0, size.x, size.y);
        graphics.endFill();
        addLabel(size.x, size.y);
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
