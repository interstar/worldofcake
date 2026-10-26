(ns woc.editor.render
  "Canvas translations of Source/worldofcake/ui drawing code, at design scale."
  (:require [woc.editor.model :as model]))

(def chrome {:face "#FFFFFF" :active "#E3E6EB" :border "#C9CDD4"
             :text "#3A3F48" :track "#D3D6DC"})
;; Same 16x16 operations as laylagen/icons.clj and generated IconPainter data.
(def icons
  {:reset [2 8 8 5 0 314 0 13 2.5 1 13 5.5 1 10 5.5]
   :pause [0 5.5 3.5 1 5.5 12.5 0 10.5 3.5 1 10.5 12.5]
   :mute [0 2.5 6 1 5 6 1 8.5 3 1 8.5 13 1 5 10 1 2.5 10 1 2.5 6 0 11 6 1 14 10 0 14 6 1 11 10]
   :walls [0 2.5 2.5 1 13.5 2.5 1 13.5 13.5 1 2.5 13.5 1 2.5 2.5 3 8 8 1.6]
   :rotate-cw [2 8 8 5 160 380 0 15.25 7.98 1 12.7 9.71 1 11.86 6.74]
   :rotate-ccw [2 8 8 5 20 -200 0 0.75 7.98 1 3.3 9.71 1 4.14 6.74]})
(defn colour [v fallback]
  (cond (number? v) (str "#" (.padStart (.toString v 16) 6 "0"))
        (string? v) (.replace v "0x" "#") :else fallback))
(defn roundrect [ctx x y w h radius fill border]
  (.beginPath ctx)
  (.roundRect ctx x y (max 0 w) (max 0 h) (min radius (/ (max 0 w) 2) (/ (max 0 h) 2)))
  (when fill (set! (.-fillStyle ctx) fill) (.fill ctx))
  (when border (set! (.-strokeStyle ctx) border) (set! (.-lineWidth ctx) 1) (.stroke ctx)))
(defn text [ctx value x y w h size color bold align]
  (.save ctx)
  (.beginPath ctx) (.rect ctx x y (max 0 w) (max 0 h)) (.clip ctx)
  (set! (.-font ctx) (str (when bold "bold ") size "px Arial, sans-serif"))
  (set! (.-fillStyle ctx) color) (set! (.-textBaseline ctx) "top") (set! (.-textAlign ctx) align)
  ;; OpenFL TextField's small text inset, without shrinking overflowing text.
  (.fillText ctx (str value) (+ x (if (= align "center") (/ w 2) 2)) (+ y (max 0 (/ (- h 18) 2)) 2))
  (.restore ctx))
(defn arc [ctx x y r start end thickness color]
  (set! (.-strokeStyle ctx) color) (set! (.-lineWidth ctx) thickness) (set! (.-lineCap ctx) "round")
  (.beginPath ctx)
  (let [steps (max 1 (js/Math.ceil (/ (abs (- end start)) 6)))]
    (doseq [i (range (inc steps))]
      (let [a (* (+ start (* (- end start) (/ i steps))) (/ js/Math.PI 180))
            px (+ x (* r (js/Math.cos a))) py (+ y (* r (js/Math.sin a)))]
        (if (zero? i) (.moveTo ctx px py) (.lineTo ctx px py)))))
  (.stroke ctx))
(defn icon [ctx ops w h color]
  (let [size (* (min w h) 0.55)]
    (.save ctx) (.translate ctx (/ (- w size) 2) (/ (- h size) 2)) (.scale ctx (/ size 16) (/ size 16))
    (set! (.-strokeStyle ctx) color) (set! (.-fillStyle ctx) color)
    (set! (.-lineWidth ctx) 1.6) (set! (.-lineCap ctx) "round") (set! (.-lineJoin ctx) "round")
    (.beginPath ctx)
    (loop [ops ops]
      (when (seq ops)
        (let [[op a b c d e] ops]
          (case op
            0 (.moveTo ctx a b)
            1 (.lineTo ctx a b)
            2 (do (.stroke ctx) (.beginPath ctx)
                  (.arc ctx a b c (* d (/ js/Math.PI 180)) (* e (/ js/Math.PI 180)) (< e d))
                  (.stroke ctx) (.beginPath ctx))
            3 (do (.stroke ctx) (.beginPath ctx) (.arc ctx a b c 0 (* 2 js/Math.PI)) (.fill ctx) (.beginPath ctx)))
          (recur (drop (case op 0 3 1 3 2 6 3 4) ops)))))
    (.stroke ctx) (.restore ctx)))
(defn normalized [spec]
  (let [{lo :minimum hi :maximum value :default} spec]
    (if (= :logarithmic (:mapping spec))
      (/ (js/Math.log (/ value lo)) (js/Math.log (/ hi lo)))
      (/ (- value lo) (- hi lo)))))
