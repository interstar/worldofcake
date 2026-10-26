(ns woc.editor.model
  "WoC panel validation and fixed geometry. Mirrors laylagen's geometry pass;
   parity is tested against the bundled production generator. No Haxe involved."
  (:require [layla.core :as layla]
            [clojure.string :as str]))

(def apps ["gbloink" "goldenpond" "kdiagram" "tileland" "timeslider" "zewp"])
(def kinds #{:box :text :title :status :spacer :play-area :timeslider-track
             :knob :slider :button :toggle :semantic-select :text-input})
(def icon-names #{:reset :pause :mute :walls :rotate-cw :rotate-ccw})
(defn fail [message] (throw (ex-info message {})))
(defn nodes [root] (tree-seq #(= :layout (:node-type %)) :children root))
(defn finite? [n] (and (number? n) #?(:clj (Double/isFinite (double n)) :cljs (js/Number.isFinite n))))
(defn safe-symbol [s] (-> s str/lower-case (str/replace #"[^a-z0-9]+" "_")))
(defn validate [document config]
  (when-not (= :layout (:document-type document)) (fail "WoC panels require one layout, not named pages."))
  (when-not (= 1 (:generator-version config)) (fail "EDN :generator-version must be 1."))
  (let [all (nodes (:root document))
        named (keep #(or (:id %) (:label %)) all)
        specs (:components config)]
    (when-not (map? specs) (fail "EDN needs a :components map."))
    (doseq [key [:panel-width :panel-height]]
      (let [v (get-in config [:geometry key])]
        (when-not (and (finite? v) (pos? v) (<= v 8192))
          (fail (str "EDN :geometry " key " must be positive and at most 8192.")))))
    (doseq [[k v] (dissoc (:geometry config) :panel-width :panel-height :gaps-by-depth)]
      (when-not (and (finite? v) (>= v 0)) (fail (str "Invalid geometry value " k))))
    (doseq [[_ v] (get-in config [:geometry :gaps-by-depth])]
      (when-not (and (finite? v) (>= v 0)) (fail "Gaps must be finite and non-negative.")))
    (when-not (= (count named) (count (set (map safe-symbol named))))
      (fail "Component names collide after conversion to target symbols."))
    (doseq [id (keys specs)]
      (when-not (some #{id} named) (fail (str "Unused EDN component: " id))))
    (doseq [node all]
      (when-not (and (finite? (:weight node)) (pos? (:weight node))) (fail "Layout weights must be positive and finite."))
      (let [id (or (:id node) (:label node)) spec (get specs id) kind (:kind spec)]
        (doseq [key [:colour :fill :border]
                :let [v (get spec key)] :when (some? v)]
          (when-not (and (string? v) (re-matches #"0x[0-9a-fA-F]{6}" v))
            (fail (str id ": " key " must be a six-digit 0x colour."))))
        (doseq [key [:fill-alpha :border-alpha]
                :let [v (get spec key)] :when (some? v)]
          (when-not (and (finite? v) (<= 0 v 1)) (fail (str id ": " key " must be between 0 and 1."))))
        (when (and (:icon spec) (not (icon-names (:icon spec)))) (fail (str id ": unknown WoC icon " (:icon spec))))
        (when (= :layout (:node-type node))
          (when-not (#{:horizontal :vertical :responsive} (:layout-type node))
            (fail "The WoC OpenFL generator does not support grid layouts.")))
        (when (:id node)
          (when-not spec (fail (str "Missing EDN component: " id)))
          (when-not (and (contains? kinds kind) (not= kind :box)) (fail (str "Unsupported component kind for " id ": " kind))))
        (when (:label node)
          (when (and kind (not= kind :box)) (fail (str "Container " id " must have :kind :box."))))
        (when-let [padding (:padding spec)]
          (when-not (and (finite? padding) (>= padding 0)) (fail (str "Invalid padding for " id))))
        (when (#{:knob :slider} kind)
          (when-not (#{:linear :logarithmic} (get spec :mapping :linear))
            (fail (str id ": mapping must be :linear or :logarithmic.")))
          (let [{lo :minimum hi :maximum value :default} spec]
            (when-not (and (every? finite? [lo hi value]) (< lo hi) (<= lo value hi))
              (fail (str id ": require minimum < maximum, and a default in range.")))
            (when (and (= :logarithmic (:mapping spec)) (not (pos? lo)))
              (fail (str id ": logarithmic minimum must be positive.")))))
        (when (= :semantic-select kind)
          (when-not (and (integer? (get spec :default-index 0))
                         (<= 0 (get spec :default-index 0))
                         (< (get spec :default-index 0) (count (:choices spec))))
            (fail (str id ": default-index must select an existing choice.")))
          (when-not (and (seq (:choices spec)) (every? #(and (string? (:label %)) (finite? (:value %))) (:choices spec)))
            (fail (str id ": choices need labels and numeric values."))))))
    (:root document)))

(declare place)
(defn place [node x y width height depth geometry specs]
  (when-not (and (every? finite? [x y width height]) (pos? width) (pos? height))
    (fail (str "Padding or gaps leave no usable area for " (or (:id node) (:label node) "a container") ".")))
  (let [rect {:x x :y y :width width :height height}]
    (if (= :leaf (:node-type node))
      (merge node rect)
      (let [padding (get-in specs [(:label node) :padding] 0)
            x (+ x padding) y (+ y padding)
            width (- width (* 2 padding)) height (- height (* 2 padding))
            items (:children node)
            gap (or (get-in geometry [:gaps-by-depth depth])
                    (if (zero? depth) (:root-gap geometry) (:nested-gap geometry)) 0)
            horizontal? (#{:horizontal :responsive} (:layout-type node))
            available (- (if horizontal? width height) (* gap (dec (count items))))
            total (reduce + (map :weight items))
            sizes (map #(* available (/ (:weight %) total)) items)
            positions (reductions + (if horizontal? x y) (map #(+ % gap) sizes))]
        (merge node rect
               {:children (mapv (fn [item size cursor]
                                  (if horizontal?
                                    (place item cursor y size height (inc depth) geometry specs)
                                    (place item x cursor width size (inc depth) geometry specs)))
                                items sizes positions)})))))

(defn calculate-geometry [root geometry specs]
  (let [fallback (get geometry :outer-padding 0)
        left (get geometry :padding-left fallback) right (get geometry :padding-right fallback)
        top (get geometry :padding-top fallback) bottom (get geometry :padding-bottom fallback)]
    (place root left top (- (:panel-width geometry) left right)
           (- (:panel-height geometry) top bottom) 0 geometry specs)))

(defn panel [source config]
  (let [parsed (layla/parse-intent source)]
    (when-not (:success parsed) (fail (str "Layla: " (:error parsed))))
    (let [root (validate (:data parsed) config)]
      {:config config :placed (calculate-geometry root (:geometry config) (:components config))})))
