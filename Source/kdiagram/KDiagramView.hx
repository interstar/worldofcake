package kdiagram;

import openfl.display.Sprite;
import openfl.display.Graphics;
import worldofcake.IControlPanelView;

class KDiagramView extends Sprite implements IControlPanelView {
    private var engine:KDiagramSequencer;
    private var nodeColor:Int = 0x999999;  // Greyish nodes
    private var arcColor:Int = 0xFFC864;   // Orange arcs
    private var cursorColor:Int = 0x32C850; // Green cursor
    private var networkColor:Int = 0xC8C864; // Yellow-ish network circle
    private var selectedCursorBorderColor:Int = 0xFFFFFF;  // White border for selected cursor

    public function new(engine:KDiagramSequencer) {
        super();
        this.engine = engine;
    }

    public function needsRedraw(uid:Int):Bool {
        if (uid == KDiagramSequencer.PLAY_AREA_UID) {
            return engine.consumeDirty();
        }
        return false;
    }

    public function redraw(uid:Int):Void {
        if (uid == KDiagramSequencer.PLAY_AREA_UID) {
            var g:Graphics = this.graphics;
            g.clear();

            // Draw background
            g.beginFill(0x000000);
            g.drawRect(0, 0, engine.areaWidth, engine.areaHeight);
            g.endFill();

            var network = engine.getNetwork();

            // Draw network circle
            g.lineStyle(1, networkColor);
            g.drawCircle(network.centerX, network.centerY, network.radius);

            // Draw arcs
            g.lineStyle(1, arcColor);
            for (node in network.nodes) {
                for (arc in node.arcs) {
                    var destNode = network.getNode(arc.destination);
                    
                    // Draw arc line
                    g.moveTo(node.x, node.y);
                    g.lineTo(destNode.x, destNode.y);
                    
                    // Draw arrow near destination
                    var dx = destNode.x - node.x;
                    var dy = destNode.y - node.y;
                    var len = Math.sqrt(dx * dx + dy * dy);
                    if (len > 0) {
                        var arrowX = node.x + (dx * 0.9);
                        var arrowY = node.y + (dy * 0.9);
                        g.drawCircle(arrowX, arrowY, 2.5);
                    }
                }
            }

            // Draw nodes
            for (node in network.nodes) {
                g.lineStyle(1, nodeColor);
                g.beginFill(nodeColor);
                g.drawCircle(node.x, node.y, 10);
                g.endFill();
            }

            // Draw cursors
            var selectedIndex = engine.getSelectedCursorIndex();
            for (i in 0...engine.getCursors().length) {
                var cursor = engine.getCursors()[i];
                
                // Draw larger circle with white border for selected cursor
                if (i == selectedIndex) {
                    g.lineStyle(2, selectedCursorBorderColor);
                    g.beginFill(cursor.color);
                    g.drawCircle(cursor.x, cursor.y, 10);
                    g.endFill();
                } else {
                    g.lineStyle(1, cursor.color);
                    g.beginFill(cursor.color);
                    g.drawCircle(cursor.x, cursor.y, 8);
                    g.endFill();
                }
            }

            // Generate events after drawing
            engine.generateEvents();
        }
    }
} 