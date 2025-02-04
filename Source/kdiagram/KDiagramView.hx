package kdiagram;

import openfl.display.Sprite;
import openfl.display.Graphics;
import worldofcake.IControlPanelView;
import worldofcake.WindowPoint;
import worldofcake.PanelPoint;
import worldofcake.ComposedCoordinateMapper;
import worldofcake.CoordinateMapper;
import worldofcake.ui.Slider;
import worldofcake.ui.PlayArea;
import worldofcake.LocalPoint;

class KDiagramView extends Sprite implements IControlPanelView {
    private var sequencer:KDiagramSequencer;
    private var playArea:PlayArea;
    private var speedSliders:Array<Slider>;
    private var channelSlider:Slider;
    private var nodeColor:Int = 0x999999;  // Greyish nodes
    private var arcColor:Int = 0xFFC864;   // Orange arcs
    private var cursorColor:Int = 0x32C850; // Green cursor
    private var networkColor:Int = 0xC8C864; // Yellow-ish network circle
    private var selectedCursorBorderColor:Int = 0xFFFFFF;  // White border for selected cursor
    private var windowToPanelMapper:CoordinateMapper;

    public function new(sequencer:KDiagramSequencer, windowToPanelMapper:CoordinateMapper) {
        super();
        this.sequencer = sequencer;
        this.windowToPanelMapper = windowToPanelMapper;
        
        // PlayArea will be set later by World
        speedSliders = [];
    }
    
    public function needsRedraw(uid:Int):Bool {
        if (uid == KDiagramSequencer.PLAY_AREA_UID) {
            return sequencer.consumeDirty();
        }
        // Add UIDs for sliders (10-12 for speed, 20 for channel)
        return (uid >= 10 && uid <= 12) || uid == 20;
    }
    
    public function redraw(uid:Int):Void {
        if (uid == KDiagramSequencer.PLAY_AREA_UID) {
            redrawPlayArea();
        } else if (uid >= 10 && uid <= 12) {
            // Speed sliders need redrawing
            var sliderIndex = uid - 10;
            speedSliders[sliderIndex].redraw();
        } else if (uid == 20) {
            // Channel slider needs redrawing
            channelSlider.redraw();
        }
    }
    
    private function redrawPlayArea():Void {
        var g = playArea.graphics;
        g.clear();
        
        // Draw background
        g.beginFill(0x000000);
        g.drawRect(0, 0, KDiagramLayout.PLAY_AREA_WIDTH, KDiagramLayout.PLAY_AREA_HEIGHT);
        g.endFill();
        
        // Draw network
        var network = sequencer.getNetwork();
        
        // Use PlayArea's coordinate mapping
        var centerWindowPoint = playArea.localToWindow(new LocalPoint(0, 0));
        var edgeWindowPoint = playArea.localToWindow(new LocalPoint(network.radius, 0));
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
            var cursorWindowPoint = playArea.localToWindow(cursor.pos);
            
            g.beginFill(cursor.color);
            g.drawCircle(cursorWindowPoint.x, cursorWindowPoint.y, size);
            g.endFill();
            
            if (cursor.isMoving) {
                // Convert target position to window space
                var targetWindowPoint = playArea.localToWindow(cursor.target);
                
                g.lineStyle(1, cursor.color);
                g.moveTo(cursorWindowPoint.x, cursorWindowPoint.y);
                g.lineTo(targetWindowPoint.x, targetWindowPoint.y);
            }
        }
    }

    private function drawNode(graphics:Graphics, node:Node, selected:Bool) {
        // Convert node position from local to window space
        
        var windowPos = playArea.localToWindow(node.pos);

        // Transform the hit radius - this is a length, not a coordinate!
        var windowRadius = playArea.localLengthToWindowLength(Node.HIT_RADIUS);
        
        graphics.beginFill(nodeColor);
        graphics.drawCircle(windowPos.x, windowPos.y, windowRadius);
        graphics.endFill();
        
        // Draw arcs from this node
        graphics.lineStyle(1, arcColor);
        for (arc in node.arcs) {
            var toNode = sequencer.getNetwork().nodes[arc.destination];
            var toWindowPos = playArea.localToWindow(toNode.pos);
            
            graphics.moveTo(windowPos.x, windowPos.y);
            graphics.lineTo(toWindowPos.x, toWindowPos.y);
        }
    }

    public function setSliders(speedSliders:Array<Slider>, channelSlider:Slider):Void {
        this.speedSliders = speedSliders;
        this.channelSlider = channelSlider;
    }

    public function setPlayArea(playArea:PlayArea):Void {
        this.playArea = playArea;
        addChild(playArea);
    }
} 