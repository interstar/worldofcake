(ns worldofcake.laylagen.core
  (:require [clojure.edn :as edn]
            [clojure.java.io :as io]
            [clojure.pprint :as pprint]
            [clojure.string :as str]
            [layla.core :as layla]))

(def generator-version 1)

(defn- children [node]
  (if (= :layout (:node-type node)) (:children node) []))

(defn- leaves [node]
  (if (= :leaf (:node-type node))
    [node]
    (mapcat leaves (children node))))

(defn safe-symbol [value]
  (let [parts (->> (str/split (str value) #"[^A-Za-z0-9]+")
                   (remove str/blank?))
        joined (if (seq parts)
                 (str/lower-case (str/join "_" parts))
                 "component")]
    (if (re-find #"^[0-9]" joined) (str "component_" joined) joined)))

(defn- validate-config [document config]
  (let [root (when (= :layout (:document-type document)) (:root document))
        leaf-list (when root (vec (leaves root)))
        ids (mapv :id leaf-list)
        component-ids (set (keys (:components config)))
        missing (remove component-ids ids)
        unused (remove (set ids) component-ids)
        symbols (map safe-symbol ids)
        collisions (->> symbols frequencies (keep (fn [[s n]] (when (> n 1) s))) sort)
        errors (concat
                (when-not root ["The OpenFL/WorldOfCake target requires one layout, not pages."])
                (map #(str "Missing component configuration for " (pr-str %)) missing)
                (map #(str "Unused component configuration for " (pr-str %)) unused)
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
  (let [items (:children node)
        configured-gap (get (:gaps-by-depth geometry) depth)
        gap (double (or configured-gap (if (zero? depth) (:root-gap geometry) (:nested-gap geometry))))
        horizontal? (#{:horizontal :responsive} (:layout-type node))
        major (if horizontal? width height)
        available (- major (* gap (max 0 (dec (count items)))))
        sizes (distribute items available)]
    (loop [remaining items sizes sizes cursor (if horizontal? x y) result []]
      (if (empty? remaining)
        (assoc node :x x :y y :width width :height height :children result)
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

(defn calculate-geometry [root geometry]
  (let [fallback (double (or (:outer-padding geometry) 0.0))
        left (double (or (:padding-left geometry) fallback))
        right (double (or (:padding-right geometry) fallback))
        top (double (or (:padding-top geometry) fallback))
        bottom (double (or (:padding-bottom geometry) fallback))
        width (- (double (:panel-width geometry)) left right)
        height (- (double (:panel-height geometry)) top bottom)]
    (when (or (not (pos? width)) (not (pos? height)))
      (throw (ex-info "Outer padding leaves no usable panel area" {:geometry geometry})))
    (place-node root left top width height 0 geometry)))

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

(def interactive-kinds #{:play-area :slider :semantic-select :timeslider-track :button :toggle :knob})
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
         "}\n")))

(defn- leaf-by-id [placed]
  (into {} (map (juxt :id identity) (leaves placed))))

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
            colours (str "[" (str/join ", " (map :colour choices)) "]")]
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
           "            " (pr-str (or (:label spec) id)) ", " (or (:colour spec) "0x606874") "\n"
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
           "            " (pr-str (or (:label spec) id)) ", " (if (:default spec) "true" "false") ", " (or (:colour spec) "0x606874") "\n"
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
           "            " (pr-str (or (:label spec) id)) ", " (or (:colour spec) "0x606874") "\n"
           "        );\n"
           "        components.push(" symbol ");\n"
           "        view." (or (:view-hook spec) "addChild") "(" symbol ");\n")

      :spacer ""

      (throw (ex-info (str "Unsupported component kind " (:kind spec)) {:id id :spec spec})))))

(defn- render-worldofcake-composition-class [config placed]
  (let [{:keys [package generated-package composition-class layout-class sequencer-class view-class control-ids-class]} (:application config)
        specs (:components config)
        control-class (or control-ids-class (default-control-ids-class composition-class))]
    (str (generated-header)
         "package " generated-package ";\n\n"
         "import " package "." sequencer-class ";\n"
         "import " package "." view-class ";\n"
         "import worldofcake.CoordinateMapper;\n"
         "import worldofcake.LocalPoint;\n"
         "import worldofcake.PanelPoint;\n"
         "import worldofcake.ui.IComponent;\n"
         "import worldofcake.ui.PlayArea;\n"
         "import worldofcake.ui.Slider;\n"
         "import worldofcake.ui.SemanticSelect;\n"
         "import worldofcake.ui.Button;\n"
         "import worldofcake.ui.Toggle;\n"
         "import worldofcake.ui.Knob;\n"
         "import worldofcake.ui.PanelTitle;\n\n"
         "private typedef ControlIds = " control-class ";\n\n"
         "class " composition-class " {\n"
         "    public static function build(sequencer:" sequencer-class ", windowToPanelMapper:CoordinateMapper, view:" view-class "):Array<IComponent> {\n"
         "        var components:Array<IComponent> = [];\n"
         (apply str (for [node (leaves placed)
                          :let [id (:id node)]]
                      (str (render-component id (get specs id) layout-class) "\n")))
         "        return components;\n"
         "    }\n"
         "}\n")))

(defn- render-timeslider-control [id spec layout-class]
  (let [prefix (-> (safe-symbol id) str/upper-case)
        position (str "new PanelPoint(" layout-class "." prefix "_X, " layout-class "." prefix "_Y)")
        size (str "new PanelPoint(" layout-class "." prefix "_WIDTH, " layout-class "." prefix "_HEIGHT)")]
    (case (:kind spec)
      :button
      (str "        var " (safe-symbol id) " = new Button(ControlIds." (control-const-name id) ", " position ", " size ", windowToPanelMapper, sequencer, " (pr-str (or (:label spec) id)) ", " (or (:colour spec) "0x606874") ");\n"
           "        components.push(" (safe-symbol id) ");\n"
           "        view.addChild(" (safe-symbol id) ");\n")

      :toggle
      (str "        var " (safe-symbol id) " = new Toggle(ControlIds." (control-const-name id) ", " position ", " size ", windowToPanelMapper, sequencer, " (pr-str (or (:label spec) id)) ", " (if (:default spec) "true" "false") ", " (or (:colour spec) "0x606874") ");\n"
           "        components.push(" (safe-symbol id) ");\n"
           "        view.addChild(" (safe-symbol id) ");\n")

      "")))

(defn- render-timeslider-composition-class [config placed]
  (let [{:keys [package generated-package composition-class layout-class control-ids-class]} (:application config)
        specs (:components config)
        tracks (filter #(= :timeslider-track (:kind (get specs (:id %)))) (leaves placed))
        controls (filter #(contains? #{:button :toggle} (:kind (get specs (:id %)))) (leaves placed))
        sequencer (:sequencer config)
        control-class (or control-ids-class (default-control-ids-class composition-class))]
    (str (generated-header)
         "package " generated-package ";\n\n"
         "import " package ".TimeSliderSequencer;\n"
         "import " package ".TimeSliderSequencer.TimeSlider;\n"
         "import " package ".TimeSliderView;\n"
         "import worldofcake.CoordinateMapper;\n"
         "import worldofcake.PanelPoint;\n"
         "import worldofcake.ui.Button;\n"
         "import worldofcake.ui.IComponent;\n"
         "import worldofcake.ui.Toggle;\n\n"
         "private typedef ControlIds = " control-class ";\n\n"
         "class " composition-class " {\n"
         "    public static inline var TRACK_COUNT:Int = " (count tracks) ";\n"
         "    public static inline var MINIMUM_TRAVEL_TIME:Float = " (fmt (:minimum-travel-time sequencer)) ";\n"
         "    public static inline var MAXIMUM_TRAVEL_TIME:Float = " (fmt (:maximum-travel-time sequencer)) ";\n\n"
         "    public static function createSequencer():TimeSliderSequencer {\n"
         "        return new TimeSliderSequencer(Std.int(" layout-class ".PANEL_WIDTH), Std.int(" layout-class ".PANEL_HEIGHT), MINIMUM_TRAVEL_TIME, MAXIMUM_TRAVEL_TIME);\n"
         "    }\n\n"
         "    public static function buildTracks(minimumTravelTime:Float, maximumTravelTime:Float):Array<TimeSlider> {\n"
         "        return [\n"
         (str/join ",\n"
                   (for [node tracks
                         :let [id (:id node)
                               spec (get specs id)
                               prefix (-> (safe-symbol id) str/upper-case)]]
                     (str "            new TimeSlider("
                          "ControlIds." (control-const-name id) ", "
                          layout-class "." prefix "_X, " layout-class "." prefix "_Y, "
                          layout-class "." prefix "_WIDTH, " layout-class "." prefix "_HEIGHT, "
                          (:channel spec) ", " (:cc-number spec) ", minimumTravelTime, maximumTravelTime)")))
         "\n        ];\n"
         "    }\n\n"
         "    public static function buildControls(sequencer:TimeSliderSequencer, windowToPanelMapper:CoordinateMapper, view:TimeSliderView):Array<IComponent> {\n"
         "        var components:Array<IComponent> = [];\n"
         (apply str (for [node controls
                          :let [id (:id node)
                                spec (get specs id)]]
                      (render-timeslider-control id spec layout-class)))
         "        return components;\n"
         "    }\n"
         "}\n")))

(defn- render-composition-class [config placed]
  (case (get-in config [:application :composition-kind] :gbloink-world)
    (:gbloink-world :worldofcake-components) (render-worldofcake-composition-class config placed)
    :timeslider (render-timeslider-composition-class config placed)
    (throw (ex-info "Unsupported composition kind" {:kind (get-in config [:application :composition-kind])}))))


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
         "    public static var REDRAW_CONTROL_UIDS:Array<Int> = " redraw-values ";
"
         "}
")))

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

(defn generate
  "Pure generation core. Returns relative paths and deterministic contents."
  [document config]
  (let [root (validate-config document config)
        placed (calculate-geometry root (:geometry config))
        specs (:components config)
        control-ids (assign-control-ids placed specs)
        {:keys [id generated-package composition-class layout-class control-ids-class]} (:application config)
        package-path (str/replace generated-package "." "/")
        control-class (or control-ids-class (default-control-ids-class composition-class))]
    {:files {(str package-path "/" layout-class ".hx") (render-layout-class config placed)
             (str package-path "/" composition-class ".hx") (render-composition-class config placed)
             (str package-path "/" control-class ".hx") (render-haxe-control-ids-class config placed control-ids)
             (str package-path "/geometry.edn") (with-out-str (pprint/pprint placed))}
     :native-files {(str "worldofcake/generated/" id "/" control-class ".h") (render-cpp-control-ids-header config placed control-ids)}
     :warnings []}))

(defn parse-and-generate [layla-source config]
  (let [parsed (layla/parse-intent layla-source)]
    (when-not (:success parsed)
      (throw (ex-info (:error parsed) {:errors (:errors parsed)})))
    (generate (:data parsed) config)))
