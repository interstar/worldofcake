package kdiagram;

import worldofcake.LocalPoint;
import worldofcake.IControlPanelView;
import worldofcake.ui.PlayArea;
import worldofcake.ui.BaseComponent;
import worldofcake.ui.IFullApp;
import worldofcake.ui.Slider;
import worldofcake.ISequencerControl;
import kdiagram.KDiagramLayout;
import worldofcake.CoordinateMapper;
import worldofcake.WindowPoint;
import worldofcake.BasePoint;
import worldofcake.ui.IComponent;



class KDiagramWorld implements IFullApp {
    private var sequencer:KDiagramSequencer;
    private var view:KDiagramView;
    private var components:Array<IComponent>;
    private var activeComponent:IComponent;
    
    // Keep references to controls we need to update
    private var speedSliders:Array<Slider>;
    private var channelSlider:Slider;
    
    private var windowToPanelMapper:CoordinateMapper;
    
    public function new() {
        // Create window->panel mapper
        windowToPanelMapper = new CoordinateMapper(
            new BasePoint(0, 0),                    // Window min (physical pixels)
            new BasePoint(KDiagramLayout.WINDOW_WIDTH, KDiagramLayout.WINDOW_HEIGHT),  // Window max (physical pixels)
            new BasePoint(0, 0),                    // Panel min (virtual coordinates)
            new BasePoint(KDiagramLayout.PANEL_WIDTH, KDiagramLayout.PANEL_HEIGHT)   // Panel max (virtual coordinates)
        );
        
        sequencer = new KDiagramSequencer();
        view = new KDiagramView(sequencer, windowToPanelMapper);
        
        components = [];
        speedSliders = [];
        setupComponents();
    }
    
    private function setupComponents():Void {
        // Create play area
        var playArea = new PlayArea(
            KDiagramSequencer.PLAY_AREA_UID,
            KDiagramLayout.PLAY_AREA_X,
            KDiagramLayout.PLAY_AREA_Y,
            KDiagramLayout.PLAY_AREA_WIDTH,
            KDiagramLayout.PLAY_AREA_HEIGHT,
            windowToPanelMapper,
            new LocalPoint(0,0),
            new LocalPoint(KDiagramLayout.PANEL_WIDTH, KDiagramLayout.PANEL_HEIGHT),
            sequencer
        );
        components.push(playArea);
        view.setPlayArea(playArea);
        
        // Create speed sliders
        var speedX = [KDiagramLayout.SPEED_SLIDER_X1, 
                     KDiagramLayout.SPEED_SLIDER_X2, 
                     KDiagramLayout.SPEED_SLIDER_X3];
        
        var colors = [0xFF0000, 0x00FF00, 0x0000FF];
        
        speedSliders = [];
        for (i in 0...3) {
            var slider = new Slider(
                10 + i, speedX[i], KDiagramLayout.SPEED_SLIDER_Y,
                KDiagramLayout.SPEED_SLIDER_WIDTH, KDiagramLayout.SPEED_SLIDER_HEIGHT,
                windowToPanelMapper, sequencer,
                1.0, 80.0, true, colors[i]
            );
            components.push(slider);
            speedSliders.push(slider);
            view.addChild(slider);  // Add directly to view
        }
        
        // Create channel slider
        channelSlider = new Slider(
            20, KDiagramLayout.CHANNEL_SLIDER_X, KDiagramLayout.CHANNEL_SLIDER_Y,
            KDiagramLayout.CHANNEL_SLIDER_WIDTH, KDiagramLayout.CHANNEL_SLIDER_HEIGHT,
            windowToPanelMapper, sequencer,
            1, 14, false, 0x808080
        );
        components.push(channelSlider);
        view.addChild(channelSlider);
        
        // Set the sliders in the view
        view.setSliders(speedSliders, channelSlider);
    }
    
    // IFullApp implementation
    public function handleMouseDown(windowPoint:WindowPoint):Void {
        trace('Mouse down at window coords: ${windowPoint.x},${windowPoint.y}');
        trace('Testing components in order:');
        trace('Number of components: ${components.length}');
        for (component in components) {
            trace('- Component ${component.getUID()} (${Type.getClassName(Type.getClass(component))})');
            if (component.handleMouseDown(windowPoint)) {
                trace('  -> Component ${component.getUID()} handled click');
                activeComponent = component;
                return;
            }
        }
    }
    
    public function handleMouseDrag(windowPoint:WindowPoint):Void {
        if (activeComponent != null) {
            activeComponent.handleMouseDrag(windowPoint);
        }
    }
    
    public function handleMouseUp(windowPoint:WindowPoint):Void {
        if (activeComponent != null) {
            activeComponent.handleMouseUp(windowPoint);
            activeComponent = null;
        }
    }
    
    public function handleKeyPressed(key:String):Void {
        sequencer.keyPressed(KDiagramSequencer.PLAY_AREA_UID, key);
    }
    
    public function getView():IControlPanelView {
        return view;
    }
    
    public function resize(width:Float, height:Float):Void {
        windowToPanelMapper = new CoordinateMapper(
            new BasePoint(0, 0),                    // Window min (physical pixels)
            new BasePoint(width, height),           // Window max (physical pixels)
            new BasePoint(0, 0),                    // Panel min (virtual coordinates)
            new BasePoint(KDiagramLayout.PANEL_WIDTH, KDiagramLayout.PANEL_HEIGHT)   // Panel max (virtual coordinates)
        );
 
    }
    
    public function getSequencer():KDiagramSequencer {
        return cast sequencer;
    }
} 