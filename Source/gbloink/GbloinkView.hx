package gbloink;

import worldofcake.CoordinateMapper;
import worldofcake.ui.PlayArea;
import worldofcake.LocalPoint;
import worldofcake.ui.ControlValueViewBase;
import worldofcake.ui.SemanticSelect;
import generated.gbloink.GbloinkControlIdsGenerated;
#if woc_gpu_trails
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.text.TextField;
import openfl.text.TextFormat;
import worldofcake.visuals.GpuTrailSurface;
#end

class GbloinkView extends ControlValueViewBase {
    private var sequencer:Gbloink;
    private var playArea:PlayArea;
    private var semanticSelect:SemanticSelect;
    private var backgroundWidth:Float;
    private var backgroundHeight:Float;
    #if woc_gpu_trails
    private var trails:GpuTrailSurface;
    private var foreground:Sprite;
    private var marks:Sprite;
    private var collisionRipples:CollisionRippleView;
    private var diagnostics:TextField;
    private var effectsEnabled:Bool = true;
    private var lastRevision:Int = -1;
    private var lastModelTime:Float = -1;
    private var frameStamp:Float = -1;
    private var frameWindow:Float = 0;
    private var frameSamples:Int = 0;
    private var lastFps:Float = 0;
    private var submitTotal:Float = 0;
    private var keyStage:openfl.display.Stage;
    private var statusStamp:Float = -1;
    private var benchmarkMode:Int = -1;
    private var benchmarkStart:Float = 0;
    private var benchmarkModelStart:Float = 0;
    private var benchmarkIntervals:Array<Float> = [];
    private var benchmarkSubmit:Float = 0;
    private var benchmarkFrames:Int = 0;
    private var benchmarkPreviousStamp:Float = -1;
    private var benchmarkMeasuring:Bool = false;
    private var benchmarkSavedEnabled:Bool;
    private var benchmarkSavedResolution:Float;
    #end
    
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
        #if woc_gpu_trails
        trails = new GpuTrailSurface();
        foreground = new Sprite();
        foreground.mouseEnabled = false;
        marks = new Sprite();
        playArea.addChild(trails);
        collisionRipples = new CollisionRippleView();
        collisionRipples.scaleX = backgroundWidth / 700;
        collisionRipples.scaleY = backgroundHeight / 500;
        playArea.addChild(foreground);
        playArea.addChild(collisionRipples);
        diagnostics = new TextField();
        diagnostics.defaultTextFormat = new TextFormat("_sans", 12, 0xFFFFFF);
        diagnostics.background = true;
        diagnostics.backgroundColor = 0x12141A;
        diagnostics.width = backgroundWidth;
        diagnostics.height = 22;
        diagnostics.y = backgroundHeight - 22;
        diagnostics.selectable = false;
        diagnostics.mouseEnabled = true;
        diagnostics.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent) {
            e.stopImmediatePropagation();
            if (benchmarkMode >= 0) return;
            if (e.shiftKey) trails.halfLife = trails.halfLife >= 1 ? 0.1 : trails.halfLife * 1.5;
            else toggleTrails();
        });
        playArea.addChild(diagnostics);
        addEventListener(Event.ADDED_TO_STAGE, attachTrailKeys);
        addEventListener(Event.REMOVED_FROM_STAGE, detachTrailKeys);
        #end
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
        #if woc_gpu_trails
        // History is presentation state: it must not depend on consumeDirty().
        updateTrails();
        collisionRipples.update(sequencer.collisionCues, sequencer.collisionEpoch, sequencer.getLogicalTime(), sequencer.blocks);
        #end
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
        } else if (Gbloink.isSpeedUid(componentId) || Gbloink.isNoteVelocityUid(componentId) || componentId == Gbloink.NOTE_LENGTH_UID) {
            redrawValueControl(componentId);
        } else if (componentId == Gbloink.SCALE_SELECT_UID) {
            if (semanticSelect != null) semanticSelect.setSelectedIndex(sequencer.getScaleIndex());
        }
    }
    
    private function redrawPlayArea():Void {
        playArea.graphics.clear();
        #if woc_gpu_trails
        foreground.graphics.clear();
        var ink = trails.visible ? foreground.graphics : playArea.graphics;
        #else
        var ink = playArea.graphics;
        #end
        
        // Draw background
        playArea.graphics.beginFill(0x12141A);
        playArea.graphics.drawRect(0, 0, backgroundWidth, backgroundHeight);
        playArea.graphics.endFill();
        
        // Draw balls
        for (ball in sequencer.getBalls()) {
            var localPos = ball.pos;
            var displayPos = localToPlayAreaDisplay(localPos);
            
            ink.beginFill(ball.colour);
            ink.drawCircle(
                displayPos.x,
                displayPos.y,
                playArea.localLengthToWindowLength(ball.rad));
            ink.endFill();
        }
        
        // Draw blocks
        for (block in sequencer.getBlocks()) {
            var localPos = block.bounds.topLeft();
            var displayPos = localToPlayAreaDisplay(localPos);
            
            ink.beginFill(block.colour, 200 / 255);
            ink.drawRect(
                displayPos.x,
                displayPos.y,
                playArea.localLengthToWindowLength(block.bounds.width()),
                playArea.localLengthToWindowLength(block.bounds.height()));
            ink.endFill();
        }
    }

    #if woc_gpu_trails
    private function attachTrailKeys(e:Event):Void {
        if (e.target != this || keyStage != null) return;
        keyStage = stage;
        keyStage.addEventListener(KeyboardEvent.KEY_DOWN, trailKey);
    }

    private function detachTrailKeys(e:Event):Void {
        if (e.target != this) return;
        if (keyStage != null) keyStage.removeEventListener(KeyboardEvent.KEY_DOWN, trailKey);
        keyStage = null;
        trails.destroy();
    }

    private function trailKey(e:KeyboardEvent):Void {
        if (benchmarkMode >= 0) return;
        if (e.keyCode == 84) {
            toggleTrails();
        } else if (e.keyCode == 219) trails.halfLife = Math.max(0.03, trails.halfLife / 1.4);
        else if (e.keyCode == 221) trails.halfLife = Math.min(3, trails.halfLife * 1.4);
        else if (e.keyCode == 82) {
            trails.resolutionScale = trails.resolutionScale == 1 ? 0.5 : 1;
            trails.dispose();
            frameStamp = -1;
            frameWindow = 0;
            frameSamples = 0;
            submitTotal = 0;
        }
        else if (e.keyCode == 66 && benchmarkMode < 0) {
            benchmarkSavedEnabled = effectsEnabled;
            benchmarkSavedResolution = trails.resolutionScale;
            beginBenchmarkMode(0);
        }
    }

    private function toggleTrails():Void {
        effectsEnabled = !effectsEnabled;
        trails.dispose();
        frameStamp = -1;
        frameWindow = 0;
        frameSamples = 0;
        submitTotal = 0;
        trails.visible = false;
        redrawPlayArea();
    }

    private function updateTrails():Void {
        var now = haxe.Timer.stamp();
        updateBenchmark(now);
        if (frameStamp >= 0) {
            frameWindow += now - frameStamp;
            frameSamples++;
        }
        frameStamp = now;
        if (frameWindow >= 2) {
            lastFps = frameSamples / frameWindow;
            trace('TRAIL_BENCH ' + (trails.visible ? 'on' : 'off') + ' fps=' + lastFps
                + ' meanSubmitMs=' + submitTotal / frameSamples);
            frameWindow = 0;
            frameSamples = 0;
            submitTotal = 0;
        }
        var revision = sequencer.getModelStatus().stateRevision;
        var time = sequencer.getLogicalTime();
        if (revision != lastRevision || time < lastModelTime) trails.dispose();
        lastRevision = revision;
        if (effectsEnabled && trails.passMode == 2) marks.graphics.clear();
        if (effectsEnabled && trails.passMode == 2 && time != lastModelTime) {
            for (ball in sequencer.getBalls()) {
                var p = localToPlayAreaDisplay(ball.pos);
                marks.graphics.beginFill(ball.colour, 0.65);
                marks.graphics.drawCircle(p.x, p.y, playArea.localLengthToWindowLength(ball.rad));
                marks.graphics.endFill();
            }
        }
        lastModelTime = time;
        var wasVisible = trails.visible;
        trails.visible = effectsEnabled && trails.update(stage, Math.ceil(backgroundWidth), Math.ceil(backgroundHeight), marks);
        if (trails.visible) submitTotal += trails.passMilliseconds;
        if (benchmarkMode >= 0 && benchmarkMeasuring) {
            benchmarkSubmit += trails.visible ? trails.passMilliseconds : 0;
            benchmarkFrames++;
        }
        if (wasVisible != trails.visible) redrawPlayArea();
        // TextField changes rasterize/upload text; keep diagnostics out of the hot path.
        if (now - statusStamp < 0.5) return;
        statusStamp = now;
        diagnostics.text = 'Click/T: trails ${trails.visible ? "on" : "off"}  Shift-click/[ / ]: half-life ${Math.round(trails.halfLife * 1000)} ms'
            + '  | CPU submit: ${trails.visible ? Math.round(trails.passMilliseconds * 100) / 100 : 0} ms'
            + ' | ${Math.round(lastFps)} fps'
            + ' | R: ${trails.resolutionScale == 1 ? "full" : "half"} res'
            + (trails.gpuMilliseconds == null ? '' : ' | GPU: ' + Math.round(trails.gpuMilliseconds * 1000) / 1000 + ' ms')
            + (benchmarkMode >= 0 ? ' | BENCH ' + benchmarkMode : ' | B: benchmark')
            + (trails.failure == null ? '' : ' | ' + trails.failure);
    }

    private function beginBenchmarkMode(mode:Int):Void {
        benchmarkMode = mode;
        // Repeat baseline around the effect modes to expose machine/browser variability.
        effectsEnabled = mode != 0 && mode != 5;
        trails.passMode = mode == 1 ? 0 : (mode == 2 ? 1 : 2);
        trails.resolutionScale = mode == 4 ? 0.5 : 1;
        trails.dispose();
        benchmarkStart = haxe.Timer.stamp();
        benchmarkMeasuring = false;
        benchmarkPreviousStamp = -1;
        benchmarkIntervals = [];
        benchmarkSubmit = 0;
        benchmarkFrames = 0;
        trace('TRAIL_PROFILE starting ' + benchmarkName(mode) + ' (2 s warmup + 6 s sample)');
    }

    private static function benchmarkName(mode:Int):String {
        return ['classic-before', 'copy-full', 'decay-full', 'trails-full', 'trails-half', 'classic-after'][mode];
    }

    private function updateBenchmark(now:Float):Void {
        if (benchmarkMode < 0) return;
        if (!benchmarkMeasuring && now - benchmarkStart >= 2) {
            benchmarkMeasuring = true;
            benchmarkStart = now;
            benchmarkModelStart = sequencer.getLogicalTime();
            benchmarkPreviousStamp = now;
            return;
        }
        if (!benchmarkMeasuring) return;
        benchmarkIntervals.push((now - benchmarkPreviousStamp) * 1000);
        benchmarkPreviousStamp = now;
        if (now - benchmarkStart < 6) return;
        benchmarkIntervals.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
        trace('TRAIL_PROFILE result ' + haxe.Json.stringify({
            mode: benchmarkName(benchmarkMode),
            seconds: now - benchmarkStart,
            fps: benchmarkIntervals.length / (now - benchmarkStart),
            medianFrameMs: benchmarkIntervals[Std.int(benchmarkIntervals.length * 0.5)],
            p95FrameMs: benchmarkIntervals[Std.int(benchmarkIntervals.length * 0.95)],
            longestFrameMs: benchmarkIntervals[benchmarkIntervals.length - 1],
            stalledFrames: benchmarkIntervals.filter(function(ms) return ms > 250).length,
            meanSubmitMs: benchmarkSubmit / Math.max(1, benchmarkFrames),
            latestGpuMs: trails.visible ? trails.gpuMilliseconds : null,
            modelSecondsPerWallSecond: (sequencer.getLogicalTime() - benchmarkModelStart) / (now - benchmarkStart)
        }));
        if (benchmarkMode < 5) beginBenchmarkMode(benchmarkMode + 1);
        else {
            benchmarkMode = -1;
            effectsEnabled = benchmarkSavedEnabled;
            trails.resolutionScale = benchmarkSavedResolution;
            trails.passMode = 2;
            trails.dispose();
            trace('TRAIL_PROFILE complete');
        }
    }
    #end

    private function localToPlayAreaDisplay(localPoint:LocalPoint):LocalPoint {
        var windowPoint = playArea.localToWindow(localPoint);
        return new LocalPoint(windowPoint.x - playArea.x, windowPoint.y - playArea.y);
    }
}
