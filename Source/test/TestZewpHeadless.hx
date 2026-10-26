package test;
import zewp.ZewpSequencer;
import zewp.Zewp;
import worldofcake.LocalPoint;
import worldofcake.SeededRandomSource;

class TestZewpHeadless {
    static var failures=0;
    static function check(n:String,c:Bool):Void { Sys.println((c?"PASS ":"FAIL ")+n); if(!c) failures++; }
    static function near(a:Float,b:Float,e:Float=0.000001):Bool return Math.abs(a-b)<=e;
    static function make(seed:Int=12345):ZewpSequencer return new ZewpSequencer(600,560,new SeededRandomSource(seed));
    static function testSeedAndDelta():Void {
        var a=make(), b=make(), d=make(54321);
        check("zewp same seed world",a.exportStateJson()==b.exportStateJson());
        check("zewp different seed world",a.exportStateJson()!=d.exportStateJson());
        var r1=new SeededRandomSource(1), r2=new SeededRandomSource(1);
        var fine=new Zewp(100,100,10,4,0,1,10,r1), coarse=new Zewp(100,100,10,4,0,1,10,r2);
        for(_ in 0...100) fine.update([fine],[],1000,1000,0.001);
        coarse.update([coarse],[],1000,1000,0.1);
        check("zewp free-motion cadence",near(fine.position.x,coarse.position.x)&&near(fine.position.y,coarse.position.y));
    }
    static function testDragPauseState():Void {
        var app=make(); var block=app.getBlocks()[0]; var nx=block.bounds.center().x+20, ny=block.bounds.center().y+15;
        app.mouseDown(ZewpSequencer.PLAY_AREA_UID,new LocalPoint(block.bounds.center().x,block.bounds.center().y));
        app.mouseDragged(ZewpSequencer.PLAY_AREA_UID,new LocalPoint(nx,ny));
        app.mouseUp(ZewpSequencer.PLAY_AREA_UID,new LocalPoint(nx,ny));
        check("zewp drag block",near(block.bounds.center().x,nx)&&near(block.bounds.center().y,ny));
        var x=app.getZewps()[0].position.x; app.setPaused(true); app.advanceTime(1); check("zewp pause",near(x,app.getZewps()[0].position.x));
        app.setPaused(false); app.advanceTime(-1); app.advanceTime(Math.NaN); check("zewp invalid delta",near(x,app.getZewps()[0].position.x));
        app.advanceTime(0.001); var restored=make(999); restored.importStateJson(app.exportStateJson());
        var saved = app.exportStateJson();
        var reread = restored.exportStateJson();
        check("zewp state round trip",reread==saved);
    }
    static function testPlayAreaBounds():Void {
        var random=new SeededRandomSource(7);
        var z=new Zewp(599,559,10,4,0,1,10,random);
        z.setAngle(Math.PI/4); z.update([z],[],600,560,0.001);
        var extentX=Math.abs(Math.cos(z.angle))*z.length+2;
        var extentY=Math.abs(Math.sin(z.angle))*z.length+2;
        check("zewp complete glyph constrained horizontally",z.position.x>=extentX&&z.position.x<=600-extentX);
        check("zewp complete glyph constrained vertically",z.position.y>=extentY&&z.position.y<=560-extentY);

        var app=make(); var block=app.getBlocks()[0];
        app.mouseDown(ZewpSequencer.PLAY_AREA_UID,new LocalPoint(block.bounds.center().x,block.bounds.center().y));
        app.mouseDragged(ZewpSequencer.PLAY_AREA_UID,new LocalPoint(-100,-100));
        check("zewp dragged block constrained",block.bounds.center().x>=block.bounds.width()/2&&block.bounds.center().y>=block.bounds.height()/2);
    }
    static function testPopulationAndSpeed():Void {
        var app=make();
        app.newValue(ZewpSequencer.POPULATION_UID,40);
        check("zewp population grows to forty",app.getZewps().length==40);
        app.newValue(ZewpSequencer.POPULATION_UID,0);
        check("zewp population reaches zero",app.getZewps().length==0);
        app.newValue(ZewpSequencer.POPULATION_UID,1);
        var velocity=app.getZewps()[0].velocity;
        app.newValue(ZewpSequencer.SPEED_UID,1.5);
        check("zewp speed multiplier",near(app.getSpeedMultiplier(),1.5)&&near(app.getZewps()[0].velocity,velocity*1.5));
        app.newValue(ZewpSequencer.SPEED_UID,0);
        check("zewp speed lower clamp",near(app.getSpeedMultiplier(),ZewpSequencer.MIN_SPEED_MULTIPLIER));
    }
    public static function main():Void { testSeedAndDelta(); testDragPauseState(); testPlayAreaBounds(); testPopulationAndSpeed(); if(failures>0){Sys.println('$failures Zewp test(s) failed');Sys.exit(1);} Sys.println("All Zewp headless tests passed"); }
}
