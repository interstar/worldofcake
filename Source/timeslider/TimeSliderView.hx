package timeslider;

import openfl.display.Sprite;
import openfl.display.Graphics;
import worldofcake.IControlPanelView;
import worldofcake.ui.Chrome;
import worldofcake.ui.SemanticSelect;
import worldofcake.ui.TextInput;

/** Draws each CC lane: a dark lane in the track's colour, filled up to the current value, with the target marked. */
class TimeSliderView extends Sprite implements IControlPanelView {
    public static inline var LANE_COLOUR:Int = 0x13161C;
    public static inline var FILL_ALPHA:Float = 0.35;
    public static inline var TARGET_COLOUR:Int = 0xFFFFFF;

    private var engine:TimeSliderSequencer;
    private var channelSelects:Array<SemanticSelect>;
    private var ccSelects:Array<SemanticSelect>;
    private var labelInputs:Array<TextInput>;
    /** Label each field last showed from the model; a field is only refreshed when the model's label changes. */
    private var shownLabels:Array<String>;

    public function new(engine:TimeSliderSequencer) {
        super();
        this.engine = engine;
        channelSelects = [];
        ccSelects = [];
        labelInputs = [];
        shownLabels = [];
    }

    /** View hooks for each track's MIDI channel selector, CC number selector and label field (in track order). */
    public function addChannelSelect(select:SemanticSelect):Void {
        channelSelects.push(select);
        addChild(select);
    }

    public function addCcSelect(select:SemanticSelect):Void {
        ccSelects.push(select);
        addChild(select);
    }

    public function addLabelInput(input:TextInput):Void {
        labelInputs.push(input);
        shownLabels.push(null);
        addChild(input);
    }

    public function redrawDirty():Void {
        if (engine.consumeDirty()) {
            redraw();
        }
    }

    private function redraw():Void {
        var g:Graphics = this.graphics;
        g.clear();
        var sliders = engine.getSliders();
        var rects = TimeSliderLayout.TRACK_RECTS;
        for (i in 0...sliders.length) {
            var slider = sliders[i];
            var colour = TimeSliderLayout.TRACK_COLOURS[i];
            // The lane's place comes from the generated layout; its value (0 bottom .. 1 top) from the model.
            var left = rects[i][0], top = rects[i][1], width = rects[i][2], height = rects[i][3];
            var valueY = top + (1 - slider.value) * height;
            var targetY = top + (1 - slider.target) * height;

            g.beginFill(LANE_COLOUR);
            g.drawRoundRect(left, top, width, height, Chrome.CORNER * 1.5, Chrome.CORNER * 1.5);
            g.endFill();

            // Value: filled from the bottom of the lane up to the current position.
            g.beginFill(colour, FILL_ALPHA);
            g.drawRect(left, valueY, width, top + height - valueY);
            g.endFill();
            g.lineStyle(2, colour);
            g.moveTo(left, valueY);
            g.lineTo(left + width, valueY);

            // Target the lane is travelling to.
            if (slider.moving) {
                g.lineStyle(1, TARGET_COLOUR, 0.7);
                g.moveTo(left, targetY);
                g.lineTo(left + width, targetY);
            }
            g.lineStyle();

            // Selector choices are the numbers from their first value: channels from 1, CC numbers from 0.
            if (i < channelSelects.length) channelSelects[i].setSelectedIndex(engine.getChannel(i) - 1);
            if (i < ccSelects.length) ccSelects[i].setSelectedIndex(engine.getCcNumber(i));
            if (i < labelInputs.length && engine.getLabel(i) != shownLabels[i]) {
                shownLabels[i] = engine.getLabel(i);
                labelInputs[i].setText(shownLabels[i]);
            }
        }
    }
}
