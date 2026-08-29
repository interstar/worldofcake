package worldofcake.ui;

import worldofcake.WindowPoint;
import worldofcake.PanelPoint;
import worldofcake.LocalPoint;

interface IComponent {
    // Coordinate mapping methods
    function panelToWindow(panelPoint:PanelPoint):WindowPoint;
    function localToPanel(localPoint:LocalPoint):PanelPoint;
    function localToWindow(localPoint:LocalPoint):WindowPoint;
    function windowToLocal(windowPoint:WindowPoint):LocalPoint;
    function windowToPanel(windowPoint:WindowPoint):PanelPoint;
    function panelToLocal(panelPoint:PanelPoint):LocalPoint;
    function panelLengthToWindowLength(panelLength:Float):Float;
    function windowLengthToPanelLength(windowLength:Float):Float;
    function localLengthToWindowLength(localLength:Float):Float;
    function windowLengthToLocalLength(windowLength:Float):Float;

    
    // Input handling
    function handleMouseDown(windowPoint:WindowPoint):Bool;
    function handleMouseDragged(windowPoint:WindowPoint):Bool;
    function handleMouseUp(windowPoint:WindowPoint):Bool;
    
    // Properties
    function getUID():Int;

    public function getPosition():PanelPoint;
    public function getSize():PanelPoint;
    public function getMaxPoint():PanelPoint;
} 