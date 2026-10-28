(ns woc.editor.client
  (:require [cljs.reader :as reader]

            [woc.editor.model :as model]
            [woc.editor.render :as render]))

(defn el [id] (.getElementById js/document id))
(defonce state (atom {:loaded nil :panel nil :valid? false :saving? false :busy? false :tab "layla"}))
(def source-keys [:layla :edn :app-edn])
(defn active-keys [] (keys (:paths (:loaded @state))))
(defn sources [] (into {} (for [key (active-keys)] [key (.-value (el (name key)))])))
(defn dirty? [] (and (:loaded @state) (not= (sources) (select-keys (:loaded @state) (active-keys)))))
(defn message! [text broken?]
  (set! (.-textContent (el "diagnostics")) text)
  (.toggle (.-classList (el "diagnostics")) "error" broken?)
  (.toggle (.-classList (.-body js/document)) "broken" broken?))
(defn controls! []
  (let [{:keys [saving? busy? valid?]} @state]
    (set! (.-disabled (el "save")) (or saving? busy? (not valid?) (not (dirty?))))
    (set! (.-disabled (el "app")) (or saving? busy?))
    (set! (.-disabled (el "reload")) (or saving? busy?))
    (set! (.-textContent (el "saved")) (cond saving? "Saving…" busy? "Loading…" (dirty?) "Unsaved edits" :else "Saved on disk"))))
(defn draw! []
  (when-let [panel (:panel @state)]
    (let [geometry (get-in panel [:config :geometry]) w (:panel-width geometry) h (:panel-height geometry)
          viewport (el "viewport") choice (.-value (el "zoom"))
          zoom (if (= choice "fit") (max 0.05 (min 1 (/ (- (.-clientWidth viewport) 56) w)
                                                                  (/ (- (.-clientHeight viewport) 56) h)))
                   (js/parseFloat choice))]
      (render/draw! (el "panel") panel zoom (.-checked (el "bounds")))
      (set! (.-textContent (el "dimensions")) (str w " × " h " · " (js/Math.round (* zoom 100)) "%")))))
(declare request!)
(defonce generation (atom 0))
(defn validate! []
  (let [ticket (swap! generation inc) app (get-in @state [:loaded :app]) draft (sources)]
    (swap! state assoc :valid? false)
    (controls!)
    (-> (request! (str "/api/preview?app=" app)
                  #js {:method "POST" :headers #js {"Content-Type" "application/edn" "X-WoC-Editor" "1"}
                       :body (pr-str draft)})
        (.then (fn [{:keys [layla config]}]
                 (when (= ticket @generation)
                   (let [panel (model/panel layla config)]
                     (swap! state assoc :panel panel :valid? true)
                     (draw!)
                     (message! "Preview up to date · resolved OpenFL config · EDN defaults" false)
                     true))))
        (.catch (fn [e]
                  (when (= ticket @generation)
                    (swap! state assoc :valid? false)
                    (message! (str "Preview out of date — showing the last valid panel\n" (.-message e)) true))
                  false))
        (.finally controls!))))
(defonce timer (atom nil))
(defn changed! []
  (js/clearTimeout @timer)
  (swap! generation inc)
  (swap! state assoc :valid? false)
  (message! "Updating preview…" false)
  (controls!)
  (reset! timer (js/setTimeout validate! 180)))
(defn request! [url options]
  (-> (js/fetch url options)
      (.then (fn [response]
               (-> (.text response)
                   (.then (fn [text]
                            (let [value (reader/read-string text)]
                              (if (.-ok response) value
                                  (throw (js/Error. (or (:error value) (str "HTTP " (.-status response))))))))))))))
(defn filename! []
  (set! (.-textContent (el "filename"))
        (get-in @state [:loaded :paths (keyword (:tab @state))] "")))
(declare switch-tab!)
(defn configure-tabs! []
  (let [migrated? (= :migrated (get-in @state [:loaded :kind]))]
    (set! (.-hidden (el "tab-app-edn")) (not migrated?))
    (set! (.-textContent (el "tab-edn")) (if migrated? "OpenFL EDN" "EDN"))
    (set! (.-textContent (el "save")) (if migrated? "Save sources" "Save pair"))
    (set! (.-textContent (el "source-help"))
          (if migrated?
            "OpenFL EDN: presentation · App EDN: shared semantics · Ctrl/Cmd+S saves all sources"
            "Source editing · Ctrl/Cmd+S saves both files · Tab inserts two spaces"))
    (when (and (not migrated?) (= "app-edn" (:tab @state))) (swap! state assoc :tab "layla"))
    (switch-tab! (:tab @state))))
