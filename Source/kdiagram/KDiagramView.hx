package kdiagram;

import openfl.display.Graphics;
import worldofcake.CoordinateMapper;
import worldofcake.ui.ControlValueViewBase;
import worldofcake.ui.PlayArea;
import worldofcake.ui.SemanticSelect;
import worldofcake.LocalPoint;
import generated.kdiagram.KDiagramControlIdsGenerated;

class KDiagramView extends ControlValueViewBase {
    private var sequencer:KDiagramSequencer;
    private var playArea:PlayArea;
    private var channelSelect:SemanticSelect;
    private var cursorSelect:SemanticSelect;
    private var scaleSelect:SemanticSelect;
    private var nodeColor:Int = 0x787878;  // Match Rack node fill
    private var arcColor:Int = 0xFFC864;   // Orange arcs
    private var cursorColor:Int = 0x32C850; // Green cursor
    private var networkColor:Int = 0xC8C864; // Yellow-ish network circle
    private var selectedCursorBorderColor:Int = 0xFFFFFF;  // White border for selected cursor

    public function new(sequencer:KDiagramSequencer, windowToPanelMapper:CoordinateMapper) {
        super();
        this.sequencer = sequencer;
        
        // PlayArea will be set later by World
    }
    
    private function needsRedraw(uid:Int):Bool {
        if (uid == KDiagramSequencer.PLAY_AREA_UID) {
            if (cursorSelect != null) cursorSelect.setSelectedIndex(sequencer.getSelectedCursorIndex());
            if (scaleSelect != null) scaleSelect.setSelectedIndex(sequencer.getScaleIndex());
            if (channelSelect != null) channelSelect.setSelectedIndex(sequencer.getBaseMidiChannel() - 1);
            return sequencer.consumeDirty();
        }
        return KDiagramControlIdsGenerated.REDRAW_CONTROL_UIDS.indexOf(uid) >= 0;
    }
    

    override public function redrawDirty():Void {
        if (needsRedraw(KDiagramSequencer.PLAY_AREA_UID)) {
            redraw(KDiagramSequencer.PLAY_AREA_UID);
        }

        for (uid in KDiagramControlIdsGenerated.REDRAW_CONTROL_UIDS) {
            if (needsRedraw(uid)) {
                redraw(uid);
            }
        }
    }

    private function redraw(uid:Int):Void {
        if (uid == KDiagramSequencer.PLAY_AREA_UID) {
            redrawPlayArea();
        } else if (KDiagramSequencer.isSpeedUid(uid) || uid == KDiagramSequencer.NOTE_LENGTH_UID) {
            redrawValueControl(uid);
        } else if (uid == KDiagramSequencer.CURSOR_SELECT_UID) {
            if (cursorSelect != null) cursorSelect.setSelectedIndex(sequencer.getSelectedCursorIndex());
        } else if (uid == KDiagramSequencer.SCALE_SELECT_UID) {
            if (scaleSelect != null) scaleSelect.setSelectedIndex(sequencer.getScaleIndex());
        }
    }
    
    private function redrawPlayArea():Void {
        var g = playArea.graphics;
        g.clear();
        
        // Draw background
        g.beginFill(0x13161C);
        g.drawRoundRect(0, 0, KDiagramLayout.PLAY_AREA_WIDTH, KDiagramLayout.PLAY_AREA_HEIGHT,
            worldofcake.ui.Chrome.CORNER * 1.5, worldofcake.ui.Chrome.CORNER * 1.5);
        g.endFill();
        
        // Draw network
        var network = sequencer.getNetwork();
        
        // Use PlayArea's coordinate mapping
        var centerWindowPoint = localToPlayAreaDisplay(new LocalPoint(0, 0));
        var edgeWindowPoint = localToPlayAreaDisplay(new LocalPoint(network.radius, 0));
        var networkWindowRadius = edgeWindowPoint.x - centerWindowPoint.x;

        g.lineStyle(1, networkColor);
        g.drawCircle(centerWindowPoint.x, centerWindowPoint.y, networkWindowRadius);
        
        // Draw nodes
        for (node in network.nodes) {
            drawNode(g, node, false);
        }
        
        // Draw cursors
        var selectedIndex = sequencer.getSelectedCursorIndex();
        var cursors = sequencer.getCursors();
        for (i in 0...cursors.length) {
            var cursor = cursors[i];
            var size = (i == selectedIndex) ? 8 : 6;
            
            // Convert cursor position to window space
            var cursorWindowPoint = localToPlayAreaDisplay(cursor.pos);
            
            g.beginFill(cursor.color);
            g.drawCircle(cursorWindowPoint.x, cursorWindowPoint.y, size);
            g.endFill();

            if (i == selectedIndex) {
                g.lineStyle(2, selectedCursorBorderColor);
                g.drawCircle(cursorWindowPoint.x, cursorWindowPoint.y, size + 3);
            }
            
            if (cursor.isMoving) {
                // Convert target position to window space
                var targetWindowPoint = localToPlayAreaDisplay(cursor.target);
                
                g.lineStyle(1, cursor.color);
                g.moveTo(cursorWindowPoint.x, cursorWindowPoint.y);
                g.lineTo(targetWindowPoint.x, targetWindowPoint.y);
            }
        }
    }

    private function drawNode(graphics:Graphics, node:Node, selected:Bool) {
        var windowPos = localToPlayAreaDisplay(node.pos);
        var windowRadius = playArea.localLengthToWindowLength(Node.HIT_RADIUS);
        
        graphics.beginFill(nodeColor);
        graphics.drawCircle(windowPos.x, windowPos.y, windowRadius);
        graphics.endFill();
        
        // Draw arcs from this node
        graphics.lineStyle(1, arcColor);
        for (arc in node.arcs) {
            var toNode = sequencer.getNetwork().nodes[arc.destination];
            var toWindowPos = localToPlayAreaDisplay(toNode.pos);
            
            graphics.moveTo(windowPos.x, windowPos.y);
            graphics.lineTo(toWindowPos.x, toWindowPos.y);
        }
    }


    public function setChannelSelect(select:SemanticSelect):Void {
        channelSelect = select;
        addChild(select);
    }

    public function setCursorSelect(select:SemanticSelect):Void {
        cursorSelect = select;
        addChild(select);
    }

    public function setScaleSelect(select:SemanticSelect):Void {
        scaleSelect = select;
        addChild(select);
    }

    public function setSemanticSelect(select:SemanticSelect):Void {
        setCursorSelect(select);
    }

    public function setPlayArea(playArea:PlayArea):Void {
        this.playArea = playArea;
        addChild(playArea);
    }

    private function localToPlayAreaDisplay(point:LocalPoint):LocalPoint {
        var windowPoint = playArea.localToWindow(point);
        return new LocalPoint(windowPoint.x - playArea.x, windowPoint.y - playArea.y);
    }
}
