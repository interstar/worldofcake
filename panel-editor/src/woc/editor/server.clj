(ns woc.editor.server
  (:require [clojure.edn :as edn]
            [clojure.java.io :as io]
            [woc.editor.edn :as panel-edn]
            [worldofcake.laylagen.targets :as targets]
            [woc.editor.model :as model])
  (:import [com.sun.net.httpserver HttpServer HttpHandler]
           [java.net InetSocketAddress]
           [java.nio.charset StandardCharsets]
           [java.security MessageDigest]))

(def root (.getCanonicalFile (io/file "..")))
(def write-lock (Object.))
(defn file-for [app extension]
  (when-not (some #{app} model/apps) (throw (ex-info "Unknown WoC app." {:status 404})))
  (io/file root "layouts" "openfl" (str app "." extension)))
(defn source-info [app]
  (file-for app "edn") ; app allowlist applies to both source layouts
  (if (.isFile (io/file root "apps" app "app.edn"))
    {:kind :migrated :paths {:layla (str "apps/" app "/openfl.layla")
                            :edn (str "apps/" app "/openfl.edn")
                            :app-edn (str "apps/" app "/app.edn")}}
    {:kind :legacy :paths {:layla (str "layouts/openfl/" app ".layla")
                          :edn (str "layouts/openfl/" app ".edn")}}))
(defn revision [a b]
  (apply str (map #(format "%02x" (bit-and % 255))
                  (.digest (MessageDigest/getInstance "SHA-256")
                           (.getBytes (pr-str [a b]) StandardCharsets/UTF_8)))))
(defn read-panel [app]
  (let [{:keys [kind paths] :as info} (source-info app)
        ;; Include inherited overlays/layouts in conflict detection too. Snapshot
        ;; all flat source files so even a broken :extends can still be edited.
        dependencies (if (= :migrated kind)
                       (into (sorted-map)
                             (for [f (.listFiles (io/file root "apps" app))
                                   :when (and (.isFile f) (re-matches #"[A-Za-z][A-Za-z0-9_-]*\.(edn|layla)" (.getName f)))]
                               [(.getName f) (slurp f :encoding "UTF-8")]))
                       {})
        sources (into {} (for [[key path] paths]
                          [key (slurp (io/file root path) :encoding "UTF-8")]))]
    (merge info sources {:app app :dependencies dependencies
                         :revision (revision [kind sources] dependencies)})))
(defn resolve-sources [before request]
  (doseq [key (keys (:paths before))]
    (when-not (string? (get request key)) (throw (ex-info (str "Missing source: " key) {:status 400}))))
  (if (= :legacy (:kind before))
    {:layla (:layla request) :config (panel-edn/read-one (:edn request)) :chain []}
    ;; The build resolver reads directories. Resolve a temporary snapshot of the
    ;; draft, never write drafts into real apps/, and never duplicate merge rules.
    (let [temp (.toFile (java.nio.file.Files/createTempDirectory "woc-editor-draft" (make-array java.nio.file.attribute.FileAttribute 0)))]
      (try
        (doseq [[name content] (:dependencies before)] (spit (io/file temp name) content :encoding "UTF-8"))
        (doseq [[key path] (:paths before)]
          (when-not (= key :layla) (panel-edn/read-one (get request key)))
          (spit (io/file temp (.getName (io/file path))) (get request key) :encoding "UTF-8"))
        ;; Restrict draft inheritance to the source snapshot; prevents filesystem
        ;; traversal while still permitting arbitrary named local overlay chains.
        (doseq [f (.listFiles temp) :when (.endsWith (.getName f) ".edn")]
          (when-let [parent (:extends (panel-edn/read-one (slurp f :encoding "UTF-8")))]
            (when-not (and (or (keyword? parent) (string? parent))
                           (re-matches #"[A-Za-z][A-Za-z0-9_-]*" (name parent))
                           (not (and (keyword? parent) (namespace parent))))
              (throw (ex-info "Invalid :extends target name." {})))))
        (targets/resolve-target temp :openfl)
        (finally (doseq [f (reverse (file-seq temp))] (.delete f)))))))
(defn preview-panel [app request]
  (let [before (read-panel app)
        {:keys [config layla chain]} (resolve-sources before request)]
    (model/panel layla config)
    {:config config :layla layla :chain chain}))
(defn save-panel! [app request]
  (locking write-lock
    (let [before (read-panel app)]
      (when-not (= (:revision request) (:revision before))
        (throw (ex-info "Files changed on disk. Reload before saving; your edits remain in the editor." {:status 409})))
      (let [{:keys [config layla]} (resolve-sources before request)
            changed (filter #(not= (get before %) (get request %)) (keys (:paths before)))]
        (model/panel layla config)
        (when-not (= (:revision before) (:revision (read-panel app)))
          (throw (ex-info "Files changed while resolving the draft. Reload before saving." {:status 409})))
        (try
          (doseq [key changed] (spit (io/file root (get-in before [:paths key])) (get request key) :encoding "UTF-8"))
          (catch Exception e
            (doseq [key changed]
              (try (spit (io/file root (get-in before [:paths key])) (get before key) :encoding "UTF-8")
                   (catch Exception restore-error (.addSuppressed e restore-error))))
            (throw e))))
      (read-panel app))))
(defn respond! [exchange status content-type body]
  (let [bytes (if (string? body) (.getBytes body StandardCharsets/UTF_8) body)
        headers (.getResponseHeaders exchange)]
    (.set headers "Content-Type" content-type)
    (.set headers "Cache-Control" "no-store")
    (.set headers "X-Content-Type-Options" "nosniff")
    (.sendResponseHeaders exchange status (alength bytes))
    (with-open [out (.getResponseBody exchange)] (.write out bytes))))
(defn handle! [exchange]
  (try
    (let [uri (.getRequestURI exchange) path (.getPath uri)
          method (.getRequestMethod exchange)
          headers (.getRequestHeaders exchange)
          host (.getFirst headers "Host")
          origin (.getFirst headers "Origin")]
      (when-not (re-matches #"(?:localhost|127\.0\.0\.1):[0-9]+" (or host ""))
        (throw (ex-info "Invalid local host." {:status 403})))
      (cond
        (= path "/api/apps")
        (respond! exchange 200 "application/edn; charset=utf-8" (pr-str model/apps))

        (#{"/api/panel" "/api/preview"} path)
        (let [app (second (re-matches #"app=([a-z]+)" (or (.getRawQuery uri) "")))]
          (case method
            "GET" (respond! exchange 200 "application/edn; charset=utf-8" (pr-str (read-panel app)))
            "POST" (do
                     (when-not (and (= "1" (.getFirst headers "X-WoC-Editor"))
                                    (= "application/edn" (.getFirst headers "Content-Type"))
                                    (or (nil? origin) (= origin (str "http://" host))))
                       (throw (ex-info "Save must originate from this editor." {:status 403})))
                     (let [bytes (.readNBytes (.getRequestBody exchange) 1048577)]
                       (when (> (alength bytes) 1048576) (throw (ex-info "Source pair exceeds 1 MB." {:status 413})))
                       (respond! exchange 200 "application/edn; charset=utf-8"
                                 (pr-str ((if (= path "/api/preview") preview-panel save-panel!) app
                                          (panel-edn/read-one (String. bytes StandardCharsets/UTF_8)))))))
            (respond! exchange 405 "text/plain" "Method not allowed")))

        (= method "GET")
        (let [base (.toPath (.getCanonicalFile (io/file "resources/public")))
              relative (if (= path "/") "index.html" (subs path 1))
              file (.normalize (.resolve base relative))]
          (if (and (.startsWith file base) (.isFile (.toFile file)))
            (respond! exchange 200
                      (cond (.endsWith path ".js") "text/javascript; charset=utf-8"
                            (.endsWith path ".css") "text/css; charset=utf-8"
                            (.endsWith path ".map") "application/json"
                            :else "text/html; charset=utf-8")
                      (java.nio.file.Files/readAllBytes file))
            (respond! exchange 404 "text/plain" "Not found")))
        :else (respond! exchange 405 "text/plain" "Method not allowed")))
    (catch Exception e
      (respond! exchange (or (:status (ex-data e)) 400) "application/edn; charset=utf-8"
                (pr-str {:error (.getMessage e)})))
    (finally (.close exchange))))
(defn -main [& [port]]
  (when-not (or (.isDirectory (io/file root "layouts/openfl")) (.isDirectory (io/file root "apps")))
    (throw (ex-info "Run from the panel-editor directory." {})))
  (let [port (Integer/parseInt (or port "8765"))
        server (HttpServer/create (InetSocketAddress. "127.0.0.1" port) 0)]
    (.createContext server "/" (reify HttpHandler (handle [_ exchange] (handle! exchange))))
    (.start server)
    (println (str "World of Cake panel editor: http://127.0.0.1:" port))
    (println "Reads apps/<app>/ sources when migrated; otherwise layouts/openfl/. Ctrl+C to stop.")))
