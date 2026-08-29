package worldofcake.ui;

import openfl.display.DisplayObject;
import openfl.display.Stage;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import openfl.geom.Point;
import worldofcake.WindowPoint;

/** Fits one fixed-design WorldOfCake panel inside a resizable OpenFL client area. */
class ResponsivePanelHost {
    private var stage:Stage;
    private var panel:DisplayObject;
    private var designWidth:Float;
    private var designHeight:Float;

    public function new(stage:Stage, panel:DisplayObject, designWidth:Float, designHeight:Float) {
        this.stage = stage;
        this.panel = panel;
        this.designWidth = designWidth;
        this.designHeight = designHeight;
        stage.scaleMode = StageScaleMode.NO_SCALE;
        stage.align = StageAlign.TOP_LEFT;
        resize(stage.stageWidth, stage.stageHeight);
    }

    public function resize(clientWidth:Float, clientHeight:Float):Void {
        if (clientWidth <= 0 || clientHeight <= 0) return;
        var scale = Math.min(clientWidth / designWidth, clientHeight / designHeight);
        panel.scaleX = scale;
        panel.scaleY = scale;
        panel.x = (clientWidth - designWidth * scale) * 0.5;
        panel.y = (clientHeight - designHeight * scale) * 0.5;
    }

    public function stageToDesign(stageX:Float, stageY:Float):WindowPoint {
        var point = panel.globalToLocal(new Point(stageX, stageY));
        return new WindowPoint(point.x, point.y);
    }
}
