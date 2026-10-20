package goldenpond;

import haxe.Json;
import worldofcake.Event;
import worldofcake.ISequencerControl;
import worldofcake.LoopingNotePlayer;
import GoldenData;
import TimedSequence.MidiInstrumentContext;
import generated.goldenpond.GoldenpondControlIdsGenerated;

/** WoC lifecycle wrapper around Goldenpond compilation and note playback. */
class GoldenpondSequencer extends worldofcake.SequencerCore implements ISequencerControl {
    public static inline var PLAYBACK_SPEED:Float = 1.0;
    public static inline var NOTE_ON_EVENT_TYPE:Int = 0;
    public static inline var NOTE_OFF_EVENT_TYPE:Int = 2;

    public var project:GoldenData;
    public var player:LoopingNotePlayer;
    public var lastCompileError:Null<String>;
    public var pianoRollZoom:Float;
    private var compilePending:Bool;
    private var compileDelay:Float;
    private var correctionRevision:Int;
    private var correctionChordCount:Int;
    private var cachedBpm:Float;
    private var cachedPpq:Float;
    private var cachedProjectJson:Null<String>;

    public function new(?initialProject:GoldenData) {
        super(true);
        project = initialProject == null ? defaultProject() : initialProject;
        lastCompileError = null;
        pianoRollZoom = 1.0;
        compilePending = false;
        compileDelay = 0.0;
        correctionRevision = 0;
        correctionChordCount = 1;
        cachedBpm = project.bpm;
        cachedPpq = project.ppq;
        player = new LoopingNotePlayer();
        compileNow();
    }

    public function compileNow():Bool {
        invalidateProjectJsonCache();
        // A rebuilt score supersedes all events from the previous key/scale/
        // pattern. Never let stale notes leak into the new sequence.
        clearEvents();
        try {
            var compiled = GoldenpondScoreCompiler.compile(project);
            var time = project.makeTimeManipulator();
            cachedBpm = time.getBPM();
            cachedPpq = time.getPPQ();
            var now = player.getPositionTicks();
            player.publish(compiled, now);
            correctionChordCount = Std.int(Math.round(compiled.loopLengthTicks / (project.ppq * project.chordDuration)));
            correctionRevision++;
            lastCompileError = null;
            dirty = true;
            return true;
        } catch (error:Dynamic) {
            lastCompileError = Std.string(error);
            dirty = true;
            return false;
        }
    }

    override function advanceModel(delta:Float):Bool {
        servicePendingCompile(delta);
        var deltaTicks = delta * PLAYBACK_SPEED * cachedBpm * cachedPpq / 60.0;
        player.advanceTicks(deltaTicks);
        drainPlayerEvents(cachedBpm, cachedPpq);
        return true;
    }

    public function servicePendingCompile(delta:Float):Void {
        if (!compilePending) return;
        compileDelay -= Math.max(0.0, delta);
        if (compileDelay <= 0.0) {
            compilePending = false;
            compileNow();
        }
    }

    /** Host tempo override used by DAW adapters; project BPM remains editable state. */
    public function setHostBpm(value:Float):Void {
        if (!Math.isFinite(value) || value <= 0) return;
        var normalized = Std.int(Math.round(value));
        if (normalized < 30) normalized = 30;
        if (normalized > 240) normalized = 240;
        project.bpm = normalized;
        cachedBpm = normalized;
        invalidateProjectJsonCache();
        dirty = true;
    }

    public function reset():Void {
        resetTransport();
    }

    override public function resetTransport(unpause:Bool = true):Void {
        super.resetTransport(unpause);
        player.reset();
        if (!unpause) player.stop();
        drainPlayerEvents(project.bpm, project.ppq);
    }

    override public function resetTransportPreservingState():Void {
        super.resetTransportPreservingState();
        player.reset();
        drainPlayerEvents(project.bpm, project.ppq);
    }

    public function exportStateJson():String {
        if (cachedProjectJson == null) cachedProjectJson = Json.stringify(project.toJSON());
        var envelope = Json.stringify({
            v: 1,
            kind: "goldenpond",
            currentTime: currentTime,
            paused: paused,
            muted: muted
        });
        return envelope.substr(0, envelope.length - 1) + ',"project":' + cachedProjectJson + '}';
    }

