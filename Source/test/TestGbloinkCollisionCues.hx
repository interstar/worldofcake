package test;

import gbloink.Gbloink;
import gbloink.Gbloink.Block;
import worldofcake.LocalPoint;
import worldofcake.LocalRect;
import worldofcake.SeededRandomSource;

class TestGbloinkCollisionCues {
    static function check(name:String, condition:Bool):Void {
        if (!condition) throw 'FAIL $name';
        Sys.println('PASS $name');
    }
    static function near(a:Float, b:Float):Bool return Math.abs(a-b) < 0.000001;
    static function fixture():Gbloink {
        var app = new Gbloink(new LocalPoint(700, 500), new SeededRandomSource(17));
        app.blocks = [];
        for (i in 0...app.balls.length) {
            app.balls[i].pos = new LocalPoint(350+i*80, 350);
            app.balls[i].velocity = new LocalPoint(0, 0);
        }
        return app;
    }

    public static function main():Void {
        var wall = fixture();
        wall.setMuted(true);
        wall.setNoteVelocity(0, 24);
        wall.balls[0].pos = new LocalPoint(5, 100);
        wall.balls[0].velocity = new LocalPoint(-20, 0);
        wall.advanceTime(0.001);
        check("muted wall still publishes cosmetic impact", wall.collisionCues.length == 1);
        var cue = wall.collisionCues[0];
        check("wall contact and authoritative timestamp", cue.kind == 0 && near(cue.x, 0) && near(cue.y, 100) && near(cue.time, 0.001));
        check("wall cue has no block target", cue.blockId == -1);
        check("impact captures velocity", cue.velocity == 24);
        wall.setNoteVelocity(0, 120);
        check("velocity edit does not resize an existing impact", cue.velocity == 24);
        check("cosmetic wall impact does not introduce MIDI", wall.events.length == 0);

        var pair = fixture();
        pair.balls[0].pos = new LocalPoint(100, 100);
        pair.balls[1].pos = new LocalPoint(109.9, 100);
        pair.balls[0].velocity = new LocalPoint(10, 0);
        pair.balls[1].velocity = new LocalPoint(-10, 0);
        pair.setNoteVelocity(0, 20);
        pair.setNoteVelocity(1, 110);
        pair.advanceTime(0.001);
        check("pair publishes two brighter-kind cues", pair.collisionCues.length == 2 && pair.collisionCues[0].kind == 2 && pair.collisionCues[1].kind == 2);
        check("pair retains independent velocities and colours", pair.collisionCues[0].velocity == 20 && pair.collisionCues[1].velocity == 110 && pair.collisionCues[0].colour != pair.collisionCues[1].colour);
        check("pair shares contact point", near(pair.collisionCues[0].x, pair.collisionCues[1].x) && near(pair.collisionCues[0].y, pair.collisionCues[1].y));
        check("ball pair has no block flash target", pair.collisionCues[0].blockId == -1 && pair.collisionCues[1].blockId == -1);
        pair.advanceTime(0.001);
        check("separating pair does not repeat impact", pair.collisionCues.length == 2);
        check("pair plays each ball once with its own channel and velocity", pair.events.length == 2
            && pair.events[0].type == 0 && pair.events[1].type == 0
            && pair.events[0].data1 == pair.balls[0].channel && pair.events[1].data1 == pair.balls[1].channel
            && pair.events[0].data3 == 20 && pair.events[1].data3 == 110);
        check("pair pitch follows contact height", pair.events[0].data2 == pair.noteCalc.transform(pair.collisionCues[0].y)
            && pair.events[1].data2 == pair.events[0].data2);
        pair.advanceTime(0.1);
        var released = 0;
        for (event in pair.events) if (event.type == 2) released++;
        check("pair notes receive matching note-offs", released == 2);

        var block = fixture();
        var obstacle = new Block(new LocalPoint(165, 100), new SeededRandomSource(1));
        obstacle.bounds = new LocalRect(150, 80, 180, 120);
        block.blocks.push(obstacle);
        block.balls[0].pos = new LocalPoint(144.99, 100);
        block.balls[0].velocity = new LocalPoint(20, 0);
        block.advanceTime(0.001);
        check("block impact originates on struck face", block.collisionCues.length == 1 && block.collisionCues[0].kind == 1 && near(block.collisionCues[0].x, 150));
        check("block cue identifies exactly the struck block", block.collisionCues[0].blockId == obstacle.id);
        var replacement = new Block(new LocalPoint(165,100),new SeededRandomSource(1));
        check("replacement block does not inherit an old flash", replacement.id != block.collisionCues[0].blockId);
        check("block note output is preserved", block.events.length == 1 && block.events[0].type == 0);

        var bounded = fixture();
        for (i in 0...200) {
            bounded.balls[0].pos = new LocalPoint(4.99, 30+(i%30)*12);
            bounded.balls[0].velocity = new LocalPoint(-50, 0);
            bounded.advanceTime(0.001);
        }
        check("history stays bounded under dense impacts", bounded.collisionCues.length == Gbloink.MAX_COLLISION_CUES);
        check("history retains newest impacts", bounded.collisionCues[bounded.collisionCues.length-1].serial == 200);
        var epoch = bounded.collisionEpoch;
        bounded.resetTransport();
        check("transport reset clears cues and changes epoch", bounded.collisionCues.length == 0 && bounded.collisionEpoch != epoch);
        wall.importStateJson(wall.exportStateJson());
        check("restoration does not replay old impacts", wall.collisionCues.length == 0);
        block.balls[0].velocity = new LocalPoint(0, 0);
        block.advanceTime(1);
        check("old impacts expire", block.collisionCues.length == 0);
    }
}
