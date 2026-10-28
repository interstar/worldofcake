(ns woc.editor.test-runner
  (:require [clojure.test :refer :all]
            [clojure.edn :as edn]
            [clojure.java.io :as io]
            [layla.core :as layla]
            [worldofcake.laylagen.core :as generator]
            [woc.editor.model :as model]
            [woc.editor.edn :as panel-edn]
            [woc.editor.server :as server]))

(deftest production-geometry-parity
  (doseq [app model/apps]
    (testing app
      (let [pair (server/read-panel app)
            {:keys [config layla]} (server/resolve-sources pair pair)
            expected (generator/calculate-geometry (:root (:data (layla/parse-intent layla)))
                                                  (:geometry config) (:components config))
            actual (:placed (model/panel layla config))]
        (is (= expected actual) "Every container and leaf rectangle matches production")))))

(deftest invalid-edits
  (let [pair (server/read-panel "gbloink") config (edn/read-string (:edn pair))]
    (is (thrown? Exception (model/panel "[broken" config)))
    (is (thrown? Exception (model/panel (:layla pair) (assoc-in config [:geometry :outer-padding] 10000))))
    (is (thrown? Exception (model/panel (:layla pair) (assoc-in config [:components "redspeed" :minimum] 0))))
    (is (thrown? Exception (model/panel (:layla pair) (assoc-in config [:components "redspeed" :kind] :unknown))))
    (is (thrown? Exception (model/panel (:layla pair) (update config :components dissoc "redspeed"))))
    (is (thrown? Exception (server/file-for "../gbloink" "edn")))))

(deftest complete-edn
  (is (= {:a 1} (panel-edn/read-one "{:a 1} ;; a trailing comment\n")))
  (is (thrown? Exception (panel-edn/read-one "{:a 1} broken")))
  (is (thrown? Exception (panel-edn/read-one "{:a 1} }")))
  (is (thrown? Exception (panel-edn/read-one "; empty"))))

(deftest choice-range-support
  (let [pair (server/read-panel "timeslider")
        config (:config (server/resolve-sources pair pair))
        expanded (:config (model/panel (:layla pair) config))
        channel (get-in expanded [:components "lane1channel"])
        cc (get-in expanded [:components "lane1cc"])]
    (is (= 16 (count (:choices channel))))
    (is (= {:value 1 :label "Ch 1"} (first (:choices channel))))
    (is (= {:value 16 :label "Ch 16"} (last (:choices channel))))
    (is (= 128 (count (:choices cc))))
    (is (= {:value 1 :label "CC 1"} (nth (:choices cc) (:default-index cc))))
    (is (nil? (:choice-range channel)))
    (when-let [production-expand (ns-resolve 'worldofcake.laylagen.core 'expand-specs)]
      (is (= (production-expand config) expanded)))
    (is (thrown? Exception (model/expand-specs {:components {"bad" {:choice-range {:from 16 :to 1}}}})))))

(deftest save-roundtrip-and-conflict
  ;; Exercise the real save path only against a temporary repository, never user files.
  (let [temp (.toFile (java.nio.file.Files/createTempDirectory "woc-panel-editor-test" (make-array java.nio.file.attribute.FileAttribute 0)))
        layout (io/file temp "layouts/openfl") pair (server/read-panel "gbloink")]
    (.mkdirs layout)
    (try
      (with-redefs [server/root temp]
        (spit (server/file-for "gbloink" "layla") (:layla pair) :encoding "UTF-8")
        (spit (server/file-for "gbloink" "edn") (:edn pair) :encoding "UTF-8")
        (let [before (server/read-panel "gbloink")
              edited (update before :edn str "\n;; roundtrip ✓\n")
              saved (server/save-panel! "gbloink" edited)]
          (is (= (:edn edited) (:edn saved)))
          (is (not= (:revision before) (:revision saved)))
          (is (= 409 (:status (ex-data (try (server/save-panel! "gbloink" before) (catch Exception e e))))))
          (is (thrown? Exception (server/save-panel! "gbloink" (assoc saved :layla "[invalid"))))
          (is (= saved (server/read-panel "gbloink")))) )
      (finally
        (doseq [file (reverse (file-seq temp))] (.delete file))))))

