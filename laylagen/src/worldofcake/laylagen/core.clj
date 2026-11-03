(ns worldofcake.laylagen.core
  (:require [clojure.edn :as edn]
            [clojure.java.io :as io]
            [clojure.pprint :as pprint]
            [clojure.string :as str]
            [layla.core :as layla]
            [worldofcake.laylagen.icons :as icons]))

(def generator-version 1)

(defn- children [node]
  (if (= :layout (:node-type node)) (:children node) []))

(defn- leaves [node]
  (if (= :leaf (:node-type node))
    [node]
    (mapcat leaves (children node))))

(defn labelled-containers
  "Layout nodes carrying a Layla %label, in document order."
  [node]
  (if (= :layout (:node-type node))
    (concat (when (:label node) [node]) (mapcat labelled-containers (:children node)))
    []))

(defn boxes
  "Labelled containers whose EDN component is a :box, with the container's placed geometry."
  [placed specs]
  (vec (for [node (labelled-containers placed)
             :let [spec (get specs (:label node))]
             :when (= :box (:kind spec))]
         (merge spec (select-keys node [:label :x :y :width :height])))))

(defn safe-symbol [value]
  (let [parts (->> (str/split (str value) #"[^A-Za-z0-9]+")
                   (remove str/blank?))
        joined (if (seq parts)
                 (str/lower-case (str/join "_" parts))
                 "component")]
    (if (re-find #"^[0-9]" joined) (str "component_" joined) joined)))

(defn- output-errors [outputs]
  (concat
   (for [[id n] (frequencies (map :id outputs)) :when (> n 1)]
     (str "Duplicate control output " (pr-str id)))
   (for [{:keys [id channel cc]} outputs
         :when (not (and (string? id) (int? channel) (<= 1 channel 16) (int? cc) (<= 0 cc 127)))]
     (str "Control output " (pr-str id) " needs a string :id, :channel 1..16 and :cc 0..127"))))

(defn- validate-config [document config]
  (let [root (when (= :layout (:document-type document)) (:root document))
        leaf-list (when root (vec (leaves root)))
        ids (mapv :id leaf-list)
        labels (mapv :label (when root (labelled-containers root)))
        specs (:components config)
        component-ids (set (keys specs))
        missing (remove component-ids ids)
        unused (remove (set (concat ids labels)) component-ids)
        bad-containers (filter #(when-let [kind (:kind (get specs %))] (not= :box kind)) labels)
        leaf-boxes (filter #(= :box (:kind (get specs %))) ids)
        symbols (map safe-symbol (concat ids labels))
        collisions (->> symbols frequencies (keep (fn [[s n]] (when (> n 1) s))) sort)
        errors (concat
                (when-not root ["The OpenFL/WorldOfCake target requires one layout, not pages."])
                (map #(str "Missing component configuration for " (pr-str %)) missing)
                (map #(str "Unused component configuration for " (pr-str %)) unused)
                (map #(str "Container " (pr-str %) " can only be configured as a :box (or with no :kind)") bad-containers)
                (map #(str "Leaf " (pr-str %) " cannot be a :box; label a container instead") leaf-boxes)
                (output-errors (:outputs config))
                (map #(str "Target-symbol collision for " (pr-str %)) collisions)
                (when-not (= generator-version (:generator-version config))
                  [(str "Unsupported generator version " (:generator-version config))]))]
    (when (seq errors)
      (throw (ex-info (str/join "\n" errors) {:errors (vec errors)})))
    root))

(defn- distribute [nodes available]
  (let [total (reduce + (map :weight nodes))]
    (mapv #(* available (/ (:weight %) total)) nodes)))

(declare place-node)

(defn- place-layout [node x y width height depth geometry]
  (let [padding (double (or (get-in geometry [:container-specs (:label node) :padding]) 0.0))
        node-rect {:x x :y y :width width :height height}
        x (+ x padding)
        y (+ y padding)
        width (- width padding padding)
        height (- height padding padding)
        items (:children node)
        configured-gap (get (:gaps-by-depth geometry) depth)
        gap (double (or configured-gap (if (zero? depth) (:root-gap geometry) (:nested-gap geometry))))
        horizontal? (#{:horizontal :responsive} (:layout-type node))
        major (if horizontal? width height)
        available (- major (* gap (max 0 (dec (count items)))))
        sizes (distribute items available)]
    (loop [remaining items sizes sizes cursor (if horizontal? x y) result []]
      (if (empty? remaining)
        (merge node node-rect {:children result})
        (let [item (first remaining)
              size (first sizes)
              placed (if horizontal?
                       (place-node item cursor y size height (inc depth) geometry)
                       (place-node item x cursor width size (inc depth) geometry))]
          (recur (rest remaining) (rest sizes) (+ cursor size gap) (conj result placed)))))))

(defn- place-node [node x y width height depth geometry]
  (if (= :leaf (:node-type node))
    (assoc node :x x :y y :width width :height height)
    (case (:layout-type node)
      (:horizontal :vertical :responsive) (place-layout node x y width height depth geometry)
      (throw (ex-info (str "Unsupported OpenFL layout type " (:layout-type node)) {:node node})))))

(defn calculate-geometry
  "Places the layout. `specs` (the EDN components) supply per-container :padding."
  ([root geometry] (calculate-geometry root geometry {}))
  ([root geometry specs]
  (let [fallback (double (or (:outer-padding geometry) 0.0))
        left (double (or (:padding-left geometry) fallback))
        right (double (or (:padding-right geometry) fallback))
        top (double (or (:padding-top geometry) fallback))
        bottom (double (or (:padding-bottom geometry) fallback))
        width (- (double (:panel-width geometry)) left right)
        height (- (double (:panel-height geometry)) top bottom)]
    (when (or (not (pos? width)) (not (pos? height)))
      (throw (ex-info "Outer padding leaves no usable panel area" {:geometry geometry})))
    (place-node root left top width height 0 (assoc geometry :container-specs specs)))))

(defn- fmt [number]
  (String/format java.util.Locale/ROOT "%.6f" (to-array [(double number)])))

(defn- const-name [id suffix]
  (str (-> (safe-symbol id) str/upper-case) "_" suffix))

(defn- control-const-name [id]
  (-> (safe-symbol id) str/upper-case))

(defn- cpp-control-const-name [id]
  (let [parts (->> (str/split (safe-symbol id) #"_")
                   (remove str/blank?)
                   (map #(str (str/upper-case (subs % 0 1)) (subs % 1))))]
    (str "k" (if (seq parts) (str/join "" parts) "Component"))))

(def interactive-kinds #{:play-area :slider :semantic-select :timeslider-track :button :toggle :knob :text-input})
(def redraw-control-kinds #{:slider :semantic-select :knob})

(defn- interactive? [spec]
  (contains? interactive-kinds (:kind spec)))

(defn- redraw-control? [spec]
  (contains? redraw-control-kinds (:kind spec)))

(defn- ordered-control-keys [placed specs]
  (->> (leaves placed)
       (keep (fn [node]
               (let [id (:id node)
                     spec (get specs id)]
                 (when (interactive? spec) id))))
       vec))

(defn- assign-control-ids [placed specs]
  (->> (ordered-control-keys placed specs)
       (map-indexed (fn [index id] [id (inc index)]))
       (into {})))

(defn- default-control-ids-class [composition-class]
  (str/replace composition-class #"CompositionGenerated$" "ControlIdsGenerated"))

(defn- generated-header []
  "// Generated by WorldOfCake laylagen from Layla IR. Do not edit directly.\n")

(defn- render-layout-class [config placed]
  (let [{:keys [generated-package layout-class]} (:application config)
        geometry (:geometry config)
        leaf-list (leaves placed)]
    (str (generated-header)
         "package " generated-package ";\n\n"
         "class " layout-class " {\n"
         "    public static inline var WINDOW_WIDTH:Float = " (fmt (:panel-width geometry)) ";\n"
         "    public static inline var WINDOW_HEIGHT:Float = " (fmt (:panel-height geometry)) ";\n"
         "    public static inline var PANEL_WIDTH:Float = " (fmt (:panel-width geometry)) ";\n"
         "    public static inline var PANEL_HEIGHT:Float = " (fmt (:panel-height geometry)) ";\n"
         (apply str
                (for [{:keys [id x y width height]} leaf-list]
                  (str "\n"
                       "    public static inline var " (const-name id "X") ":Float = " (fmt x) ";\n"
                       "    public static inline var " (const-name id "Y") ":Float = " (fmt y) ";\n"
                       "    public static inline var " (const-name id "WIDTH") ":Float = " (fmt width) ";\n"
                       "    public static inline var " (const-name id "HEIGHT") ":Float = " (fmt height) ";\n")))
         (apply str
                (for [{:keys [label x y width height]} (labelled-containers placed)]
                  (str "\n"
                       "    public static inline var " (const-name label "X") ":Float = " (fmt x) ";\n"
                       "    public static inline var " (const-name label "Y") ":Float = " (fmt y) ";\n"
                       "    public static inline var " (const-name label "WIDTH") ":Float = " (fmt width) ";\n"
                       "    public static inline var " (const-name label "HEIGHT") ":Float = " (fmt height) ";\n")))
         "}\n")))

(defn- leaf-by-id [placed]
  (into {} (map (juxt :id identity) (leaves placed))))

(defn- haxe-icon [icon]
  (if-let [ops (icons/icon-ops icon)]
    (str "[" (str/join ", " (map fmt ops)) "]")
    "null"))

(defn- render-component [id spec layout-class]
  (let [symbol (safe-symbol id)
        prefix (-> symbol str/upper-case)
        control-ref (str "ControlIds." (control-const-name id))
        position (str "new PanelPoint(" layout-class "." prefix "_X, " layout-class "." prefix "_Y)")
        size (str "new PanelPoint(" layout-class "." prefix "_WIDTH, " layout-class "." prefix "_HEIGHT)")]
    (case (:kind spec)
      :title
      (str "        var " symbol " = new PanelTitle(\n"
           "            " position ",\n"
           "            " size ",\n"
           "            windowToPanelMapper,\n"
           "            " (pr-str (or (:text spec) (:label spec) id)) "\n"
           "        );\n"
           "        view.addChild(" symbol ");\n")

      :status
      (str "        var " symbol " = new PanelStatus(\n"
           "            " position ",\n"
           "            " size ",\n"
           "            windowToPanelMapper\n"
           "        );\n"
           "        view." (or (:view-hook spec) "addChild") "(" symbol ");\n")

      :play-area
      (str "        var " symbol " = new PlayArea(\n"
           "            " control-ref ",\n"
           "            " position ",\n"
           "            " size ",\n"
           "            windowToPanelMapper,\n"
           "            new LocalPoint(" (fmt (or (:local-min-x spec) 0.0)) ", " (fmt (or (:local-min-y spec) 0.0)) "),\n"
           "            new LocalPoint(" (fmt (or (:local-max-x spec) (:local-width spec))) ", " (fmt (or (:local-max-y spec) (:local-height spec))) "),\n"
           "            sequencer\n"
           "        );\n"
           "        components.push(" symbol ");\n"
           "        view." (or (:view-hook spec) "setPlayArea") "(" symbol ");\n")

      :slider
      (str "        var " symbol " = new Slider(\n"
           "            " control-ref ",\n"
           "            " position ",\n"
           "            " size ",\n"
           "            windowToPanelMapper,\n"
           "            sequencer,\n"
           "            " (fmt (:minimum spec)) ", " (fmt (:maximum spec)) ", " (fmt (:default spec)) ",\n"
           "            " (if (:vertical spec) "true" "false") ",\n"
           "            " (:colour spec) "\n"
           "        );\n"
           "        components.push(" symbol ");\n"
           "        view." (or (:view-hook spec) "addSlider") "(" symbol ");\n")

      :semantic-select
      (let [choices (:choices spec)
            labels (str "[" (str/join ", " (map #(pr-str (:label %)) choices)) "]")
            values (str "[" (str/join ", " (map #(fmt (:value %)) choices)) "]")
            colours (str "[" (str/join ", " (map #(or (:colour %) "0x606874") choices)) "]")]
        (str "        var " symbol " = new SemanticSelect(\n"
             "            " control-ref ",\n"
             "            " position ",\n"
             "            " size ",\n"
             "            windowToPanelMapper,\n"
             "            sequencer,\n"
             "            " labels ",\n"
             "            " values ",\n"
             "            " colours ",\n"
             "            " (or (:default-index spec) 0) ", " (pr-str (or (:presentation spec) "segmented")) "\n"
             "        );\n"
             "        components.push(" symbol ");\n"
             "        view." (or (:view-hook spec) "setSemanticSelect") "(" symbol ");\n"))

      :button
      (str "        var " symbol " = new Button(\n"
           "            " control-ref ",\n"
           "            " position ",\n"
           "            " size ",\n"
           "            windowToPanelMapper,\n"
           "            sequencer,\n"
           "            " (pr-str (or (:label spec) id)) ", " (or (:colour spec) "0x606874") ", " (haxe-icon (:icon spec)) "\n"
           "        );\n"
           "        components.push(" symbol ");\n"
           "        view." (or (:view-hook spec) "addChild") "(" symbol ");\n")

      :toggle
      (str "        var " symbol " = new Toggle(\n"
           "            " control-ref ",\n"
           "            " position ",\n"
           "            " size ",\n"
           "            windowToPanelMapper,\n"
           "            sequencer,\n"
           "            " (pr-str (or (:label spec) id)) ", " (if (:default spec) "true" "false") ", " (or (:colour spec) "0x606874") ", " (haxe-icon (:icon spec)) "\n"
           "        );\n"
           "        components.push(" symbol ");\n"
           "        view." (or (:view-hook spec) "addChild") "(" symbol ");\n")

      :knob
      (str "        var " symbol " = new Knob(\n"
           "            " control-ref ",\n"
           "            " position ",\n"
           "            " size ",\n"
           "            windowToPanelMapper,\n"
           "            sequencer,\n"
           "            " (fmt (:minimum spec)) ", " (fmt (:maximum spec)) ", " (fmt (:default spec)) ",\n"
           "            " (pr-str (or (:label spec) id)) ", " (or (:colour spec) "0x606874") ", "
           (pr-str (name (or (:mapping spec) :linear))) ", " (if (false? (:show-label spec)) "false" "true") "\n"
           "        );\n"
           "        components.push(" symbol ");\n"
           "        view." (or (:view-hook spec) "addChild") "(" symbol ");\n")

      :text-input
      (str "        var " symbol " = new TextInput(\n"
           "            " control-ref ",\n"
           "            " position ",\n"
           "            " size ",\n"
           "            windowToPanelMapper,\n"
           "            sequencer,\n"
           "            " (pr-str (or (:default spec) "")) "\n"
           "        );\n"
           "        components.push(" symbol ");\n"
           "        view." (or (:view-hook spec) "addChild") "(" symbol ");\n")

      :text
      (str "        var " symbol " = new PanelText(\n"
           "            " position ",\n"
           "            " size ",\n"
           "            windowToPanelMapper,\n"
           "            " (pr-str (:text spec)) ", " (or (:colour spec) "0x5A616D") "\n"
           "        );\n"
           "        view.addChild(" symbol ");\n")

      :spacer ""

      (throw (ex-info (str "Unsupported component kind " (:kind spec)) {:id id :spec spec})))))

(defn- argb-alpha [alpha]
  (Math/round (* 255.0 (double alpha))))

(defn- render-box [{:keys [label fill fill-alpha border border-alpha]} layout-class]
  (let [symbol (str (safe-symbol label) "_box")
        prefix (-> (safe-symbol label) str/upper-case)]
    (str "        var " symbol " = new PanelBox(\n"
         "            new PanelPoint(" layout-class "." prefix "_X, " layout-class "." prefix "_Y),\n"
         "            new PanelPoint(" layout-class "." prefix "_WIDTH, " layout-class "." prefix "_HEIGHT),\n"
         "            windowToPanelMapper,\n"
         "            " (or fill "0xFFFFFF") ", " (fmt (or fill-alpha 1.0)) ", "
         (or border "0x000000") ", " (fmt (if border (or border-alpha 1.0) 0.0)) "\n"
         "        );\n"
         "        view.addChild(" symbol ");\n")))

(def ^:private widget-imports
  (str "import worldofcake.CoordinateMapper;\n"
       "import worldofcake.LocalPoint;\n"
       "import worldofcake.PanelPoint;\n"
       "import worldofcake.ui.IComponent;\n"
       "import worldofcake.ui.PlayArea;\n"
       "import worldofcake.ui.Slider;\n"
       "import worldofcake.ui.SemanticSelect;\n"
       "import worldofcake.ui.Button;\n"
       "import worldofcake.ui.Toggle;\n"
       "import worldofcake.ui.Knob;\n"
       "import worldofcake.ui.TextInput;\n"
       "import worldofcake.ui.PanelTitle;\n"
       "import worldofcake.ui.PanelBox;\n"
       "import worldofcake.ui.PanelText;\n"
       "import worldofcake.ui.PanelStatus;\n\n"))

(defn- render-widgets
  "Boxes first (so they draw behind), then every leaf the shared component renderer handles."
  [placed specs layout-class skip-kind?]
  (str (apply str (for [box (boxes placed specs)]
                    (str (render-box box layout-class) "\n")))
       (apply str (for [node (leaves placed)
                        :let [id (:id node)
                              spec (get specs id)]
                        :when (not (skip-kind? (:kind spec)))]
                    (str (render-component id spec layout-class) "\n")))))

(defn- render-worldofcake-composition-class [config placed]
  (let [{:keys [package generated-package composition-class layout-class sequencer-class view-class control-ids-class]} (:application config)
        specs (:components config)
        control-class (or control-ids-class (default-control-ids-class composition-class))]
    (str (generated-header)
         "package " generated-package ";\n\n"
         "import " package "." sequencer-class ";\n"
         "import " package "." view-class ";\n"
         widget-imports
         "private typedef ControlIds = " control-class ";\n\n"
         "class " composition-class " {\n"
         "    public static function build(sequencer:" sequencer-class ", windowToPanelMapper:CoordinateMapper, view:" view-class "):Array<IComponent> {\n"
         "        var components:Array<IComponent> = [];\n"
         (render-widgets placed specs layout-class #{})
         "        return components;\n"
         "    }\n"
         "}\n")))

(defn- timeslider-tracks-class [composition-class]
  (str/replace composition-class #"CompositionGenerated$" "TracksGenerated"))

(defn- model-class [composition-class]
  (str/replace composition-class #"CompositionGenerated$" "ModelGenerated"))

(defn- camel-name [k]
  (str/join "" (map str/capitalize (str/split (safe-symbol (name k)) #"_"))))

(defn- model-constants
  "The model's numeric shape (`:model`) and colour lists (`:palettes`), sorted by key."
  [config]
  {:numbers (sort-by key (filter (comp number? val) (:model config)))
   :palettes (sort-by key (:palettes config))})

(defn- render-model-class
  "Model constants for Haxe: the app's world size, counts and palettes, from `:model` and
  `:palettes`. No layout: the model works in this space on every target."
  [config]
  (let [{:keys [generated-package composition-class]} (:application config)
        {:keys [numbers palettes]} (model-constants config)]
    (str (generated-header)
         "package " generated-package ";\n\n"
         "class " (model-class composition-class) " {\n"
         (apply str (for [[k v] numbers]
                      (str "    public static inline var " (control-const-name (name k))
                           (if (integer? v) (str ":Int = " v) (str ":Float = " (fmt v))) ";\n")))
         (apply str (for [[k colours] palettes]
                      (str "    public static var PALETTE_" (control-const-name (name k)) "(default, never):Array<Int> = ["
                           (str/join ", " colours) "];\n")))
         "}\n")))

(defn- render-cpp-model-constants [config]
  (let [{:keys [numbers palettes]} (model-constants config)]
    (if (and (empty? numbers) (empty? palettes))
      ""
      (str "/** The model's shape (EDN `:model`) and palettes (`:palettes`). */\n"
           "namespace model {\n"
           (apply str (for [[k v] numbers]
                        (str "constexpr " (if (integer? v) (str "int k" (camel-name k) " = " v) (str "double k" (camel-name k) " = " (fmt v))) ";\n")))
           (apply str (for [[k colours] palettes]
                        (str "inline constexpr std::array<std::uint32_t, " (count colours) "> kPalette" (camel-name k) "{{"
                             (str/join ", " colours) "}};\n")))
           "}\n"))))

(defn- model-files [config package-path]
  (when (or (seq (:model config)) (seq (:palettes config)))
    {(str package-path "/" (model-class (get-in config [:application :composition-class])) ".hx") (render-model-class config)}))

(defn- model-order
  "Component IDs in the model's order: plain components by ID, then repeated ones by copy and ID.
  Independent of any layout, so targets without a generated panel get the same order."
  [specs]
  (sort-by (fn [id] [(or (:repeat-index (get specs id)) 0) id]) (keys specs)))

(defn- timeslider-tracks
  "TimeSlider track IDs, in track order (the model's order, not the layout's)."
  [specs]
  (filter #(= :timeslider-track (:kind (get specs %))) (model-order specs)))

(defn- render-timeslider-tracks-class
  "The model's side of TimeSlider: how many tracks, their control IDs, travel times and colours.
  No layout and no UI imports, so every target (and the headless tests) can use it."
  [config]
  (let [{:keys [package generated-package composition-class control-ids-class]} (:application config)
        specs (:components config)
        tracks (timeslider-tracks specs)
        sequencer (:sequencer config)
        control-class (or control-ids-class (default-control-ids-class composition-class))
        uid-list (fn [ids] (str "[" (str/join ", " (map #(str "ControlIds." (control-const-name %)) ids)) "]"))]
    (str (generated-header)
         "package " generated-package ";\n\n"
         "import " package ".TimeSliderSequencer.TimeSlider;\n\n"
         "private typedef ControlIds = " control-class ";\n\n"
         "class " (timeslider-tracks-class composition-class) " {\n"
         "    public static inline var TRACK_COUNT:Int = " (count tracks) ";\n"
         "    public static inline var MINIMUM_TRAVEL_TIME:Float = " (fmt (:minimum-travel-time sequencer)) ";\n"
         "    public static inline var MAXIMUM_TRAVEL_TIME:Float = " (fmt (:maximum-travel-time sequencer)) ";\n"
         "    /** Each track's control ID, in track order. */\n"
         "    public static var TRACK_UIDS(default, never):Array<Int> = " (uid-list tracks) ";\n"
         "    /** Track colours, in track order. */\n"
         "    public static var TRACK_COLOURS(default, never):Array<Int> = ["
         (str/join ", " (for [id tracks] (or (:colour (get specs id)) "0x5A616D")))
         "];\n"
         (apply str
                (for [[constant spec-key doc] [["CHANNEL_UIDS" :channel-control "MIDI channel control"]
                                               ["CC_UIDS" :cc-control "CC number control"]
                                               ["LABEL_UIDS" :label-control "label text input"]]]
                  (str "    /** Each track's " doc ", in track order. */\n"
                       "    public static var " constant "(default, never):Array<Int> = "
                       (uid-list (keep #(get (get specs %) spec-key) tracks)) ";\n")))
         "\n"
         "    public static function buildTracks(minimumTravelTime:Float, maximumTravelTime:Float):Array<TimeSlider> {\n"
         "        return [for (uid in TRACK_UIDS) new TimeSlider(uid, minimumTravelTime, maximumTravelTime)];\n"
         "    }\n"
         "}\n")))

(defn- render-timeslider-composition-class [config placed]
  (let [{:keys [package generated-package composition-class layout-class control-ids-class]} (:application config)
        specs (:components config)
        tracks (timeslider-tracks specs)
        control-class (or control-ids-class (default-control-ids-class composition-class))]
    (str (generated-header)
         "package " generated-package ";\n\n"
         "import " package ".TimeSliderSequencer;\n"
         "import " package ".TimeSliderView;\n"
         widget-imports
         "private typedef ControlIds = " control-class ";\n\n"
         "class " composition-class " {\n"
         "    /** Each track's panel rectangle [x, y, width, height], in track order (for views only). */\n"
         "    public static var TRACK_RECTS(default, never):Array<Array<Float>> = [\n"
         (str/join ",\n"
                   (for [id tracks
                         :let [prefix (-> (safe-symbol id) str/upper-case)]]
                     (str "        [" layout-class "." prefix "_X, " layout-class "." prefix "_Y, "
                          layout-class "." prefix "_WIDTH, " layout-class "." prefix "_HEIGHT]")))
         "\n    ];\n\n"
         "    public static function buildControls(sequencer:TimeSliderSequencer, windowToPanelMapper:CoordinateMapper, view:TimeSliderView):Array<IComponent> {\n"
         "        var components:Array<IComponent> = [];\n"
         (render-widgets placed specs layout-class #{:timeslider-track})
         "        return components;\n"
         "    }\n"
         "}\n")))

(defn- render-composition-class [config placed]
  (case (get-in config [:application :composition-kind] :gbloink-world)
    (:gbloink-world :worldofcake-components) (render-worldofcake-composition-class config placed)
    :timeslider (render-timeslider-composition-class config placed)
    (throw (ex-info "Unsupported composition kind" {:kind (get-in config [:application :composition-kind])}))))


(defn- output-const-name [output]
  (str "OUTPUT_" (control-const-name (:id output))))

(defn- render-haxe-control-outputs
  "Index constants and a builder for the app's control outputs (EDN `:outputs`), in declaration order."
  [outputs]
  (if (empty? outputs)
    ""
    (str "\n"
         (apply str (map-indexed (fn [i output]
                                   (str "    public static inline var " (output-const-name output) ":Int = " i ";\n"))
                                 outputs))
         "\n    /** This app's control outputs, each starting at 0 with its default MIDI routing. */\n"
         "    public static function controlOutputs():Array<worldofcake.ControlOutput> {\n"
         "        return [\n"
         (str/join ",\n" (for [{:keys [id label channel cc]} outputs]
                           (str "            new worldofcake.ControlOutput(" (pr-str id) ", " (pr-str (or label id)) ", " channel ", " cc ")")))
         "\n        ];\n"
         "    }\n")))

(defn- render-haxe-control-ids-class [config placed control-ids]
  (let [{:keys [generated-package composition-class control-ids-class]} (:application config)
        specs (:components config)
        class-name (or control-ids-class (default-control-ids-class composition-class))
        ordered (ordered-control-keys placed specs)
        redraw-ids (->> (leaves placed)
                        (keep (fn [node]
                                (let [id (:id node)
                                      spec (get specs id)]
                                  (when (redraw-control? spec) id))))
                        vec)
        redraw-values (str "[" (str/join ", " (map #(str (control-ids %)) redraw-ids)) "]")]
    (str (generated-header)
         "package " generated-package ";

"
         "class " class-name " {
"
         (apply str
                (for [id ordered]
                  (str "    public static inline var " (control-const-name id) ":Int = " (control-ids id) ";
")))
         "    public static var REDRAW_CONTROL_UIDS:Array<Int> = " redraw-values ";\n"
         (render-haxe-control-outputs (:outputs config))
         "}\n")))

(defn- render-cpp-control-ids-header [config placed control-ids]
  (let [{:keys [id composition-class control-ids-class]} (:application config)
        class-name (or control-ids-class (default-control-ids-class composition-class))
        ordered (ordered-control-keys placed (:components config))]
    (str "// Generated by WorldOfCake laylagen from Layla IR. Do not edit directly.\n"
         "#pragma once\n\n"
         "namespace worldofcake\n"
         "{\n"
         "    namespace control\n"
         "    {\n"
         "        namespace " id "\n"
         "        {\n"
         (apply str
                (for [id ordered]
                  (str "            constexpr int " (cpp-control-const-name id) " = " (control-ids id) ";\n")))
         "        } // namespace " id "\n"
         "    } // namespace control\n"
         "} // namespace worldofcake\n")))

(defn- render-cpp-juce-layout-header [config placed]
  (let [id (get-in config [:application :id])
        leaves* (leaves placed)
        containers (labelled-containers placed)
        boxes* (boxes placed (:components config))
        argb (fn [colour alpha] (format "0x%02X%s" (argb-alpha alpha) (str/replace (or colour "0x000000") #"^0x" "")))]
    (str "// Generated by WorldOfCake laylagen from the canonical OpenFL Layla/EDN layout. Do not edit directly.\n"
         "#pragma once\n#include <array>\n#include <juce_gui_basics/juce_gui_basics.h>\n\n"
         "namespace worldofcake::juce_layout::" id " {\n"
         "constexpr double kPanelWidth = " (fmt (get-in config [:geometry :panel-width])) ";\n"
         "constexpr double kPanelHeight = " (fmt (get-in config [:geometry :panel-height])) ";\n"
         (apply str (for [{:keys [id x y width height]} (concat leaves* (map #(assoc % :id (:label %)) containers))]
                      (let [s (safe-symbol id)]
                             (str "inline const juce::Rectangle<double> k" (str/capitalize s)
                             "{" (fmt x) ", " (fmt y) ", " (fmt width) ", " (fmt height) "};\n"))))
         (let [specs (:components config)
               tracks (timeslider-tracks specs)
               region (fn [id] (if id (str "k" (str/capitalize (safe-symbol id))) "juce::Rectangle<double>{}"))]
           (if (empty? tracks)
             ""
             (str "/** Each TimeSlider lane's regions, in track order. */\n"
                  "struct LaneRegions { juce::Rectangle<double> track, label, channel, cc; };\n"
                  "inline const std::array<LaneRegions, " (count tracks) "> kLaneRegions{{"
                  (str/join ", " (for [id tracks
                                       :let [spec (get specs id)]]
                                   (str "{" (region id) ", " (region (:label-control spec)) ", "
                                        (region (:channel-control spec)) ", " (region (:cc-control spec)) "}")))
                  "}};\n")))
         "struct Box { juce::Rectangle<double> bounds; juce::uint32 fill; juce::uint32 border; };\n"
         "inline const std::array<Box, " (count boxes*) "> kBoxes{{"
         (str/join ", " (for [{:keys [x y width height fill fill-alpha border border-alpha]} boxes*]
                          (str "{{" (fmt x) ", " (fmt y) ", " (fmt width) ", " (fmt height) "}, "
                               (argb (or fill "0xFFFFFF") (or fill-alpha 1.0)) ", "
                               (argb border (if border (or border-alpha 1.0) 0.0)) "}")))
         "}};\n"
         "}\n")))

(defn- cpp-str [value]
  (pr-str (or value "")))

(defn- render-cpp-control-metadata-header [config placed control-ids]
  (let [id (get-in config [:application :id])
        specs (:components config)
        ordered (ordered-control-keys placed specs)]
    (str "// Generated by WorldOfCake laylagen from EDN component metadata. Do not edit directly.\n"
         "#pragma once\n#include <array>\n#include <cstddef>\n#include <cstdint>\n#include <cstring>\n#include <cmath>\n\n"
         "namespace worldofcake::metadata::" id " {\n"
         "struct Choice { const char* label; double value; std::uint32_t colour; };\n"
         "struct SemanticSelect { int controlId; const Choice* choices; std::size_t choiceCount; int defaultIndex; const char* label; const char* tooltip; const char* presentation; const char* unit; const char* output; };\n"
         "struct Knob { int controlId; double minimum; double maximum; double defaultValue; const char* label; const char* shortLabel; const char* tooltip; std::uint32_t colour; const char* scale; const char* mapping; const char* unit; const char* output; bool showLabel; };\n"
         "struct Button { int controlId; const char* label; const char* tooltip; std::uint32_t colour; const float* icon; std::size_t iconLength; };\n"
         "struct Text { const char* text; std::uint32_t colour; };\n"
         "struct Track { int controlId; std::uint32_t colour; };\n"
         "/** A control output (EDN `:outputs`): a 0..1 value the model publishes, with its default MIDI routing. */\n"
         "struct ControlOutput { const char* id; const char* label; int channel; int ccNumber; };\n"
         "inline constexpr std::array<ControlOutput, " (count (:outputs config)) "> kControlOutputs{{"
         (str/join ", " (for [{:keys [id label channel cc]} (:outputs config)]
                          (str "{" (cpp-str id) ", " (cpp-str (or label id)) ", " channel ", " cc "}")))
         "}};\n"
         "struct TextInput { int controlId; const char* label; const char* tooltip; const char* defaultText; };\n"
         "constexpr double clamp01(double value) { return value < 0.0 ? 0.0 : (value > 1.0 ? 1.0 : value); }\n"
         "inline double normalize(const Knob& parameter, double value) { if (parameter.maximum == parameter.minimum) return 0.0; const double v = clamp01((value - parameter.minimum) / (parameter.maximum - parameter.minimum)); return std::strcmp(parameter.mapping, \"logarithmic\") == 0 ? std::log(value / parameter.minimum) / std::log(parameter.maximum / parameter.minimum) : v; }\n"
         "inline double denormalize(const Knob& parameter, double normalized) { const double v = clamp01(normalized); return std::strcmp(parameter.mapping, \"logarithmic\") == 0 ? parameter.minimum * std::pow(parameter.maximum / parameter.minimum, v) : parameter.minimum + v * (parameter.maximum - parameter.minimum); }\n"
         (apply str
          (for [component-id ordered
                :let [spec (get specs component-id)
                      symbol (safe-symbol component-id)
                      control-id (control-ids component-id)]
                :when (= (:kind spec) :semantic-select)]
            (str "inline constexpr Choice k" (str/capitalize symbol) "Choices[] = {"
                 (str/join ", " (map #(str "{" (cpp-str (:label %)) ", " (fmt (:value %)) ", " (or (:colour %) "0x606874") "}") (:choices spec)))
                 "};\n"
                 "inline constexpr SemanticSelect k" (str/capitalize symbol) "{" control-id ", k" (str/capitalize symbol) "Choices, sizeof(k" (str/capitalize symbol) "Choices) / sizeof(Choice), " (or (:default-index spec) 0) ", " (cpp-str (or (:label spec) component-id)) ", " (cpp-str (:tooltip spec)) ", " (cpp-str (or (:presentation spec) "segmented")) ", " (cpp-str (name (or (:unit spec) :none))) ", " (cpp-str (name (or (:output spec) :none))) "};\n")))
         (apply str
          (for [component-id ordered
                :let [spec (get specs component-id)
                      symbol (safe-symbol component-id)
                      control-id (control-ids component-id)]
                :when (= (:kind spec) :knob)]
            (str "inline constexpr Knob k" (str/capitalize symbol) "{" control-id ", " (fmt (:minimum spec)) ", " (fmt (:maximum spec)) ", " (fmt (:default spec)) ", " (cpp-str (or (:label spec) component-id)) ", " (cpp-str (or (:short-label spec) (:label spec) component-id)) ", " (cpp-str (:tooltip spec)) ", " (or (:colour spec) "0x606874") ", " (cpp-str (or (:scale spec) "linear")) ", " (cpp-str (if (= (:mapping spec) :logarithmic) "logarithmic" "linear")) ", " (cpp-str (name (or (:unit spec) :none))) ", " (cpp-str (name (or (:output spec) :none))) ", " (if (false? (:show-label spec)) "false" "true") "};\n")))
         (apply str
          (for [component-id ordered
                :let [spec (get specs component-id)
                      symbol (str/capitalize (safe-symbol component-id))
                      control-id (control-ids component-id)
                      ops (icons/icon-ops (:icon spec))]
                :when (#{:button :toggle} (:kind spec))]
            (str (when ops (str "inline constexpr float k" symbol "Icon[] = {" (str/join ", " (map #(str (fmt %) "f") ops)) "};\n"))
                 "inline constexpr Button k" symbol "{" control-id ", " (cpp-str (or (:label spec) component-id)) ", " (cpp-str (:tooltip spec)) ", " (or (:colour spec) "0x606874") ", "
                 (if ops (str "k" symbol "Icon, " (count ops)) "nullptr, 0") "};\n")))
         (apply str
          (for [component-id ordered
                :let [spec (get specs component-id)]
                :when (= (:kind spec) :timeslider-track)]
            (str "inline constexpr Track k" (str/capitalize (safe-symbol component-id)) "{" (control-ids component-id) ", "
                 (or (:colour spec) "0x5A616D") "};\n")))
         (apply str
          (for [node (leaves placed)
                :let [spec (get specs (:id node))]
                :when (= (:kind spec) :text)]
            (str "inline constexpr Text k" (str/capitalize (safe-symbol (:id node))) "{" (cpp-str (:text spec)) ", " (or (:colour spec) "0x5A616D") "};\n")))
         (apply str
          (for [component-id ordered
                :let [spec (get specs component-id)
                      symbol (safe-symbol component-id)
                      control-id (control-ids component-id)]
                :when (= (:kind spec) :text-input)]
            (str "inline constexpr TextInput k" (str/capitalize symbol) "{" control-id ", " (cpp-str (or (:label spec) component-id)) ", " (cpp-str (:tooltip spec)) ", " (cpp-str (:default spec)) "};\n")))
         (let [tracks (timeslider-tracks specs)
               ref (fn [id] (if id (str "&k" (str/capitalize (safe-symbol id))) "nullptr"))]
           (if (empty? tracks)
             ""
             (str "/** TimeSlider lanes, in track order: each lane's track and its per-lane controls. */\n"
                  "struct Lane { const Track* track; const TextInput* label; const SemanticSelect* channel; const SemanticSelect* cc; };\n"
                  "constexpr std::size_t kLaneCount = " (count tracks) ";\n"
                  "inline constexpr std::array<Lane, kLaneCount> kLanes{{"
                  (str/join ", " (for [id tracks
                                       :let [spec (get specs id)]]
                                   (str "{" (ref id) ", " (ref (:label-control spec)) ", "
                                        (ref (:channel-control spec)) ", " (ref (:cc-control spec)) "}")))
                  "}};\n")))
         (render-cpp-model-constants config)
         "}\n")))

(defn- expand-choice-range
  "A semantic select may give `:choice-range {:from 0 :to 127 :format \"CC %d\"}` instead of
  listing `:choices`: one choice per integer, valued by that integer."
  [spec]
  (if-let [{:keys [from to format]} (:choice-range spec)]
    (-> spec
        (dissoc :choice-range)
        (assoc :choices (vec (for [n (range from (inc to))]
                               {:value n :label (clojure.core/format (or format "%d") n)}))))
    spec))

(defn- expand-specs [config]
  (update config :components #(into {} (for [[id spec] %] [id (expand-choice-range spec)]))))

(defn generate
  "Pure generation core. Returns relative paths and deterministic contents."
  [document config]
  (let [config (expand-specs config)
        root (validate-config document config)
        placed (calculate-geometry root (:geometry config) (:components config))
        specs (:components config)
        control-ids (assign-control-ids placed specs)
        {:keys [id generated-package composition-class layout-class control-ids-class]} (:application config)
        package-path (str/replace generated-package "." "/")
        control-class (or control-ids-class (default-control-ids-class composition-class))]
    {:files (merge
             (model-files config package-path)
             (when (= :timeslider (get-in config [:application :composition-kind]))
               {(str package-path "/" (timeslider-tracks-class composition-class) ".hx") (render-timeslider-tracks-class config)})
             {(str package-path "/" layout-class ".hx") (render-layout-class config placed)
             (str package-path "/" composition-class ".hx") (render-composition-class config placed)
             (str package-path "/" control-class ".hx") (render-haxe-control-ids-class config placed control-ids)
             (str package-path "/geometry.edn") (with-out-str (pprint/pprint placed))})
     :native-files {(str "worldofcake/generated/" id "/" control-class ".h") (render-cpp-control-ids-header config placed control-ids)
                    (str "worldofcake/generated/" id "/" (str/capitalize id) "ControlMetadataGenerated.h") (render-cpp-control-metadata-header config placed control-ids)
                    (str "worldofcake/generated/juce/" id "/LayoutGenerated.h") (render-cpp-juce-layout-header config placed)}
     :warnings []}))

(defn generate-model
  "Model code only, for a target whose panel another generator draws (e.g. Rack): control IDs,
  control metadata and app model data, from the config alone, in model order. No layout."
  [config]
  (let [config (expand-specs config)
        errors (output-errors (:outputs config))
        _ (when (seq errors) (throw (ex-info (str/join "\n" errors) {:errors (vec errors)})))
        specs (:components config)
        placed {:node-type :layout :layout-type :vertical
                :children (vec (for [id (model-order specs)] {:node-type :leaf :id id}))}
        control-ids (assign-control-ids placed specs)
        {:keys [id generated-package composition-class control-ids-class]} (:application config)
        package-path (str/replace generated-package "." "/")
        control-class (or control-ids-class (default-control-ids-class composition-class))]
    {:files (merge
             (model-files config package-path)
             (when (= :timeslider (get-in config [:application :composition-kind]))
               {(str package-path "/" (timeslider-tracks-class composition-class) ".hx") (render-timeslider-tracks-class config)})
             {(str package-path "/" control-class ".hx") (render-haxe-control-ids-class config placed control-ids)})
     :native-files {(str "worldofcake/generated/" id "/" control-class ".h") (render-cpp-control-ids-header config placed control-ids)
                    (str "worldofcake/generated/" id "/" (str/capitalize id) "ControlMetadataGenerated.h") (render-cpp-control-metadata-header config placed control-ids)}
     :warnings []}))

(def hxcpp-targets
  "Targets whose native host links the app's Haxe harness through hxcpp (`generated/<target>/`)."
  #{"juce" "rack"})

(defn- harness-class
  "`:harness-class`, or by convention worldofcake.bridge.<Name>Harness, where <Name> is the
  composition class without its CompositionGenerated suffix."
  [{:keys [harness-class composition-class id]}]
  (or harness-class
      (when composition-class
        (str "worldofcake.bridge." (str/replace composition-class #"CompositionGenerated$" "") "Harness"))
      (throw (ex-info (str "No :harness-class or :composition-class for " id) {:id id}))))

(defn hxml-files
  "The hxcpp build of the app's harness for `target`, as {\"<id>.hxml\" content}; nil for a
  target without one. Paths are relative to the repository root, where the builds run haxe.
  `:haxe-classpaths` in `:application` adds the app's own libraries."
  [config target]
  (when (hxcpp-targets target)
    (let [application (:application config)
          classpaths (concat ["bridge/haxe" "Source" (str "generated/" target "/haxe")]
                             (:haxe-classpaths application))]
      {(str (:id application) ".hxml")
       (str "# Generated from the app's metadata by the WorldOfCake generator; do not edit.\n"
            "# Run haxe from the repository root: haxe generated/" target "/haxe/" (:id application) ".hxml -cpp <output>\n"
            (apply str (for [path classpaths] (str "-cp " path "\n")))
            "-D HXCPP_M64\n"
            "-D HXCPP_LINK_STATIC\n"
            (harness-class application) "\n")})))

(defn parse-and-generate [layla-source config]
  (let [parsed (layla/parse-intent layla-source)]
    (when-not (:success parsed)
      (throw (ex-info (:error parsed) {:errors (:errors parsed)})))
    (generate (:data parsed) config)))