(defn draw-widget [ctx node spec]
  (let [{w :width h :height} node color (colour (:colour spec) "#606874")
        label (or (:label spec) (:id node))]
    (case (:kind spec)
      :box (do
             (set! (.-globalAlpha ctx) (get spec :fill-alpha 1))
             (roundrect ctx 0.5 0.5 (- w 1) (- h 1) 6 (colour (:fill spec) "#FFFFFF") nil)
             (set! (.-globalAlpha ctx) (get spec :border-alpha 1))
             (roundrect ctx 0.5 0.5 (- w 1) (- h 1) 6 nil (colour (:border spec) "#D9DCE1")))
      :knob (let [label-space (if (false? (:show-label spec)) 0 16)
                  diameter (max 4 (- (min w (- h label-space)) 4))
                  cx (* w 0.5) cy (* (- h label-space) 0.5)
                  thickness (max 2 (* diameter 0.09)) radius (* (- diameter thickness) 0.5)]
              (arc ctx cx cy radius 135 405 thickness (:track chrome))
              (arc ctx cx cy radius 135 (+ 135 (* 270 (normalized spec))) thickness color)
              (.beginPath ctx) (.arc ctx cx cy (* radius 0.55) 0 (* 2 js/Math.PI))
              (set! (.-fillStyle ctx) (:face chrome)) (.fill ctx)
              (set! (.-lineWidth ctx) 1) (set! (.-strokeStyle ctx) (:border chrome)) (.stroke ctx)
              (when (pos? label-space) (text ctx label 0 (- h 16) w 18 11 (:text chrome) false "center")))
      (:button :toggle) (do
                          (roundrect ctx 0.5 0.5 (- w 1) (- h 1) 4
                                     (if (and (= :toggle (:kind spec)) (:default spec)) (:active chrome) (:face chrome)) (:border chrome))
                          (if-let [ops (get icons (:icon spec))]
                            (icon ctx ops w h color)
                            (text ctx label 0 0 w h 12 color true "center")))
      :semantic-select
      (let [choices (:choices spec) index (mod (get spec :default-index 0) (count choices))]
        (if (= "compact" (:presentation spec))
          (let [half (min (* h 0.18) 5) margin (min (* h 0.7) 18)]
            (roundrect ctx 0.5 0.5 (- w 1) (- h 1) 4 (:face chrome) (:border chrome))
            (doseq [[cx half] [[(* margin 0.6) (- half)] [(- w (* margin 0.6)) half]]]
              (.beginPath ctx) (.moveTo ctx (- cx (* half 0.5)) (- (* h 0.5) (abs half)))
              (.lineTo ctx (+ cx (* half 0.5)) (* h 0.5))
              (.lineTo ctx (- cx (* half 0.5)) (+ (* h 0.5) (abs half)))
              (set! (.-strokeStyle ctx) (:text chrome)) (set! (.-lineWidth ctx) 1.6) (.stroke ctx))
            (text ctx (:label (nth choices index)) margin 0 (- w (* 2 margin)) h 12 (:text chrome) false "center"))
          (let [item-width (/ w (count choices))]
            (doseq [[i choice] (map-indexed vector choices)]
              (let [selected (= i index) c (colour (:colour choice) "#606874")]
                (set! (.-globalAlpha ctx) (if selected 1 0.16))
                (roundrect ctx (+ (* i item-width) 1) 0.5 (- item-width 2) (- h 1) 4 c nil)
                (set! (.-globalAlpha ctx) (if selected 1 0.55))
                (roundrect ctx (+ (* i item-width) 1) 0.5 (- item-width 2) (- h 1) 4 nil c)
                (set! (.-globalAlpha ctx) 1)
                (text ctx (:label choice) (* i item-width) 0 item-width h 12
                      (if selected "#FFFFFF" (:text chrome)) selected "center"))))))
      :slider (let [n (normalized spec)]
                (roundrect ctx 0 0 w h 0 "#EEEEEE" "#000000")
                (set! (.-fillStyle ctx) color)
                (if (:vertical spec) (.fillRect ctx 0 (* h (- 1 n)) w (* h n)) (.fillRect ctx 0 0 (* w n) h)))
      :text (text ctx (:text spec) 0 0 w h 12 (colour (:colour spec) "#5A616D") false "center")
      :title (text ctx (or (:text spec) label) 0 0 w 30 24 "#4A453C" true "left")
      :text-input (let [height (min h 26) top (/ (- h height) 2)]
                    (roundrect ctx 0.5 (+ top 0.5) (- w 1) (- height 1) 4 (:face chrome) (:border chrome))
                    (text ctx (or (:default spec) "") 6 top (- w 12) height 13 (:text chrome) false "left"))
      :play-area (do (set! (.-fillStyle ctx) "#000000") (.fillRect ctx 0 0 w h))
      :timeslider-track (roundrect ctx 0 0 w h 6 "#13161C" nil)
      (:spacer :status) nil
      nil)))

(defn draw! [canvas panel zoom bounds?]
  (let [config (:config panel) geometry (:geometry config)
        w (:panel-width geometry) h (:panel-height geometry)
        ratio (or js/window.devicePixelRatio 1)
        ctx (.getContext canvas "2d")
        all (model/nodes (:placed panel)) specs (:components config)]
    (set! (.-width canvas) (js/Math.ceil (* w zoom ratio)))
    (set! (.-height canvas) (js/Math.ceil (* h zoom ratio)))
    (set! (.. canvas -style -width) (str (* w zoom) "px"))
    (set! (.. canvas -style -height) (str (* h zoom) "px"))
    (.scale ctx (* zoom ratio) (* zoom ratio))
    (set! (.-fillStyle ctx) "#F1EFEA") (.fillRect ctx 0 0 w h)
    ;; Decorative containers first, matching generated composition ordering.
    (doseq [node (concat (filter :label all) (filter :id all))]
      (let [spec (get specs (or (:id node) (:label node)))]
        (.save ctx) (.translate ctx (:x node) (:y node))
        (draw-widget ctx node spec) (.restore ctx)))
    (when bounds?
      (set! (.-strokeStyle ctx) "#c04f91") (set! (.-lineWidth ctx) 0.6)
      (.setLineDash ctx #js [3 3])
      (doseq [node all] (.strokeRect ctx (:x node) (:y node) (:width node) (:height node))))))
