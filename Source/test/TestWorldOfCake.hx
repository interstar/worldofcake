package test;

import worldofcake.CoordinateMapper;
import worldofcake.ComposedCoordinateMapper;
import worldofcake.BasePoint;

class TestWorldOfCake {
    static var ERRORS = 0;

    static function floatEquals(a:Float, b:Float):Bool {
        return Math.abs(a - b) < 0.0001;
    }

    static function testit(id:String, val:Dynamic, target:Dynamic, msg:String) {
        if (Std.isOfType(val, Float) && Std.isOfType(target, Float)) {
            if (!floatEquals(val, target)) {
                trace("ERROR IN " + id + " : " + msg);
                trace("Wanted:*" + Std.string(target) + "**");
                trace("Got:*" + Std.string(val) + "**");
                ERRORS = ERRORS + 1;
            } else {
                trace(id + " OK");
            }
            return;
        }
        if (!deepEquals(val, target)) {
            trace("ERROR IN " + id + " : " + msg);
            trace("Wanted:*" + Std.string(target) + "**");
            trace("Got:*" + Std.string(val) + "**");
            compareDetails(val, target);
            ERRORS = ERRORS + 1;
        } else {
            trace(id + " OK");
        }
    }

    static function deepEquals(a:Dynamic, b:Dynamic):Bool {
        if (a == null || b == null) return a == b;

        if (Std.isOfType(a, Array) && Std.isOfType(b, Array)) {
            if (a.length != b.length) return false;
            for (i in 0...a.length) {
                if (!deepEquals(a[i], b[i])) return false;
            }
            return true;
        }

        // Special case for coordinate objects
        if (Reflect.hasField(a, "x") && Reflect.hasField(a, "y") &&
            Reflect.hasField(b, "x") && Reflect.hasField(b, "y")) {
            return Math.abs(a.x - b.x) < 0.0001 && Math.abs(a.y - b.y) < 0.0001;
        }

        return a == b;
    }

    static function compareDetails(val:Dynamic, target:Dynamic) {
        // Add detailed comparison if needed
    }

    public static function main() {
        testCoordinateMapper();
        testComposedMapper();
        testSliderMapping();
        testSpeedSliderMapping();
        
        if (ERRORS == 0) {
            trace("All tests passed!");
        } else {
            trace('${ERRORS} tests failed!');
        }
    }

    static function testCoordinateMapper() {
        // Test window (0,0,800,600) to panel (0,0,800,600) mapping
        var mapper = new CoordinateMapper(
            new BasePoint(0, 0),
            new BasePoint(800, 600),
            new BasePoint(0, 0),
            new BasePoint(800, 600)
        );

        var result = mapper.forward(400, 300);
        testit("basic_mapping", result, {x: 400, y: 300}, "Simple 1:1 mapping");

        // Test length mapping
        var length = mapper.lengthForward(100);
        testit("length_mapping", length, 100, "Length should map 1:1");
    }

    static function testComposedMapper() {
        // Test window->panel->local composed mapping
        var windowToPanel = new CoordinateMapper(
            new BasePoint(0, 0),
            new BasePoint(800, 600),
            new BasePoint(0, 0),
            new BasePoint(800, 600)
        );

        var panelToLocal = new CoordinateMapper(
            new BasePoint(0, 0),
            new BasePoint(150, 150),
            new BasePoint(0, 0),
            new BasePoint(1, 1)
        );

        var composed = new ComposedCoordinateMapper(windowToPanel, panelToLocal);

        var result = composed.forward(75, 75);
        testit("composed_mapping", result, {x: 0.5, y: 0.5}, "Should map through both spaces");
    }

    static function testSliderMapping() {
        // Test vertical slider (height 150, value range 4.0 -> 0.1)
        var verticalMapper = new CoordinateMapper(
            new BasePoint(0, 0),
            new BasePoint(0, 150),    // Height of slider in local space
            new BasePoint(0, 4.0),    // Max value at top
            new BasePoint(0, 0.1)     // Min value at bottom
        );

        // Test points along vertical slider
        var topValue = verticalMapper.forward(0, 0).y;
        testit("vertical_slider_top", topValue, 4.0, "Top of slider should be max value");
        
        var middleValue = verticalMapper.forward(0, 75).y;
        testit("vertical_slider_middle", middleValue, 2.05, "Middle of slider should be middle of value range");
        
        var bottomValue = verticalMapper.forward(0, 150).y;
        testit("vertical_slider_bottom", bottomValue, 0.1, "Bottom of slider should be min value");

        // Test horizontal slider (width 120, value range 1 -> 14)
        var horizontalMapper = new CoordinateMapper(
            new BasePoint(0, 0),
            new BasePoint(120, 0),    // Width of slider in local space
            new BasePoint(1.0, 0),    // Min value at left
            new BasePoint(14.0, 0)    // Max value at right
        );

        // Test points along horizontal slider
        var leftValue = horizontalMapper.forward(0, 0).x;
        testit("horizontal_slider_left", leftValue, 1.0, "Left of slider should be min value");
        
        var centerValue = horizontalMapper.forward(60, 0).x;
        testit("horizontal_slider_center", centerValue, 7.5, "Center of slider should be middle of value range");
        
        var rightValue = horizontalMapper.forward(120, 0).x;
        testit("horizontal_slider_right", rightValue, 14.0, "Right of slider should be max value");
    }

    static function testSpeedSliderMapping() {
        // Test vertical speed slider mapping (height 150, value range 4.0 -> 0.1)
        var mapper = new CoordinateMapper(
            new BasePoint(0, 0),
            new BasePoint(0, 150),    // Height of slider in local space
            new BasePoint(0, 4.0),    // Max value at top (y=0)
            new BasePoint(0, 0.1)     // Min value at bottom (y=150)
        );

        // Test key points along slider
        var topValue = mapper.forward(0, 0).y;
        testit("speed_slider_top", topValue, 4.0, "Top of slider (y=0) should map to max speed");
        
        var quarterValue = mapper.forward(0, 37.5).y;  // 25% down
        testit("speed_slider_quarter", quarterValue, 3.025, "Quarter down should map to 75% of speed range");
        
        var middleValue = mapper.forward(0, 75).y;  // 50% down
        testit("speed_slider_middle", middleValue, 2.05, "Middle should map to middle of speed range");
        
        var threeQuarterValue = mapper.forward(0, 112.5).y;  // 75% down
        testit("speed_slider_threequarter", threeQuarterValue, 1.075, "Three quarters down should map to 25% of speed range");
        
        var bottomValue = mapper.forward(0, 150).y;
        testit("speed_slider_bottom", bottomValue, 0.1, "Bottom of slider (y=150) should map to min speed");

        // Test reverse mapping
        var topPos = mapper.backward(0, 4.0).y;
        testit("speed_slider_pos_top", topPos, 0.0, "Max speed should map to top position");
        
        var bottomPos = mapper.backward(0, 0.1).y;
        testit("speed_slider_pos_bottom", bottomPos, 150.0, "Min speed should map to bottom position");
    }
} 