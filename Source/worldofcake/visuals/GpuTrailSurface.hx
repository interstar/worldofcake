package worldofcake.visuals;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.display.Stage;
import openfl.display3D.Context3D;
import openfl.display3D.Context3DTextureFormat;
import openfl.display3D.textures.RectangleTexture;
import lime.ui.Window;
import lime.graphics.RenderContext;

/** Experimental OpenFL-only ping-pong surface. No readback or raw GL state manipulation. */
class GpuTrailSurface extends Bitmap {
    public var halfLife:Float = 0.22;
    public var resolutionScale:Float = 0.5;
    /** Profiling isolation: 0 = copy only, 1 = decay only, 2 = decay + marks. */
    public var passMode:Int = 2;
    public var passMilliseconds(default, null):Float = 0;
    /** Asynchronous GPU query result, when the browser exposes timer queries. */
    public var gpuMilliseconds(default, null):Null<Float>;
    public var failure(default, null):Null<String>;
    private var targets:Array<BitmapData> = [];
    private var textures:Array<RectangleTexture> = [];
    private var source:Bitmap;
    private var decay:TrailDecayShader;
    private var context:Context3D;
    private var index:Int = 0;
    private var lastStamp:Float = -1;
    private var scene:Sprite;
    private var window:Window;
    private var contextLost:Bool = false;
    #if (js && html5)
    private var timerGl:Dynamic;
    private var timerExtension:Dynamic;
    private var timerQueries:Array<Dynamic> = [];
    private var timerPending:Array<Bool> = [];
    private var timerFrame:Int = 0;
    #end

    public function new() {
        super();
        smoothing = true;
        source = new Bitmap();
        scene = new Sprite();
        scene.addChild(source);
        decay = new TrailDecayShader();
        source.shader = decay;
    }

    public function update(stage:Stage, w:Int, h:Int, marks:Sprite):Bool {
        if (failure != null) return false;
        if (stage == null || stage.context3D == null || contextLost) return false;
        if (window == null) {
            window = stage.window;
            window.onRenderContextLost.add(loseContext);
            window.onRenderContextRestored.add(restoreContext);
        }
        try {
            // Fixed design resolution, bounded independently of window zoom/HiDPI.
            var displayWidth = w;
            var displayHeight = h;
            w = Std.int(Math.max(1, Math.min(1536, Math.ceil(w * resolutionScale))));
            h = Std.int(Math.max(1, Math.min(1536, Math.ceil(h * resolutionScale))));
            if (context != stage.context3D || targets.length == 0 || targets[0].width != w || targets[0].height != h) {
                dispose();
                context = stage.context3D;
                trace('GPU trails backend: ' + context.driverInfo);
                #if (js && html5)
                var gl = stage.window.context.webgl;
                if (gl != null) {
                    var info:Dynamic = gl.getExtension("WEBGL_debug_renderer_info");
                    if (info != null) trace('GPU trails device: ' + gl.getParameter(info.UNMASKED_RENDERER_WEBGL));
                }
                timerGl = stage.window.context.webgl2;
                timerExtension = timerGl == null ? null : timerGl.getExtension("EXT_disjoint_timer_query_webgl2");
                if (timerExtension != null) {
                    for (i in 0...2) {
                        timerQueries.push(timerGl.createQuery());
                        timerPending.push(false);
                    }
                }
                trace('GPU trails timer queries: ' + (timerExtension != null ? 'available' : 'unavailable'));
                #end
                var seed = new Sprite();
                seed.graphics.beginFill(0x12141A);
                seed.graphics.drawRect(0, 0, w, h);
                seed.graphics.endFill();
                for (i in 0...2) {
                    var texture = context.createRectangleTexture(w, h, Context3DTextureFormat.BGRA, true);
                    textures.push(texture);
                    var target = BitmapData.fromTexture(texture);
                    targets.push(target);
                    target.draw(seed);
                }
                trace('GPU trails: allocated two ${w}x${h} hardware-only surfaces');
            }
            scaleX = displayWidth / w;
            scaleY = displayHeight / h;
            if (marks.parent != scene) scene.addChild(marks);
            marks.scaleX = w / displayWidth;
            marks.scaleY = h / displayHeight;
            marks.visible = passMode == 2;
            var started = haxe.Timer.stamp();
            var dt = lastStamp < 0 ? 0 : Math.max(0, started - lastStamp);
            lastStamp = started;
            decay.data.retention.value[0] = Math.pow(0.5, dt / Math.max(0.01, halfLife));
            source.bitmapData = targets[index];
            var next = 1 - index;
            #if (js && html5)
            var timerIndex = beginGpuTimer();
            #end
            // Full opaque quad replaces every pixel; never sample the destination.
            source.shader = passMode == 0 ? null : decay;
            // One renderer / framebuffer visit for history and marks together.
            try {
                targets[next].draw(scene);
            } catch (drawError:Dynamic) {
                #if (js && html5)
                if (timerIndex >= 0) timerGl.endQuery(timerExtension.TIME_ELAPSED_EXT);
                #end
                throw drawError;
            }
            #if (js && html5)
            if (timerIndex >= 0) {
                timerGl.endQuery(timerExtension.TIME_ELAPSED_EXT);
                timerPending[timerIndex] = true;
            }
            #end
            if (passMode != 0 && decay.program == null) throw "Trail shader did not create a program";
            index = next;
            bitmapData = targets[index];
            passMilliseconds = (haxe.Timer.stamp() - started) * 1000;
            return true;
        } catch (error:Dynamic) {
            failure = Std.string(error);
            trace('GPU trails disabled: ' + failure);
            dispose();
            return false;
        }
    }

