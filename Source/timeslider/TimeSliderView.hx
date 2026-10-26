package timeslider;

import openfl.display.Sprite;
import openfl.display.Graphics;
import worldofcake.IControlPanelView;
import worldofcake.ui.Chrome;
import worldofcake.ui.SemanticSelect;

/** Draws each CC lane: a dark lane in the track's colour, filled up to the current value, with the target marked. */
class TimeSliderView extends Sprite implements IControlPanelView {
    public static inline var LANE_COLOUR:Int = 0x13161C;
    public static inline var FILL_ALPHA:Float = 0.35;
    public static inline var TARGET_COLOUR:Int = 0xFFFFFF;

    private var engine:TimeSliderSequencer;
    private var channelSelects:Array<SemanticSelect>;

    public function new(engine:TimeSliderSequencer) {
        super();
        this.engine = engine;
        channelSelects = [];
    }

    /** View hook for each track's MIDI channel selector (in track order). */
    public function addChannelSelect(select:SemanticSelect):Void {
        channelSelects.push(select);
        addChild(select);
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
        for (i in 0...sliders.length) {
            var slider = sliders[i];
            var colour = TimeSliderLayout.TRACK_COLOURS[i];
            var left = slider.bounds.left, top = slider.bounds.top;
            var width = slider.bounds.width(), height = slider.bounds.height();

            g.beginFill(LANE_COLOUR);
            g.drawRoundRect(left, top, width, height, Chrome.CORNER * 1.5, Chrome.CORNER * 1.5);
            g.endFill();

            // Value: filled from the bottom of the lane up to the current position.
            g.beginFill(colour, FILL_ALPHA);
            g.drawRect(left, top + slider.current, width, height - slider.current);
            g.endFill();
            g.lineStyle(2, colour);
            g.moveTo(left, top + slider.current);
            g.lineTo(left + width, top + slider.current);

            // Target the lane is travelling to.
            if (slider.moving) {
                g.lineStyle(1, TARGET_COLOUR, 0.7);
                g.moveTo(left, top + slider.destination);
                g.lineTo(left + width, top + slider.destination);
            }
            g.lineStyle();

            if (i < channelSelects.length) channelSelects[i].setSelectedIndex(engine.getChannel(i) - 1);
        }
    }
}
