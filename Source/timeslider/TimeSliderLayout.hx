package timeslider;

import generated.timeslider.TimeSliderCompositionGenerated;
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
    public static inline var TRACK_COUNT:Int = TimeSliderCompositionGenerated.TRACK_COUNT;
    public static inline var MINIMUM_TRAVEL_TIME:Float = TimeSliderCompositionGenerated.MINIMUM_TRAVEL_TIME;
    public static inline var MAXIMUM_TRAVEL_TIME:Float = TimeSliderCompositionGenerated.MAXIMUM_TRAVEL_TIME;

    public static inline var CC1_TRACK_X:Float = TimeSliderLayoutGenerated.CC1TRACK_X;
    public static inline var CC1_TRACK_Y:Float = TimeSliderLayoutGenerated.CC1TRACK_Y;
    public static inline var CC1_TRACK_WIDTH:Float = TimeSliderLayoutGenerated.CC1TRACK_WIDTH;
    public static inline var CC1_TRACK_HEIGHT:Float = TimeSliderLayoutGenerated.CC1TRACK_HEIGHT;

    public static function createSequencer():TimeSliderSequencer {
        return TimeSliderCompositionGenerated.createSequencer();
    }

    public static function buildTracks(minimumTravelTime:Float, maximumTravelTime:Float):Array<TimeSlider> {
        return TimeSliderCompositionGenerated.buildTracks(minimumTravelTime, maximumTravelTime);
    }

    public static function buildControls(sequencer:TimeSliderSequencer, windowToPanelMapper:CoordinateMapper, view:TimeSliderView):Array<IComponent> {
        return TimeSliderCompositionGenerated.buildControls(sequencer, windowToPanelMapper, view);
    }
}
