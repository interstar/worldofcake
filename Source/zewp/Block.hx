package zewp;

class Block {
    public var x:Float;
    public var y:Float;
    public var width:Float;
    public var height:Float;
    public var color:Int;
    
    public function new(x:Float, y:Float, width:Float, height:Float, color:Int) {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
        this.color = color;
    }
    
    public function hit(px:Float, py:Float):Bool {
        return (px >= x - width/2 && px <= x + width/2 &&
                py >= y - height/2 && py <= y + height/2);
    }
} 