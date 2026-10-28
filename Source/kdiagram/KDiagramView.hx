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
    private var nodeColor:Int = 0x292722;  // Match Rack node fill
    private var arcColor:Int = 0x35332E;   // Orange arcs
    private var cursorColor:Int = 0x32C850; // Green cursor
    private var networkColor:Int = 0xA7A298; // Yellow-ish network circle
    private var selectedCursorBorderColor:Int = 0x292722;  // White border for selected cursor

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
        g.beginFill(0xF6F3EA);
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
        
        // Draw all connections before the opaque paper-filled symbols.
        g.lineStyle(1, arcColor);
        for (node in network.nodes) for (arc in node.arcs) {
            var from = localToPlayAreaDisplay(node.pos);
            var to = localToPlayAreaDisplay(network.nodes[arc.destination].pos);
            g.moveTo(from.x, from.y);
            g.lineTo(to.x, to.y);
        }
        for (node in network.nodes) {
            drawNode(g, node, false);
        }
        
        // Draw cursors
        var selectedIndex = sequencer.getSelectedCursorIndex();
        var cursors = sequencer.getCursors();
        for (i in 0...cursors.length) {
            var cursor = cursors[i];
            var size = (i == selectedIndex) ? 5 : 4;
            
            // Convert cursor position to window space
            var cursorWindowPoint = localToPlayAreaDisplay(cursor.pos);
            
            g.lineStyle();
            g.beginFill(cursor.color);
            g.drawCircle(cursorWindowPoint.x, cursorWindowPoint.y, size);
            g.endFill();

            if (i == selectedIndex) {
                g.lineStyle(2, selectedCursorBorderColor);
                g.drawCircle(cursorWindowPoint.x, cursorWindowPoint.y, size + 3);
            }
            
            if (cursor.isMoving && cursor.waitRemaining <= 0) {
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
        
        var x = windowPos.x, y = windowPos.y, r = windowRadius;
        graphics.lineStyle(1.3, nodeColor);
        graphics.beginFill(0xF6F3EA);
        switch (node.type) {
            case Terminus:
                graphics.moveTo(x-r*1.35, y);
                graphics.lineTo(x, y-r*0.65);
                graphics.lineTo(x+r*1.35, y);
                graphics.lineTo(x, y+r*0.65);
                graphics.lineTo(x-r*1.35, y);
            case Square: graphics.drawRect(x-r, y-r, r*2, r*2);
            case Triangle:
                graphics.moveTo(x, y-r);
                graphics.lineTo(x+r, y+r);
                graphics.lineTo(x-r, y+r);
                graphics.lineTo(x, y-r);
            default: graphics.drawCircle(x, y, r);
        }
        graphics.endFill();
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