    public function importStateJson(json:String):Void {
        if (json == null || json == "") return;
        try {
            var saved:Dynamic = Json.parse(json);
            if (saved == null || saved.kind != "goldenpond" || saved.project == null) return;
            var restored = GoldenData.makeFromJSON(saved.project, new TimedSequence.DeserializationHelper());
            project = restored;
            markStateReplaced();
            currentTime = saved.currentTime == null ? 0 : Std.parseFloat(Std.string(saved.currentTime));
            paused = saved.paused == true;
            muted = saved.muted == true;
            player = new LoopingNotePlayer();
            compileNow();
            drainPlayerEvents(project.bpm, project.ppq);
        } catch (_:Dynamic) {
            // Invalid state is ignored, matching the ISequencer persistence contract.
        }
    }

    public function textSubmitted(uid:Int, text:String):Void {
        if (uid == GoldenpondControlIdsGenerated.CHORDINPUT) {
            project.chordSequence = text;
            requestCompile();
        } else {
            var index = -1;
            if (uid == GoldenpondControlIdsGenerated.RHYTHM0) index = 0;
            else if (uid == GoldenpondControlIdsGenerated.RHYTHM1) index = 1;
            else if (uid == GoldenpondControlIdsGenerated.RHYTHM2) index = 2;
            else if (uid == GoldenpondControlIdsGenerated.RHYTHM3) index = 3;
            if (index >= 0) {
                while (project.lines.length <= index) {
                    project.addLine("3%8 > 2", new MidiInstrumentContext(0, 100, 0.8, 0));
                }
                project.lines[index].pattern = text;
                requestCompile();
            }
        }
    }
    public function mouseDragged(uid:Int, point:worldofcake.LocalPoint):Void {}
    public function mouseDown(uid:Int, point:worldofcake.LocalPoint):Void {}
    public function mouseUp(uid:Int, point:worldofcake.LocalPoint):Void {}
    public function newValue(uid:Int, value:Float):Void {
        if (uid == GoldenpondControlIdsGenerated.BPM) {
            project.bpm = Std.int(Math.max(30, Math.min(240, value)));
            requestCompile();
        } else if (uid == GoldenpondControlIdsGenerated.CHORDDURATION) {
            project.chordDuration = Std.int(Math.max(1, Math.min(16, value)));
            requestCompile();
        } else if (uid == GoldenpondControlIdsGenerated.CORRECTIONTARGET) {
            project.setCorrectionTarget(Std.int(Math.max(0, Math.min(3, Math.round(value)))));
            invalidateProjectJsonCache();
            dirty = true;
        } else if (uid == GoldenpondControlIdsGenerated.KEYSELECT) {
            project.root = 60 + Std.int(Math.max(0, Math.min(11, Math.round(value))));
            requestCompile();
        } else if (uid == GoldenpondControlIdsGenerated.MODESELECT) {
            project.setMode(Std.int(Math.max(0, Math.min(6, Math.round(value)))));
            requestCompile();
        } else if (uid == GoldenpondControlIdsGenerated.PAUSE) {
            if (value > 0.5) pause(); else resume();
        } else if (uid == GoldenpondControlIdsGenerated.MUTE) {
            setMuted(value > 0.5);
        } else if (uid == GoldenpondControlIdsGenerated.ZOOM) {
            pianoRollZoom = Math.max(1.0, Math.min(8.0, value));
            dirty = true;
        } else {
            var part = partForControl(uid, "OCTAVE");
            if (part >= 0) setPartContext(part, null, Std.int(Math.round(value)) * 12);
            else {
                part = partForControl(uid, "VELOCITY");
                if (part >= 0) setPartContext(part, Std.int(Math.round(value)), null);
            }
        }
    }

    public function buttonPressed(uid:Int):Void {
        if (uid == GoldenpondControlIdsGenerated.RESET) reset();
        else if (uid == GoldenpondControlIdsGenerated.PAUSE) pause();
    }
    public function keyPressed(uid:Int, key:String):Void {}

    public function getSnapshot():worldofcake.SequenceSnapshot return player.getSnapshot();
    public function getPositionTicks():Float return player.getPositionTicks();
    public function getLoopPositionTicks():Float return player.getLoopPositionTicks();
    public function getPianoRollZoom():Float return pianoRollZoom;

    public function getCorrectionRevision():Int return correctionRevision;
    public function getCorrectionTarget():Int return project.correctionTarget;
    public function getKeyIndex():Int return ((project.root % 12) + 12) % 12;
    public function getModeIndex():Int return project.mode;

