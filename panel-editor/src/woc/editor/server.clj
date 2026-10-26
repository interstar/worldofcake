(ns woc.editor.server
  (:require [clojure.edn :as edn]
            [clojure.java.io :as io]
            [woc.editor.edn :as panel-edn]
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
(defn revision [a b]
  (apply str (map #(format "%02x" (bit-and % 255))
                  (.digest (MessageDigest/getInstance "SHA-256")
                           (.getBytes (pr-str [a b]) StandardCharsets/UTF_8)))))
(defn read-panel [app]
  (let [a (slurp (file-for app "layla") :encoding "UTF-8")
        b (slurp (file-for app "edn") :encoding "UTF-8")]
    {:app app :layla a :edn b :revision (revision a b)}))
(defn save-panel! [app request]
  (locking write-lock
    (let [before (read-panel app) a (:layla request) b (:edn request)]
      (when-not (= (:revision request) (:revision before))
        (throw (ex-info "Files changed on disk. Reload before saving; your edits remain in the editor." {:status 409})))
      (when-not (and (string? a) (string? b)) (throw (ex-info "Both sources are required." {:status 400})))
      (model/panel a (panel-edn/read-one b))
      ;; Validate before either write; restore the old pair if an I/O write fails.
      (try
        (spit (file-for app "layla") a :encoding "UTF-8")
        (spit (file-for app "edn") b :encoding "UTF-8")
        (catch Exception e
          (spit (file-for app "layla") (:layla before) :encoding "UTF-8")
          (spit (file-for app "edn") (:edn before) :encoding "UTF-8")
          (throw e)))
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

        (= path "/api/panel")
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
                                 (pr-str (save-panel! app (panel-edn/read-one (String. bytes StandardCharsets/UTF_8)))))))
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
  (when-not (.isDirectory (io/file root "layouts/openfl"))
    (throw (ex-info "Run from the panel-editor directory." {})))
  (let [port (Integer/parseInt (or port "8765"))
        server (HttpServer/create (InetSocketAddress. "127.0.0.1" port) 0)]
    (.createContext server "/" (reify HttpHandler (handle [_ exchange] (handle! exchange))))
    (.start server)
    (println (str "World of Cake panel editor: http://127.0.0.1:" port))
    (println "Reads and saves layouts/openfl/*.layla and *.edn. Ctrl+C to stop.")))