    #if (js && html5)
    private function beginGpuTimer():Int {
        if (timerExtension == null || timerGl == null) return -1;
        var disjoint:Bool = timerGl.getParameter(timerExtension.GPU_DISJOINT_EXT);
        for (i in 0...timerQueries.length) {
            if (timerPending[i] && timerGl.getQueryParameter(timerQueries[i], timerGl.QUERY_RESULT_AVAILABLE)) {
                if (!disjoint) gpuMilliseconds = timerGl.getQueryParameter(timerQueries[i], timerGl.QUERY_RESULT) / 1000000.0;
                timerPending[i] = false;
            }
        }
        if (disjoint) gpuMilliseconds = null;
        // Sparse queries, preallocated and never waited on synchronously.
        timerFrame++;
        if (timerFrame % 30 != 0 || disjoint) return -1;
        for (i in 0...timerQueries.length) if (!timerPending[i]) {
            timerGl.beginQuery(timerExtension.TIME_ELAPSED_EXT, timerQueries[i]);
            return i;
        }
        return -1;
    }
    #end

    private function loseContext():Void {
        contextLost = true;
        dispose();
        trace('GPU trails: context lost; history discarded');
    }

    private function restoreContext(restored:RenderContext):Void {
        contextLost = false;
        failure = null;
        decay = new TrailDecayShader();
        source.shader = decay;
        trace('GPU trails: context restored; history will be recreated');
    }

    public function destroy():Void {
        dispose();
        if (window != null) {
            window.onRenderContextLost.remove(loseContext);
            window.onRenderContextRestored.remove(restoreContext);
            window = null;
        }
    }

    public function dispose():Void {
        #if (js && html5)
        if (timerGl != null) for (query in timerQueries) timerGl.deleteQuery(query);
        timerQueries = [];
        timerPending = [];
        timerGl = null;
        timerExtension = null;
        timerFrame = 0;
        #end
        gpuMilliseconds = null;
        bitmapData = null;
        source.bitmapData = null;
        for (target in targets) target.dispose();
        for (texture in textures) texture.dispose();
        targets = [];
        textures = [];
        context = null;
        index = 0;
        lastStamp = -1;
    }
}
