package worldofcake;

interface IControlPanelView {
    /** Redraw the view when its target snapshot/model revision changes. */
    function redrawDirty():Void;

}
