package gbloink;

import openfl.display.Sprite;
import worldofcake.IControlPanelView;
import worldofcake.ISequencerControl;
import worldofcake.CoordinateMapper;
import worldofcake.ui.PlayArea;
import worldofcake.PanelPoint;
import worldofcake.LocalPoint;
import worldofcake.ui.Slider;
import worldofcake.ui.SemanticSelect;

class GbloinkView extends Sprite implements IControlPanelView {
    private var sequencer:Gbloink;
    private var windowToPanelMapper:CoordinateMapper;
    private var playArea:PlayArea;
    private var speedSliders:Array<Slider>;
    private var semanticSelect:SemanticSelect;
    private var backgroundWidth:Float;
    private var backgroundHeight:Float;
    
    public function new(sequencer:Gbloink, windowToPanelMapper:CoordinateMapper) {
        super();
        this.sequencer = sequencer;
        this.windowToPanelMapper = windowToPanelMapper;
        this.speedSliders = [];
    }
    
    public function setPlayArea(playArea:PlayArea):Void {
        this.playArea = playArea;
        addChild(playArea);
        // Cache background dimensions
        var size = playArea.getSize();
        this.backgroundWidth = playArea.panelLengthToWindowLength(size.x);
        this.backgroundHeight = playArea.panelLengthToWindowLength(size.y);
    }
    
    public function addSlider(slider:Slider):Void {
        speedSliders.push(slider);
        addChild(slider);
    }

    public function setSemanticSelect(select:SemanticSelect):Void {
        semanticSelect = select;
        addChild(select);
    }
    
    // IControlPanelView implementation
    public function needsRedraw(componentId:Int):Bool {
        return sequencer.needsRedraw(componentId);
    }
    
    public function redraw(componentId:Int):Void {
        if (componentId == Gbloink.PLAY_AREA_UID) {
            if (semanticSelect != null) semanticSelect.setSelectedIndex(sequencer.getScaleIndex());
            redrawPlayArea();
        } else if (componentId >= 10 && componentId <= 12) {  // Speed sliders
            for (slider in speedSliders) {
                if (slider.getUID() == componentId) {
                    slider.redraw();
                    break;
                }
            }
        }
    }
    
    private function redrawPlayArea():Void {
        playArea.graphics.clear();
        
        // Draw background
        playArea.graphics.beginFill(0x12141A);
        playArea.graphics.drawRect(0, 0, backgroundWidth, backgroundHeight);
        playArea.graphics.endFill();
        
        // Draw balls
        for (ball in sequencer.getBalls()) {
            var localPos = ball.pos;
            var displayPos = localToPlayAreaDisplay(localPos);
            
            playArea.graphics.beginFill(ball.colour);
            playArea.graphics.drawCircle(
                displayPos.x,
                displayPos.y,
                playArea.localLengthToWindowLength(ball.rad));
            playArea.graphics.endFill();
        }
        
        // Draw blocks
        for (block in sequencer.getBlocks()) {
            var localPos = block.bounds.topLeft();
            var displayPos = localToPlayAreaDisplay(localPos);
            
            playArea.graphics.beginFill(block.colour, 200 / 255);
            playArea.graphics.drawRect(
                displayPos.x,
                displayPos.y,
                playArea.localLengthToWindowLength(block.bounds.width()),
                playArea.localLengthToWindowLength(block.bounds.height()));
            playArea.graphics.endFill();
        }
    }

    private function localToPlayAreaDisplay(localPoint:LocalPoint):LocalPoint {
        var windowPoint = playArea.localToWindow(localPoint);
        return new LocalPoint(windowPoint.x - playArea.x, windowPoint.y - playArea.y);
    }
}
