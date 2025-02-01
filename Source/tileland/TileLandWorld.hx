package tileland;

import worldofcake.IControlPanelView;
import worldofcake.ui.PlayArea;
import worldofcake.ui.BaseComponent;
import worldofcake.ui.IFullApp;
import worldofcake.ui.Slider;
import worldofcake.ui.SliderView;
import tileland.TileLandLayout;
import worldofcake.CoordinateMapper;

class TileLandWorld implements IFullApp {
    private var sequencer:TileLandSequencer;
    private var view:TileLandView;
    private var components:Array<BaseComponent>;
    private var activeComponent:BaseComponent;
    
    // Keep references to controls we need to update
    private var speedSliders:Array<SliderView>;
    private var channelSlider:SliderView;
    
    private var windowToPanelMapper:CoordinateMapper;  // window coords -> panel virtual coords
    private var panelToPlayAreaMapper:CoordinateMapper;  // panel virtual coords -> play area coords
    
    public function new(width:Int, height:Int) {
        sequencer = new TileLandSequencer();
        
        // Create mapper for window->panel space
        windowToPanelMapper = new CoordinateMapper(
            TileLandLayout.PANEL_OFFSET_X,                           // space1 min x (window)
            TileLandLayout.PANEL_OFFSET_X + TileLandLayout.PANEL_WIDTH,  // space1 max x
            TileLandLayout.PANEL_OFFSET_Y,                           // space1 min y
            TileLandLayout.PANEL_OFFSET_Y + TileLandLayout.PANEL_HEIGHT, // space1 max y
            0,                                                       // space2 min x (panel)
            TileLandLayout.PANEL_WIDTH,                             // space2 max x
            0,                                                       // space2 min y
            TileLandLayout.PANEL_HEIGHT                             // space2 max y
        );
        
        // Maps panel coordinates to play area local coordinates
        panelToPlayAreaMapper = new CoordinateMapper(
            TileLandLayout.PLAY_AREA_OFFSET_X,                              // space1 min x (panel)
            TileLandLayout.PLAY_AREA_OFFSET_X + TileLandLayout.PLAY_AREA_WIDTH,  // space1 max x
            TileLandLayout.PLAY_AREA_OFFSET_Y,                              // space1 min y
            TileLandLayout.PLAY_AREA_OFFSET_Y + TileLandLayout.PLAY_AREA_HEIGHT, // space1 max y
            0,                                                              // space2 min x (local)
            TileLandLayout.PLAY_AREA_WIDTH,                                // space2 max x
            0,                                                              // space2 min y
            TileLandLayout.PLAY_AREA_HEIGHT                                // space2 max y
        );
        
        view = new TileLandView(sequencer);
        components = [];
        setupComponents();
    }
    
    // IFullApp implementation
    public function handleMouseDown(screenX:Float, screenY:Float):Void {
        trace('Mouse down at screen coords: ${screenX},${screenY}');
        trace('Testing components in order:');
        trace('Number of components: ${components.length}');
        for (component in components) {
            trace('- Component ${component.uid} (${Type.getClassName(Type.getClass(component))})');
            if (component.handleMouseDown(screenX, screenY)) {
                trace('  -> Component ${component.uid} handled click');
                activeComponent = component;
                return;
            }
        }
    }
    
    public function handleMouseDrag(screenX:Float, screenY:Float):Void {
        if (activeComponent != null) {
            activeComponent.handleMouseDrag(screenX, screenY);
        }
    }
    
    public function handleMouseUp(screenX:Float, screenY:Float):Void {
        if (activeComponent != null) {
            activeComponent.handleMouseUp(screenX, screenY);
            activeComponent = null;
        }
    }
    
    public function handleKeyPressed(key:String):Void {
        sequencer.keyPressed(0, key);
    }
    
    public function resize(width:Float, height:Float):Void {
        // Instead of updating dimensions, we need to create a new mapper
        windowToPanelMapper = new CoordinateMapper(
            TileLandLayout.PANEL_OFFSET_X,
            TileLandLayout.PANEL_OFFSET_X + TileLandLayout.PANEL_WIDTH,
            TileLandLayout.PANEL_OFFSET_Y,
            TileLandLayout.PANEL_OFFSET_Y + TileLandLayout.PANEL_HEIGHT,
            0,
            TileLandLayout.PANEL_WIDTH,
            0,
            TileLandLayout.PANEL_HEIGHT
        );
    }
    
    public function getView():IControlPanelView {
        return view;
    }
    
    // Method to get sequencer for view
    public function getSequencer():TileLandSequencer {
        return sequencer;
    }
    
    private function setupComponents():Void {
        // Create play area
        var playArea = new PlayArea(
            1,              // uid
            TileLandLayout.PLAY_AREA_OFFSET_X,
            TileLandLayout.PLAY_AREA_OFFSET_Y,
            TileLandLayout.PLAY_AREA_WIDTH,
            TileLandLayout.PLAY_AREA_HEIGHT,
            windowToPanelMapper,
            sequencer,
            1              // areaUid
        );
        components.push(playArea);
        
        // Create speed sliders
        speedSliders = [];
        var sliderX = [640, 680, 720];
        var colors = [0xFF0000, 0x00FF00, 0x0000FF];
        
        for (i in 0...3) {
            var component = new worldofcake.ui.Slider(
                10 + i,         // uid
                sliderX[i],     // x
                50,            // y
                30,            // width
                150,           // height
                windowToPanelMapper,
                sequencer,
                1.0,           // min
                80.0,          // max
                true           // vertical
            );
            components.push(component);
            
            var view = new SliderView(component, true, colors[i]);
            speedSliders.push(view);
            this.view.addChild(view);
        }
        
        // Create MIDI channel slider
        var channelComponent = new worldofcake.ui.Slider(
            20,             // uid
            640,           // x
            250,           // y
            120,           // width
            30,            // height
            windowToPanelMapper,
            sequencer,
            1,             // min
            14,            // max
            false          // horizontal
        );
        components.push(channelComponent);
        
        channelSlider = new SliderView(channelComponent, false, 0x808080);
        this.view.addChild(channelSlider);
        
        view.setSliders(speedSliders, channelSlider);
    }
} 