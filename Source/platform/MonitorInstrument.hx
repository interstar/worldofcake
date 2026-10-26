package platform;

import worldofcake.IInstrument;
import worldofcake.Event;

class MonitorInstrument implements IInstrument {
    private var frameCount:Int = 0;
    
    public function new() {
        trace("Monitor initialized");
    }
    
    public function send(e:Event):Void {
        if (e.type == worldofcake.EventType.ControlChange) {
            trace('CC Event: channel=${e.data1} controller=${e.data2} value=${e.data3}');
        } else {
            trace('Note Event: channel=${e.data1} note=${e.data2} velocity=${e.data3}');
        }
        frameCount++;
    }
} 