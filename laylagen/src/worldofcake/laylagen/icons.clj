(ns worldofcake.laylagen.icons
  "The one definition of the vector icons that buttons and toggles can show.

  An icon is drawn in a 16x16 box as a flat list of numbers: an opcode followed
  by its arguments. Every target interprets the same list, so an icon is
  defined here once and generated into Haxe, C++ and SVG.

    0 x y                    move to
    1 x y                    line to (stroked)
    2 cx cy r start end      arc, angles in degrees, clockwise on screen (stroked)
    3 cx cy r                filled dot

  Strokes are 1.6 units wide, round-capped, in the control's text colour."
  (:require [clojure.string :as str]))

(def opcode-arity {0 2, 1 2, 2 5, 3 3})

(def icons
  {:lozenge [0 2 8 1 8 5 1 14 8 1 8 11 1 2 8]
   :reset [2 8 8 5 0 314
           0 13 2.5 1 13 5.5 1 10 5.5]
   :pause [0 5.5 3.5 1 5.5 12.5
           0 10.5 3.5 1 10.5 12.5]
   :mute [0 2.5 6 1 5 6 1 8.5 3 1 8.5 13 1 5 10 1 2.5 10 1 2.5 6
          0 11 6 1 14 10
          0 14 6 1 11 10]
   :walls [0 2.5 2.5 1 13.5 2.5 1 13.5 13.5 1 2.5 13.5 1 2.5 2.5
           3 8 8 1.6]
   ;; An open arc over the top with an arrowhead at its end; one is the mirror of the other.
   :rotate-cw [2 8 8 5 160 380
               0 15.25 7.98 1 12.7 9.71 1 11.86 6.74]
   :rotate-ccw [2 8 8 5 20 -200
                0 0.75 7.98 1 3.3 9.71 1 4.14 6.74]})

(defn icon-ops
  "The op list for an icon keyword, or nil for no icon. Throws for an unknown icon."
  [icon]
  (when icon
    (or (get icons icon)
        (throw (ex-info (str "Unknown icon " (pr-str icon) "; known icons: " (sort (keys icons))) {:icon icon})))))

(defn- arc-points [cx cy r start end]
  (let [steps (max 2 (int (Math/ceil (/ (Math/abs (double (- end start))) 15.0))))]
    (for [i (range (inc steps))
          :let [a (Math/toRadians (+ start (* (- end start) (/ i (double steps)))))]]
      [(+ cx (* r (Math/cos a))) (+ cy (* r (Math/sin a)))])))

(defn svg-path
  "SVG path data for the stroked parts of an icon, plus filled dots as [cx cy r]."
  [ops]
  (loop [ops (seq ops) path [] dots []]
    (if-not ops
      {:path (str/join " " path) :dots dots}
      (let [op (int (first ops))
            args (take (opcode-arity op) (rest ops))
            more (seq (drop (inc (opcode-arity op)) ops))
            fmt #(String/format java.util.Locale/ROOT "%.3f" (to-array [(double %)]))]
        (case op
          0 (recur more (conj path (str "M" (fmt (nth args 0)) " " (fmt (nth args 1)))) dots)
          1 (recur more (conj path (str "L" (fmt (nth args 0)) " " (fmt (nth args 1)))) dots)
          2 (let [[[x0 y0] & points] (apply arc-points args)]
              (recur more (into (conj path (str "M" (fmt x0) " " (fmt y0)))
                                (map (fn [[x y]] (str "L" (fmt x) " " (fmt y))) points))
                     dots))
          3 (recur more path (conj dots (vec args))))))))
