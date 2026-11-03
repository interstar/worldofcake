(ns worldofcake.laylagen.svg-text
  "Build-time SVG outlines from the vendored font; no system-font lookup."
  (:require [clojure.java.io :as io] [clojure.string :as str])
  (:import [java.awt Font RenderingHints]
           [java.awt.font FontRenderContext TextAttribute]
           [java.awt.geom AffineTransform PathIterator]
           [java.net JarURLConnection]
           [java.util Locale]))

(System/setProperty "java.awt.headless" "true")

(defn- vendored-font []
  ;; Resolve from our own source/JAR location, not the caller's working directory.
  (let [resource (io/resource "worldofcake/laylagen/svg_text.clj")
        location (if (= "jar" (.getProtocol resource))
                   (.getJarFileURL ^JarURLConnection (.openConnection resource))
                   resource)]
    (loop [dir (.getParentFile (io/file (.toURI location)))]
      (when-not dir (throw (ex-info "Missing vendored vendor/fonts/DejaVuSans.ttf" {})))
      (let [candidate (io/file dir "vendor/fonts/DejaVuSans.ttf")]
        (if (.isFile candidate) candidate (recur (.getParentFile dir)))))))

(def ^:private font
  (delay
    (with-open [input (io/input-stream (vendored-font))]
      (-> (Font/createFont Font/TRUETYPE_FONT input)
          (.deriveFont (float 1000))
          (.deriveFont {TextAttribute/KERNING TextAttribute/KERNING_ON
                        TextAttribute/LIGATURES (Integer/valueOf 0)})))))
(def ^:private context (FontRenderContext. (AffineTransform.)
                                          RenderingHints/VALUE_TEXT_ANTIALIAS_ON
                                          RenderingHints/VALUE_FRACTIONALMETRICS_ON))
(defn- glyphs [text]
  (.layoutGlyphVector ^Font @font context (char-array text) 0 (count text) Font/LAYOUT_LEFT_TO_RIGHT))
(def ^:private cap-height (delay (.getHeight (.getBounds2D (.getOutline (glyphs "H"))))))
(defn- decimal [x] (String/format Locale/ROOT "%.3f" (to-array [(double x)])))
(defn- escape-xml [value]
  (-> (str value) (str/replace "&" "&amp;") (str/replace "<" "&lt;")
      (str/replace ">" "&gt;") (str/replace "\"" "&quot;")))

(defn text-path
  "One path per label. x/y locate its horizontal anchor and visual cap centre."
  [{:keys [id text x y size anchor colour] :or {anchor :middle colour "#3a3f48"}}]
  (let [missing (.canDisplayUpTo ^Font @font ^String text)]
    (when (not= -1 missing)
      (throw (ex-info (str "Missing glyph in label " (pr-str text) ": U+"
                           (format "%04X" (.codePointAt ^String text missing)))
                      {:label text :index missing}))))
  (let [gv (glyphs text)
        scale (/ (double size) 1000.0)
        width (.getWidth (.getLogicalBounds gv))
        factor (case anchor :start 0.0 :middle 0.5 :end 1.0
                     (throw (ex-info "Unknown text anchor" {:anchor anchor :label text})))
        tx (AffineTransform. scale 0.0 0.0 scale
                             (- (double x) (* width scale factor))
                             (+ (double y) (* @cap-height scale 0.5)))
        iterator (.getPathIterator (.getOutline gv) tx)
        coords (double-array 6)
        path (StringBuilder.)]
    (while (not (.isDone iterator))
      (let [segment (.currentSegment iterator coords)
            [command count] (case segment
                              0 ["M" 2] 1 ["L" 2] 2 ["Q" 4] 3 ["C" 6] 4 ["Z" 0])]
        (.append path command)
        (.append path (str/join " " (map #(decimal (aget coords %)) (range count)))))
      (.next iterator))
    (str "<path id=\"text-" (escape-xml id) "\" data-text=\"" (escape-xml text)
         "\" fill=\"" (escape-xml (str/replace colour #"^0x" "#"))
         "\" d=\"" path "\"/>\n")))