(defn load! [app]
  (js/clearTimeout @timer)
  (swap! generation inc)
  (swap! state assoc :busy? true :valid? false)
  (controls!)
  (-> (request! (str "/api/panel?app=" app) #js {})
      (.then (fn [data]
               (swap! state assoc :loaded data :panel nil)
               (doseq [key source-keys] (set! (.-value (el (name key))) (get data key "")))
               (configure-tabs!)
               (set! (.-value (el "app")) app)
               ;; Never show another app's old preview if this pair is invalid.
               (let [canvas (el "panel")] (set! (.-width canvas) 0) (set! (.-height canvas) 0))
               (filename!) (validate!)))
      (.catch (fn [e] (message! (str "Could not load panel: " (.-message e)) true)))
      (.finally (fn [] (swap! state assoc :busy? false) (controls!)))))
(defn save! []
  (js/clearTimeout @timer)
  (when (and (:loaded @state) (not (:saving? @state)) (not (:busy? @state)))
    (-> (validate!)
        (.then (fn [valid?]
                 (when (and valid? (:valid? @state) (dirty?) (not (:saving? @state)))
                   (let [loaded (:loaded @state) draft (sources)]
                     (swap! state assoc :saving? true) (controls!)
                     (-> (request! (str "/api/panel?app=" (:app loaded))
                                   #js {:method "POST" :headers #js {"Content-Type" "application/edn" "X-WoC-Editor" "1"}
                                        :body (pr-str (assoc draft :revision (:revision loaded)))})
                         (.then (fn [data] (swap! state assoc :loaded data)))
                         (.catch (fn [e] (message! (str "Save failed — your edits are retained\n" (.-message e)) true)))
                         (.finally (fn [] (swap! state assoc :saving? false) (controls!)))))))))))
(defn switch-tab! [tab]
  (swap! state assoc :tab tab)
  (doseq [name ["layla" "edn" "app-edn"]]
    (set! (.-hidden (el name)) (not= name tab))
    (.setAttribute (el (str "tab-" name)) "aria-selected" (str (= name tab))))
  (filename!))
(defn init! []
  (doseq [app model/apps]
    (let [option (.createElement js/document "option")]
      (set! (.-value option) app) (set! (.-textContent option) app) (.appendChild (el "app") option)))
  (doseq [tab ["layla" "edn" "app-edn"]]
    (.addEventListener (el (str "tab-" tab)) "click" #(switch-tab! tab))
    (.addEventListener (el tab) "input" changed!)
    (.addEventListener (el tab) "keydown"
                       (fn [e]
                         (when (= "Tab" (.-key e))
                           (.preventDefault e)
                           (let [field (.-target e)]
                             (.setRangeText field "  " (.-selectionStart field) (.-selectionEnd field) "end")
                             (changed!))))))
  (.addEventListener (el "save") "click" save!)
  (.addEventListener (el "reload") "click"
                     #(when (or (not (dirty?)) (js/confirm "Discard unsaved edits and reload these sources from disk?"))
                        (load! (get-in @state [:loaded :app]))))
  (.addEventListener (el "app") "change"
                     #(if (or (not (dirty?)) (js/confirm "Discard unsaved edits and switch panels?"))
                        (load! (.-value (el "app")))
                        (set! (.-value (el "app")) (get-in @state [:loaded :app]))))
  (doseq [id ["zoom" "bounds"]] (.addEventListener (el id) "change" draw!))
  (.observe (js/ResizeObserver. draw!) (el "viewport"))
  (.addEventListener js/window "keydown" (fn [e] (when (and (or (.-ctrlKey e) (.-metaKey e)) (= "s" (.-key e)))
                                                                  (.preventDefault e) (save!))))
  (.addEventListener js/window "beforeunload" (fn [e] (when (dirty?) (.preventDefault e) (set! (.-returnValue e) ""))))
  (load! "gbloink"))
(init!)
