package worldofcake.ui;

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.FocusEvent;
import openfl.events.KeyboardEvent;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;
import worldofcake.CoordinateMapper;
import worldofcake.ISequencerControl;
import worldofcake.LocalPoint;
import worldofcake.PanelPoint;
import worldofcake.WindowPoint;

/** A small editable single-line control for app-specific text parameters. */
class TextInput extends Sprite implements IComponent {
    public static inline var FIELD_HEIGHT:Float = 26;
    private var common:ComponentCommon;
    private var field:TextField;

    public function new(uid:Int, panelPos:PanelPoint, panelSize:PanelPoint,
                        windowToPanelMapper:CoordinateMapper,
                        sequencer:ISequencerControl, defaultText:String) {
        super();
        common = new ComponentCommon(uid, panelPos, panelSize, windowToPanelMapper,
            new LocalPoint(0, 0), new LocalPoint(panelSize.x, panelSize.y), sequencer);

        var windowPos = panelToWindow(panelPos);
        var windowSize = common.getWindowSize();
        x = windowPos.x;
        y = windowPos.y;

        // A single text line, vertically centred in its cell, on a light face.
        var height = Math.min(windowSize.y, FIELD_HEIGHT);
        var top = (windowSize.y - height) * 0.5;
        graphics.lineStyle(1, Chrome.BORDER);
        graphics.beginFill(Chrome.FACE);
        graphics.drawRoundRect(0.5, top + 0.5, windowSize.x - 1, height - 1, Chrome.CORNER, Chrome.CORNER);
        graphics.endFill();
        graphics.lineStyle();

        field = new TextField();
        field.type = TextFieldType.INPUT;
        field.defaultTextFormat = new TextFormat("_sans", 13, Chrome.TEXT, false);
        field.text = defaultText == null ? "" : defaultText;
        field.x = 6;
        field.y = top + Math.max(0, (height - 18) * 0.5);
        field.width = Math.max(1, windowSize.x - 12);
        field.height = Math.min(height, 20);
        field.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
        field.addEventListener(FocusEvent.FOCUS_OUT, onFocusOut);
        addChild(field);
    }

    private function submit():Void {
        common.sequencer.textSubmitted(getUID(), field.text);
    }

    private function onKeyDown(event:KeyboardEvent):Void {
        if (event.keyCode == 13) submit();
    }

    private function onFocusOut(_):Void submit();

    public function handleMouseDown(point:WindowPoint):Bool {
        if (!common.inBounds(point)) return false;
        if (stage != null) stage.focus = field;
        return true;
    }

    public function handleMouseDragged(point:WindowPoint):Bool return common.inBounds(point);
    public function handleMouseUp(point:WindowPoint):Bool return common.inBounds(point);

    public function getText():String return field.text;
    public function setText(value:String):Void field.text = value == null ? "" : value;
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