    public function getCorrectionKey(time:Float):Int {
        try {
            return project.getCorrectionKey(toGoldenpondTicks(time));
        } catch (_:Dynamic) {
            return -1;
        }
    }

    public function getCorrectionChordIndex(time:Float):Int {
        var chordTicks = project.ppq * project.chordDuration;
        if (!Math.isFinite(time) || time < 0 || chordTicks <= 0 || correctionChordCount <= 0) return -1;
        var ticks = time * PLAYBACK_SPEED * cachedBpm * cachedPpq / 60.0;
        var progressionIndex = Std.int(Math.floor(ticks / chordTicks));
        return progressionIndex % correctionChordCount;
    }

    public function makeCorrectionTable(time:Float, previousNote:Int = -1):Array<Int> {
        try {
            return project.makeCorrectionTable(toGoldenpondTicks(time), previousNote < 0 ? null : previousNote);
        } catch (_:Dynamic) {
            return [for (note in 0...128) note];
        }
    }

    public function makeBidirectionalCorrectionTable(time:Float):Array<Int> {
        try {
            return project.makeBidirectionalCorrectionTable(toGoldenpondTicks(time));
        } catch (_:Dynamic) {
            return [for (note in 0...128) note].concat([for (note in 0...128) note]);
        }
    }

    override public function correctInputNote(note:Int, time:Float, previousNote:Int = -1):Int {
        try {
            return project.correct(note, toGoldenpondTicks(time), previousNote < 0 ? null : previousNote);
        } catch (_:Dynamic) {
            return note;
        }
    }

    private function toGoldenpondTicks(time:Float):Float {
        return time * PLAYBACK_SPEED * cachedBpm * cachedPpq / 60.0;
    }

    private function partForControl(uid:Int, kind:String):Int {
        var ids = kind == "OCTAVE"
            ? [GoldenpondControlIdsGenerated.OCTAVE0, GoldenpondControlIdsGenerated.OCTAVE1, GoldenpondControlIdsGenerated.OCTAVE2, GoldenpondControlIdsGenerated.OCTAVE3]
            : [GoldenpondControlIdsGenerated.VELOCITY0, GoldenpondControlIdsGenerated.VELOCITY1, GoldenpondControlIdsGenerated.VELOCITY2, GoldenpondControlIdsGenerated.VELOCITY3];
        return ids.indexOf(uid);
    }

    private function setPartContext(index:Int, velocity:Null<Int>, transpose:Null<Int>):Void {
        if (index < 0 || index >= project.lines.length) return;
        var current:Dynamic = Json.parse(project.lines[index].instrumentContext.toJSON());
        var nextVelocity:Int = velocity == null ? Std.int(current.velocity) : Std.int(Math.max(1, Math.min(127, velocity)));
        var nextTranspose:Int = transpose == null ? Std.int(current.transpose) : Std.int(Math.max(-36, Math.min(36, transpose)));
        project.lines[index].instrumentContext = new MidiInstrumentContext(
            Std.int(current.chan), nextVelocity, current.gateLength, nextTranspose);
        requestCompile();
    }

    private function requestCompile():Void {
        invalidateProjectJsonCache();
        compilePending = true;
        compileDelay = 0.01;
        dirty = true;
    }

    private function invalidateProjectJsonCache():Void {
        cachedProjectJson = null;
    }

    private function drainPlayerEvents(bpm:Float, ppq:Float):Void {
        var secondsPerTick = 60.0 / (bpm * ppq * PLAYBACK_SPEED);
        while (player.hasEventBefore(player.getPositionTicks())) {
            var note = player.getNextEvent();
            var type = note.type == worldofcake.SequenceNoteEvent.NOTE_ON ? NOTE_ON_EVENT_TYPE : NOTE_OFF_EVENT_TYPE;
            // WoC's native note contract is channel/part, pitch, velocity.
            emitEvent(new Event(note.timestampTicks * secondsPerTick, type, note.partId, note.pitch, note.velocity));
        }
    }

    private static function defaultProject():GoldenData {
        var data = new GoldenData();
        data.chordSequence = "";
        data.lines = [];
        // Start empty. Users can enter a chord progression and patterns explicitly;
        // an empty project must not silently restore the historical demo score.
        return data;
    }
}
