package timeslider;

import generated.timeslider.TimeSliderCompositionGenerated;
import generated.timeslider.TimeSliderLayoutGenerated;
import generated.timeslider.TimeSliderTracksGenerated;
import worldofcake.CoordinateMapper;
import worldofcake.ui.IComponent;

// Maintained facade over the generated OpenFL layout (apps/timeslider/openfl.layla). For views
// only: the model never sees panel geometry.
class TimeSliderLayout {
    public static inline var WINDOW_WIDTH:Float = TimeSliderLayoutGenerated.WINDOW_WIDTH;
    public static inline var WINDOW_HEIGHT:Float = TimeSliderLayoutGenerated.WINDOW_HEIGHT;
    public static inline var PANEL_WIDTH:Float = TimeSliderLayoutGenerated.PANEL_WIDTH;
    public static inline var PANEL_HEIGHT:Float = TimeSliderLayoutGenerated.PANEL_HEIGHT;
    public static var TRACK_COLOURS(get, never):Array<Int>;
    static inline function get_TRACK_COLOURS():Array<Int> return TimeSliderTracksGenerated.TRACK_COLOURS;
    /** Each lane's panel rectangle [x, y, width, height], in lane order. */
    public static var TRACK_RECTS(get, never):Array<Array<Float>>;
    static inline function get_TRACK_RECTS():Array<Array<Float>> return TimeSliderCompositionGenerated.TRACK_RECTS;

    public static function buildControls(sequencer:TimeSliderSequencer, windowToPanelMapper:CoordinateMapper, view:TimeSliderView):Array<IComponent> {
        return TimeSliderCompositionGenerated.buildControls(sequencer, windowToPanelMapper, view);
    }
}
