package timeslider;

import worldofcake.PanelPoint;
import worldofcake.ui.ComponentWorldBase;
import worldofcake.ui.IComponent;

class TimeSliderWorld extends ComponentWorldBase {
    private var sequencer:TimeSliderSequencer;

    public function new() {
        super(
            TimeSliderLayout.WINDOW_WIDTH,
            TimeSliderLayout.WINDOW_HEIGHT,
            TimeSliderLayout.PANEL_WIDTH,
            TimeSliderLayout.PANEL_HEIGHT
        );
        sequencer = new TimeSliderSequencer();
        var view = new TimeSliderView(sequencer);
        setView(view);
        setComponents(buildComponents(view));
    }

    /** One component per lane, over that lane's rectangle in the generated layout. */
    private function buildComponents(view:TimeSliderView):Array<IComponent> {
        var components:Array<IComponent> = [];
        var rects = TimeSliderLayout.TRACK_RECTS;
        for (i in 0...sequencer.laneCount()) {
            var r = rects[i];
            components.push(new TimeSliderTrackComponent(
                TimeSliderSequencer.trackUid(i),
                new PanelPoint(r[0], r[1]),
                new PanelPoint(r[2], r[3]),
                getWindowToPanelMapper(),
                sequencer
            ));
        }
        for (component in TimeSliderLayout.buildControls(sequencer, getWindowToPanelMapper(), view)) {
            components.push(component);
        }
        return components;
    }

    override public function getSequencer():TimeSliderSequencer {
        return sequencer;
    }
}
