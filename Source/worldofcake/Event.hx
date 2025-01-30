package worldofcake;

class Event {
    public var timestamp:Float;
    public var type:Int;
    public var data1:Int;
    public var data2:Int;
    public var data3:Int;

    public function new(timestamp:Float, type:Int, data1:Int, data2:Int, data3:Int) {
        this.timestamp = timestamp;
        this.type = type;
        this.data1 = data1;
        this.data2 = data2;
        this.data3 = data3;
    }
} 