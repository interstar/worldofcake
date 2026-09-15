package gbloink;

import worldofcake.CoordinateMapper;
import worldofcake.ui.PlayArea;
import worldofcake.LocalPoint;
import worldofcake.ui.ControlValueViewBase;
import worldofcake.ui.SemanticSelect;
import generated.gbloink.GbloinkControlIdsGenerated;

class GbloinkView extends ControlValueViewBase {
    private var sequencer:Gbloink;
    private var playArea:PlayArea;
    private var semanticSelect:SemanticSelect;
    private var backgroundWidth:Float;
    private var backgroundHeight:Float;
    
    public function new(sequencer:Gbloink, windowToPanelMapper:CoordinateMapper) {
        super();
        this.sequencer = sequencer;
    }
    
    public function setPlayArea(playArea:PlayArea):Void {
        this.playArea = playArea;
        addChild(playArea);
        // Cache background dimensions
        var size = playArea.getSize();
        this.backgroundWidth = playArea.panelLengthToWindowLength(size.x);
        this.backgroundHeight = playArea.panelLengthToWindowLength(size.y);
    }
    
    public function setSemanticSelect(select:SemanticSelect):Void {
        semanticSelect = select;
        addChild(select);
    }
    
    private function needsRedraw(componentId:Int):Bool {
        if (componentId == Gbloink.PLAY_AREA_UID) {
            return sequencer.consumeDirty();
        }
        return GbloinkControlIdsGenerated.REDRAW_CONTROL_UIDS.indexOf(componentId) >= 0;
    }

    override public function redrawDirty():Void {
        if (needsRedraw(Gbloink.PLAY_AREA_UID)) {
            redraw(Gbloink.PLAY_AREA_UID);
        }

        for (uid in GbloinkControlIdsGenerated.REDRAW_CONTROL_UIDS) {
            if (needsRedraw(uid)) {
                redraw(uid);
            }
        }
    }

    private function redraw(componentId:Int):Void {
        if (componentId == Gbloink.PLAY_AREA_UID) {
            if (semanticSelect != null) semanticSelect.setSelectedIndex(sequencer.getScaleIndex());
            redrawPlayArea();
        } else if (Gbloink.isSpeedUid(componentId)) {
            redrawValueControl(componentId);
        } else if (componentId == Gbloink.SCALE_SELECT_UID) {
            if (semanticSelect != null) semanticSelect.setSelectedIndex(sequencer.getScaleIndex());
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
