(ns woc.editor.edn
  "Read exactly one EDN form, rejecting otherwise silently ignored trailing input."
  (:require #?(:clj [clojure.edn :as reader] :cljs [cljs.tools.reader.edn :as reader])
            #?(:cljs [cljs.tools.reader.reader-types :as types]))
  #?(:clj (:import [java.io PushbackReader StringReader])))

(defn read-one [source]
  (let [input #?(:clj (PushbackReader. (StringReader. source))
                 :cljs (types/string-push-back-reader source))
        eof ::eof value (reader/read {:eof eof} input)]
    (when (= eof value) (throw (ex-info "EDN source is empty." {})))
    (when-not (= eof (reader/read {:eof eof} input))
      (throw (ex-info "EDN must contain exactly one form; found trailing input." {})))
    value))