(deftest migrated-sources-workflow
  (let [temp (.toFile (java.nio.file.Files/createTempDirectory "woc-apps-test" (make-array java.nio.file.attribute.FileAttribute 0)))
        app-dir (io/file temp "apps/timeslider") legacy-dir (io/file temp "layouts/openfl")
        originals (server/read-panel "timeslider")]
    (.mkdirs app-dir) (.mkdirs legacy-dir)
    (doseq [[name content] (:dependencies originals)] (spit (io/file app-dir name) content :encoding "UTF-8"))
    (spit (io/file legacy-dir "timeslider.layla") "NEVER WRITE THIS")
    (spit (io/file legacy-dir "timeslider.edn") "NEVER WRITE THIS")
    (try
      (with-redefs [server/root temp]
        (let [before (server/read-panel "timeslider")
              draft (-> before (update :layla str "\n") (update :edn str "\n;; visual ✓\n") (update :app-edn str "\n;; shared ✓\n"))
              preview (server/preview-panel "timeslider" draft)]
          (is (= :migrated (:kind before)))
          (is (= #{:layla :edn :app-edn} (set (keys (:paths before)))))
          (is (= [:openfl] (:chain preview)))
          (is (map? (model/panel (:layla preview) (:config preview))))
          (is (= before (server/read-panel "timeslider")) "Preview never writes real sources")
          (is (thrown? Exception (server/save-panel! "timeslider" (assoc draft :edn "{} trailing"))))
          (is (= before (server/read-panel "timeslider")) "Invalid merged draft writes nothing")
          (let [saved (server/save-panel! "timeslider" draft)]
            (doseq [key [:layla :edn :app-edn]] (is (= (get draft key) (get saved key))))
            (doseq [key [:layla :edn :app-edn]]
              (let [f (io/file temp (get-in saved [:paths key]))]
                (spit f (str (get saved key) "\n") :encoding "UTF-8")
                (is (= 409 (:status (ex-data (try (server/save-panel! "timeslider" saved) (catch Exception e e))))))
                (spit f (get saved key) :encoding "UTF-8")))
            (is (= "NEVER WRITE THIS" (slurp (io/file legacy-dir "timeslider.edn"))))
            (is (= "NEVER WRITE THIS" (slurp (io/file legacy-dir "timeslider.layla"))))))
        (let [before (server/read-panel "timeslider")
              draft (-> before (update :layla str "\n") (update :edn str "\n;; rollback\n") (update :app-edn str "\n;; rollback\n"))
              write-fn spit failed? (atom false)
              target (.getCanonicalPath (io/file app-dir "openfl.edn"))]
          (with-redefs [clojure.core/spit
                        (fn [file & args]
                          (if (and (= target (.getCanonicalPath (io/file file))) (compare-and-set! failed? false true))
                            (throw (java.io.IOException. "Injected write failure"))
                            (apply write-fn file args)))]
            (is (thrown? java.io.IOException (server/save-panel! "timeslider" draft))))
          (is @failed?)
          (is (= before (server/read-panel "timeslider")) "A partial save restores all three files"))
        ;; An actual inherited overlay is resolved by the generator, not editor merging.
        (let [before (server/read-panel "timeslider")
              overlay (panel-edn/read-one (:edn before))
              geometry (:geometry overlay)]
          (spit (io/file app-dir "desktop.edn") (pr-str {:geometry geometry :probe {:keep 1 :drop 2} :items [1 2]}))
          (spit (io/file app-dir "openfl.edn")
                (pr-str (assoc (dissoc overlay :geometry) :extends :desktop :probe {:drop nil} :items [3])))
          (let [inherited (server/read-panel "timeslider")
                preview (server/preview-panel "timeslider" inherited)]
            (is (= [:openfl :desktop] (:chain preview)))
            (is (= geometry (get-in preview [:config :geometry])))
            (is (= {:keep 1} (get-in preview [:config :probe])))
            (is (= [3] (get-in preview [:config :items])))
            (spit (io/file app-dir "desktop.edn") "{}")
            (is (= 409 (:status (ex-data (try (server/save-panel! "timeslider" inherited) (catch Exception e e)))))))))
      (finally (doseq [f (reverse (file-seq temp))] (.delete f))))))

(defn -main [& _]
  (println "Layla parser source:" (str (io/resource "layla/core.cljc")))
  (println "Target resolver source:" (str (io/resource "worldofcake/laylagen/targets.clj")))
  (let [result (run-tests 'woc.editor.test-runner)]
    (System/exit (if (zero? (+ (:fail result) (:error result))) 0 1))))
