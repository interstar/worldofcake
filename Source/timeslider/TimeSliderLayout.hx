package timeslider;

import generated.timeslider.TimeSliderCompositionGenerated;
import generated.timeslider.TimeSliderTracksGenerated;
import generated.timeslider.TimeSliderLayoutGenerated;
import timeslider.TimeSliderSequencer.TimeSlider;
import worldofcake.CoordinateMapper;
import worldofcake.ui.IComponent;

// Maintained compatibility facade. Geometry and track metadata are generated from layouts/openfl/timeslider.layla.
class TimeSliderLayout {
    public static inline var WINDOW_WIDTH:Float = TimeSliderLayoutGenerated.WINDOW_WIDTH;
    public static inline var WINDOW_HEIGHT:Float = TimeSliderLayoutGenerated.WINDOW_HEIGHT;
    public static inline var PANEL_WIDTH:Float = TimeSliderLayoutGenerated.PANEL_WIDTH;
    public static inline var PANEL_HEIGHT:Float = TimeSliderLayoutGenerated.PANEL_HEIGHT;
    public static inline var TRACK_COUNT:Int = TimeSliderTracksGenerated.TRACK_COUNT;
    public static inline var MINIMUM_TRAVEL_TIME:Float = TimeSliderTracksGenerated.MINIMUM_TRAVEL_TIME;
    public static inline var MAXIMUM_TRAVEL_TIME:Float = TimeSliderTracksGenerated.MAXIMUM_TRAVEL_TIME;
    public static var TRACK_COLOURS(get, never):Array<Int>;
    static inline function get_TRACK_COLOURS():Array<Int> return TimeSliderTracksGenerated.TRACK_COLOURS;

    public static inline var LANE1_TRACK_X:Float = TimeSliderLayoutGenerated.LANE1TRACK_X;
    public static inline var LANE1_TRACK_Y:Float = TimeSliderLayoutGenerated.LANE1TRACK_Y;
    public static inline var LANE1_TRACK_WIDTH:Float = TimeSliderLayoutGenerated.LANE1TRACK_WIDTH;
    public static inline var LANE1_TRACK_HEIGHT:Float = TimeSliderLayoutGenerated.LANE1TRACK_HEIGHT;

    public static function createSequencer():TimeSliderSequencer {
        return TimeSliderTracksGenerated.createSequencer();
    }

    public static function buildTracks(minimumTravelTime:Float, maximumTravelTime:Float):Array<TimeSlider> {
        return TimeSliderTracksGenerated.buildTracks(minimumTravelTime, maximumTravelTime);
    }

    public static function buildControls(sequencer:TimeSliderSequencer, windowToPanelMapper:CoordinateMapper, view:TimeSliderView):Array<IComponent> {
        return TimeSliderCompositionGenerated.buildControls(sequencer, windowToPanelMapper, view);
    }
}
