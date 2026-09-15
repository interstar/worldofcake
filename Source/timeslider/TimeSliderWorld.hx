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
        sequencer = TimeSliderLayout.createSequencer();
        var view = new TimeSliderView(sequencer);
        setView(view);
        setComponents(buildComponents(view));
    }

    private function buildComponents(view:TimeSliderView):Array<IComponent> {
        var components:Array<IComponent> = [];
        var sliders = sequencer.getSliders();
        for (i in 0...sliders.length) {
            var bounds = sliders[i].bounds;
            components.push(new TimeSliderTrackComponent(
                sliders[i].uid,
                new PanelPoint(bounds.left, bounds.top),
                new PanelPoint(bounds.width(), bounds.height()),
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
