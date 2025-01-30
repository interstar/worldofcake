package timeslider;

import openfl.display.Sprite;
import openfl.display.Graphics;
import openfl.text.TextField;
import openfl.text.TextFormat;
import worldofcake.IControlPanelView;

class TimeSliderView extends Sprite implements IControlPanelView {
    private var engine:TimeSliderSequencer;
    private var sliderColor:Int = 0x323232;  // Dark grey background
    private var currentColor:Int = 0x00FF00;  // Green line for current
    private var targetColor:Int = 0xFFFF00;  // Yellow line for target
    private var labels:Array<TextField>;

    public function new(engine:TimeSliderSequencer) {
        super();
        this.engine = engine;
        
        // Create text fields for CC numbers
        labels = [];
        var format = new TextFormat("Arial", 12, 0xFFFFFF);
        
        for (slider in engine.getSliders()) {
            var label = new TextField();
            label.defaultTextFormat = format;
            label.text = 'CC${slider.ccNumber}';
            label.width = 40;
            label.height = 20;
            label.x = slider.x;
            label.y = slider.y - 20;
            label.selectable = false;
            addChild(label);
            labels.push(label);
        }
    }

    public function needsRedraw(uid:Int):Bool {
        if (uid == TimeSliderSequencer.PLAY_AREA_UID) {
            return engine.consumeDirty();
        }
        return false;
    }

    public function redraw(uid:Int):Void {
        if (uid == TimeSliderSequencer.PLAY_AREA_UID) {
            var g:Graphics = this.graphics;
            g.clear();

            // Draw background
            g.beginFill(0x000000);
            g.drawRect(0, 0, engine.areaWidth, engine.areaHeight);
            g.endFill();

            // Draw sliders
            for (slider in engine.getSliders()) {
                // Draw slider background
                g.lineStyle(1, sliderColor);
                g.beginFill(sliderColor);
                g.drawRect(slider.x, slider.y, slider.width, slider.height);
                g.endFill();

                // Draw current value line (green)
                g.lineStyle(2, currentColor);
                g.moveTo(slider.x, slider.y + slider.current);
                g.lineTo(slider.x + slider.width, slider.y + slider.current);

                // Draw target value line (yellow)
                g.lineStyle(2, targetColor);
                g.moveTo(slider.x, slider.y + slider.destination);
                g.lineTo(slider.x + slider.width, slider.y + slider.destination);
            }

            // Generate events after drawing
            engine.generateEvents();
        }
    }
} 