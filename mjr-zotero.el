;;; mjr-zotero.el --- Zotero Emacs Integration -*- lexical-binding:t; coding: utf-8; mode:emacs-lisp; fill-column:158 -*-

;; Copyright (c) 2026-2026 Mitch Richling <https://www.mitchr.me>.  All rights reserved.
;;
;; Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
;;
;; 1. Redistributions of source code must retain the above copyright notice, this list of conditions, and the following disclaimer.
;;
;; 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions, and the following disclaimer in the documentation
;;    and/or other materials provided with the distribution.
;;
;; 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without
;;    specific prior written permission.
;;
;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
;; FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
;; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
;; TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

;; Author:      Mitch Richling
;; Version:     1.7
;; Keywords:    mjr-zotero
;; URL:         https://github.com/richmit/mjr-zotero

;; This file is not part of Emacs

;;; Commentary:
;;
;; * Zero Dependency Zotero Integration for Emacs
;;
;; See the README: https://github.com/richmit/mjr-zotero/
;;
;; ** Introduction
;;
;; This package is a loose collection of experimental bits of code related to Zotero.  That said, I use this package almost everyday.
;;
;; My primary use cases are to do the following based on ISBNs, DOIs, Zotero item-ids, and/or complex search criteria:
;;
;;   - Open Zotero and select an item
;;   - Open Zotero PDF attachments without using the Zotero connector
;;   - Create bibliographies for org-mode documents exported to HTML
;;
;; The first two items can be achieved interactively -- i.e. mark the criteria in the buffer, and run the function.
;;
;; ** General Package Organization
;;
;; The mjr-zotero Emacs package provides four general categories of functionality.
;;
;; The highest level functions work with a cache of Zotero data synced from a Zotero instance via the local API.  This collection of tools enables
;; sophisticated searching and data manipulation wholly within Emacs. These are the functions an end user is most likely to use.
;;
;;  - `mjr-zotero-db-cache-bib`             Generate a bibliography -- usually from results of `mjr-zotero-db-cache-search`
;;  - `mjr-zotero-db-cache-bib-interactive' Interactive version of `mjr-zotero-db-cache-bib` 
;;  - `mjr-zotero-db-cache-search`          Sophisticated meta data searching with arbitrarily complex boolean expressions
;;  - `mjr-zotero-db-cache-sort`            Sort a list of entries
;;  - `mjr-zotero-db-cache-search-unique`   Like `mjr-zotero-db-cache-search`, but errors if results are not a single entry
;;  - `mjr-zotero-db-cache-populate`        Empty the Emacs Zotero DB cache, and then fill it with fresh data from Zotero
;;  - `mjr-zotero-db-cache-update`          Used for automatic `mjr-zotero-db-cache` updates
;;  - `mjr-zotero-db-cache-open-attachment` Search for an entry in `mjr-zotero-db-cache`, and open it's attachment
;;  - `mjr-zotero-db-cache-open-item`     Search for an entry in `mjr-zotero-db-cache`, and open it in Zotero
;;
;; The next level of functionality works directly with the Zotero Local API.  The intent is to provide a low friction interface to the Zotero Local API for
;; programmatic use.  These functions form the ground work for the higher level functions mentioned above.  I expect these functions are rarely called directly
;; by end users.
;;
;;  - `mjr-zotero-local-api-get-entry`       Given an item-key, pull the entry from the DB
;;  - `mjr-zotero-local-api-open-attachment` Given an item-key, open the item's primary attachment
;;  - `mjr-zotero-local-api-bib`             Given an item-key, or list of item-keys, produce a formatted bibliography
;;  - `mjr-zotero-local-api-call`            A nice interface to the Zotero local API
;;  - `mjr-zotero-local-api-search`          Search via the API (tags & quick only)
;;  - `mjr-zotero-local-api-last-update`     Return the date of the most recent modification
;;
;; The next level of functionality works with the Zotero connector.  
;;
;;  - `mjr-zotero-connector-link-to-item-key` Extract an item-key from a connector link
;;  - `mjr-zotero-connector-open-item`        Open an item in Zotero
;;
;; The lowest level of functionality provides what might be called Zotero adjacent operations.  For example working with data structures used by by all of
;; the functions above.
;;
;;  - `mjr-zotero-recursive-getum`            Pull elements from nested hashes/arrays
;;  - `mjr-zotero-element-match`              Match a Zotero entry against criteria (for searches)
;;  - `mjr-zotero-connector-link-to-item-key` Convert a "Zotero Connector" item link to an item-key
;;  - `mjr-zotero-looks-like-item-key`        Return non-NIL if the given object looks like a Zotero item-id
;;  - `mjr-zotero-html-bib-to-plain-text'     Convert HTML bibliographic entries to plain text
;;
;; ** Performance
;;
;; The following observations are made in reference to a 2020 vintage laptop against a Zotero instance with 20K entries.
;;
;;  - `mjr-zotero-db-cache-populate' can pull 2500 include=data entries per second into Emacs
;;  - `mjr-zotero-db-cache-populate' include=data,bib drops performance to 130 entries per second (a 20x hit)
;;  - `mjr-zotero-local-api-bib' can generate 16 apa entries per second when not using cache data
;;  - `mjr-zotero-local-api-bib' can generate over 50K apa entries per second when using fully cached data
;;
;; Keep performance in mind when selecting a cache management strategy.
;;
;; ** Bibliographies in org-mode HTML exports 
;;
;; We can produce nice HTML bibliographies with a code block like the following:
;;
;;         #+begin_src elisp :exports none :results value :wrap "export html"
;;         (setq mjr-zotero-db-cache-bib-style "apa-annotated-bibliography")
;;         (mjr-zotero-db-cache-populate "bib:reading")
;;         (mjr-zotero-cache-db-make-bib)
;;         #+end_src
;;
;; This will wrap the results in a "#+begin_export html" block.
;;
;; I use a similar strategy for the combined collection of bibliographies on my web page located at https://www.mitchr.me/SS/reading/index.html which is
;; generated from an org-mode file found here: https://www.mitchr.me/SS/reading/index.org
;;
;; ** Generating A Bibliography
;;
;; Two functions directly generate a bibliography.  `mjr-zotero-local-api-bib' takes one or more Zotero item-key values and uses the local API to
;; dynamically pull formatted bibliographic entries directly from Zotero.  This is a simple and direct method; however, it requires Zotero item-keys for the
;; entries.  This can be problematic because Zotero item-keys are not consistent across different instances of Zotero, and pulling them out of Zotero requires
;; some effort.  `mjr-zotero-db-cache-bib' takes one or more match-specifiers generates the bibliography using data in the `mjr-zotero-db-cache'.
;;
;; ** Installing
;;
;; The easiest way to install mjr-zotero is to pull it directly from github:
;;
;;      (package-vc-install (list 'mjr-zotero
;;                                :url "https://github.com/richmit/mjr-zotero"
;;                                :rev 'newest))
;;
;; Note that mjr-thingy-lookeruper (https://github.com/richmit/mjr-thingy-lookeruper) supports this package, so install it too if you wish.


;;; Code:

(require 'cl-lib)
(require 'url)
(require 'subr-x)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; mjr-zotero
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun mjr-zotero-html-bib-to-plain-text (b)
  "Convert a string with a Zotero HTML formatted bibliographic entry into plain, ASCII text.  Returns NIL if something goes wrong.
This function will only convert strings that appear to be Zotero HTML formatted bibliographic entries, and thus should be idempotent under expected use cases.
Conversion from Unicode to ASCII is limited; however, it gets most of the non-ASCII characters introduced from common Zotero's bibliography styles."
  (when (stringp b)
    (if (not (string-match-p "\\`[[:space:]\n\r]*<div[[:space:]\n\r]*class" b))
        b
        (let ((s (with-temp-buffer
                   (insert b)
                   (shr-render-region (point-min) (point-max))
                   (buffer-substring-no-properties (point-min) (point-max)))))
          (when (and (stringp s) (< 0 (length s)))
            (setq s (string-trim s))
            (dolist (p '((#x2013 . "-")
                         (#x2014 . "-")
                         (#x2019 . "'")
                         (#x2018 . "'")
                         (#x2019 . "'")
                         (#x00fc . "u")
                         (#x00f8 . "o")
                         (#x00e4 . "a")
                         (#x0161 . "s")
                         (#x201c . "\"")
                         (#x201D . "\"")
                         (#x00f6 . "o")))
              (setq s (string-replace (string (car p)) (cdr p) s)))
            (setq s (replace-regexp-in-string "\\\\[`'^~=.\"]{\\([a-zA-Z]\\)}" "\\1" s))  ;; Remove LaTeX accents with bracket protected argument
            (setq s (replace-regexp-in-string "\\\\[`'^~=.\"]\\([a-zA-Z]\\)"   "\\1" s))  ;; Remove LaTeX accents without bracket protected argument
            s)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun mjr-zotero-recursive-getum (error-handler expected-type dat-o-dat &rest rest)
  "Recursively pull hash elements/array values from a nested collection of hash/array members.
 - ERROR-HANDLER should be NIL or a function like `error' or `message'
   - If NIL no error checking is preformed and NIL is returned if an error is encountered
   - If ERROR-HANDLER is a function that dosen't throw an error, then the return upon error will be NIL
 - EXPECTED-TYPE should be NIL or a type symbol
   - If NIL, then no error checking is performed on the final type returned
   - If non-NIL, then the result type is checked and ERROR-HANDLER is executed."
  (cl-loop for da-key in rest
           for da-typ = (type-of dat-o-dat)
           finally (cl-return (if (and expected-type (not (eq expected-type (type-of dat-o-dat))))
                                  (progn (when error-handler
                                           (funcall error-handler "mjr-zotero-recursive-getum: Expected '%s' but got '%s'." (type-of dat-o-dat) expected-type))
                                         nil)
                                  dat-o-dat))
           do (setq dat-o-dat (pcase da-typ
                                ('hash-table (gethash da-key dat-o-dat))
                                ('vector     (aref dat-o-dat da-key))
                                (_           (when error-handler
                                               (funcall error-handler "mjr-zotero-recursive-getum: Hash not found while extracting key %s." da-key)
                                               (cl-return nil)))))))

;; (mjr-zotero-recursive-getum 'error nil mjr-zotero-db-cache "ELEGQ7NT" "data" "creators" 0 "lastName")
;; "Rucklidge"
;;
;; (mjr-zotero-recursive-getum 'error nil (mjr-zotero-local-api-get-entry "X9FA49XE") "data" "creators" 0 "lastName")
;; "Fortuna"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;###autoload
(defun mjr-zotero-looks-like-item-key (something)
  "Return non-NIL if SOMETHING is a string that looks like a Zotero item key"
  (and (stringp something) (let ((case-fold-search nil))
                             (string-match-p "\\`[0-9A-Z]\\{8\\}\\'" something))))

;; (mjr-zotero-looks-like-item-key "ELEGQ7NT")
;; 0
;;
;; (mjr-zotero-looks-like-item-key "elegq7nt")
;; nil
;;
;; (mjr-zotero-looks-like-item-key "ELEGQ7N")
;; nil
;;
;; (mjr-zotero-looks-like-item-key "ELEGQ7NTT")
;; nil

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defconst mjr-zotero-string-predicates #s(hash-table data (:regex             string-match-p
                                                           :ends-with         string-suffix-p
                                                           :starts-with       string-prefix-p
                                                           :equal             string-equal
                                                           :contains          string-search
                                                           :equal-ignore-case string-equal-ignore-case
                                                           :greater           string-greaterp
                                                           :less              string-lessp)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defcustom mjr-zotero-element-match-default-predicate :equal
  "The predicate used when not explicitly provided as part of a match specifier."
  :type 'symbol
  :group 'mjr-zotero)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defcustom mjr-zotero-element-match-hash-skip-keys '(("creators" "creatorType")
                                                     ("tags"     "type"))
  "Keys to skip for some match checks.  For details see `mjr-zotero-element-match'."
  :type 'symbol
  :group 'mjr-zotero)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defcustom mjr-zotero-data-key-re (list (list "key"  "zotero://select/items/[0-9]_"         "\\(?1:[0-9A-Z]\\{8\\}\\)")
                                        (list "DOI"  "\\(DOI:\\|doi:\\|https://doi.org/\\)" "\\(?1:10\\.[1-9][0-9]\\{3,\\}/[^[:space:]\n\r]\\{1,\\}\\)")
                                        (list "ISBN" "\\(isbn\\|ISBN\\):"                   "\\(?1:[0-9]\\(-?[0-9]\\)\\{8\\}\\(\\(-?[0-9]\\)\\{3\\}\\)?-?[0-9]\\)"))
  "Regular expressions for identify strings as keys.
Each sub-list contains the key, a regex for optional prefix junk, and a regex for the object.  The regular expressions are case sensitive.  One, and only one,
of the regular expressions must contain an explicitly numbered group 1.  This named group 1 is used to identify the value to be matched against the key
allowing for throw-away identifying text around a key value.  For example: (list \"citationKey\" \"\" \"cite:\\(?1:[^[:space:]\\n\\r]+\\)\")

The default value recognizes:
  - Zotero item keys (both by themselves and as a Zotero connector URL)
  - ISBN numbers (with or without an ISBN:/isbn: prefix)
  - DOIs (with or without a doi: prefix or as part of a doi.org URL)"
  :type '(repeat (cons string string))
  :group 'mjr-zotero)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;###autoload
(defun mjr-zotero-match-specifier-at-point ()
  "Return the match-specifier in the marked region or a string that looks like a key value near the point.  Return NIL if nothing is found.
When called with an active region, the return is a lisp expression if the active region's contents look like a complete lisp expression and a string
otherwise.  Without an active region the return will be a string (if something that looks like a key value is found), or NIL otherwise."
  (or (when (and transient-mark-mode (region-active-p) (mark))
        (let ((s (buffer-substring-no-properties (region-beginning) (region-end))))
          (when s
            (if (string-match-p "\\`'?(.*)\\'" s)
                (car (read-from-string (concat "'" (string-remove-prefix "'" s))))
                s))))
      (let ((case-fold-search nil))
        (cl-loop for (k p v) in mjr-zotero-data-key-re
                 for m = (and (thing-at-point-looking-at (concat "\\b\\(" p "\\)?\\(" v "\\)\\b") 100) (match-string 1))
                 when m
                 do (cl-return (substring-no-properties m))))
      (error "mjr-zotero-match-specifier-at-point: Unable to find match-specifier (no marked region or recognized key near point)!")))

;; ;; Some targets for at-point tests
;; ;; For an interactive demo, try mjr-zotero-db-cache-open-item or mjr-zotero-db-cache-open-attachment with these
;;
;; 686PNJGS
;; zotero://select/items/0_7JU94X7V
;; 10.1016/0893-9659(89)90079-7
;; doi:10.1016/0893-9659(89)90079-7
;; https://doi.org/10.1016/0893-9659(89)90079-7
;; ISBN:978-0-321-63773-4
;; isbn:978-0-321-63773-4
;; 978-0-321-63773-4

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun mjr-zotero-element-match (element match-specifier)
  "Return non-NIL if the ELEMENT matches MATCH-SPECIFIER.
MATCH-SPECIFIER is a simple match-specifier a lisp expression containing simple match-specifiers.

Simple match-specifiers are used to test a match against a single hash value in the data member of ELEMENT.  The single hash value (DATA-VALUE) is specified
by DATA-KEY in what follows -- it amounts to (gethash DATA-KEY (gethash \"data\" element)).  The method of testing a match is the PREDICATE in what follows.
Simple predicates come in three forms:

  1) ([PREDICATE] DATA-KEY SEARCH-STRING) -- Matching strings
      - PREDICATE (optional) one of the following keywords:
        - :regex ............... string-match-p
        - :ends-with ........... string-suffix-p
        - :starts-with ......... string-prefix-p
        - :equal ............... string-equal
        - :contains ............ string-search
        - :equal-ignore-case ... string-equal-ignore-case
        - :greater ............. string-greaterp
        - :less ................ string-lessp
        - :missing ............. Returns non-NIL if the data value is NIL
      - If PREDICATE is not provided, then `mjr-zotero-element-match-default-predicate' is used.
      - DATA-KEY is a key in the data member (a hash) of ELEMENT.  These keys are strings.
      - SEARCH-STRING is used to determine a match with the value in ELEMENT
      - The return value is:
        - If DATA-VALUE is a string: The value of the predicate run against the SEARCH-STRING and DATA-VALUE string
        - If DATA-VALUE is an array of hashs: Non-NIL if the predicate run against the SEARCH-STRING and values in the DATA-VALUE hash is non-NIL
          Values in the DATA-VALUE hash are ignored if they have a key in the `mjr-zotero-element-match-hash-skip-keys' for the given DATA-KEY
  2) ([PREDICATE] DATA-KEY SUB-KEY-1 SEARCH-STRING-1 ...) -- Only used when  DATA-VALUE is an array of hashes
    - PREDICATE & DATA-KEY are as in 1).
    - The SUB-KEY-N element of each hash contained in the value for DATA-KEY are tested against SEARCH-STRING-N.
    - The return is non-NIL if ALL sub-* tests are non-NIL for at least one hash in the array
  3) SEARCH-STRING
     - The DATA-KEY is found by using the first matching regular expressions in `mjr-zotero-data-key-re'

Match-specifiers are expressions containing simple match-specifiers.  For example we can combine two simple match-specifiers
with an AND like this:
    \='(and (:equal \"itemType\" \"book\") (:missing \"ISBN\"))"
  (cl-flet ((string-it (v)
              (if (stringp v)
                  v
                  (format "%s" v))))
    ;; Transform nekked string into a match-specifier list
    (when (stringp match-specifier)
      (if-let ((ms (cl-loop for (k p v) in mjr-zotero-data-key-re
                            when (let ((case-fold-search nil))
                                   (string-match (concat "\\`\\(" p "\\)?\\(" v "\\)\\'") match-specifier))
                            do (cl-return (list mjr-zotero-element-match-default-predicate k (match-string 1 match-specifier))))))
          (setq match-specifier ms)
        (error "mjr-zotero-element-match: Unable to determine data key from search string: %s" match-specifier)))
    ;; Test for match
    (when (and (listp match-specifier) (not (null match-specifier)))
      (if (stringp (car match-specifier))
          (push mjr-zotero-element-match-default-predicate match-specifier))
      (if (keywordp (car match-specifier))
          (let* ((match-method (car match-specifier))
                 (search-key   (cadr match-specifier))
                 (data-value   (mjr-zotero-recursive-getum 'error nil element "data" search-key))
                 (search-bits  (cddr match-specifier))
                 (predicate    (gethash match-method mjr-zotero-string-predicates)))
            (when (eq 0 (length search-bits))
              (error "mjr-zotero-element-match: No match vlaue provided!"))
            (pcase (type-of data-value)
              ('symbol  (and (null data-value) (eq match-method :missing)))
              ('vector  (if (cdr search-bits)
                            (cl-some (lambda (y) (cl-loop for i from 0
                                                          for (k s) on search-bits while s
                                                          for m = (funcall predicate (gethash k y) s)
                                                          finally (cl-return m)
                                                          while m))
                                     data-value)
                            (cl-some (lambda (y) (cl-some (lambda (x) (funcall predicate (car search-bits) (string-it (gethash x y))))
                                                          (cl-set-difference (hash-table-keys y)
                                                                             (cdr (assoc search-key mjr-zotero-element-match-hash-skip-keys)))))
                                     data-value)))
              (_  (let ((search-string (car search-bits)))
                    (if (not (stringp search-string))
                        (error "mjr-zotero-element-match: Non-string for string data value string match (%s)!" match-specifier))
                    (if (cdr search-bits)
                        (error "mjr-zotero-element-match: Invalid MATCH-SPECIFIER for string data value (%s)!" match-specifier))
                    (funcall predicate search-string (string-it data-value))))))
          (eval (cons (car match-specifier) (mapcar (lambda (x) (mjr-zotero-element-match element x)) (cdr match-specifier))))))))

;; (mjr-zotero-element-match (mjr-zotero-local-api-get-entry "X9FA49XE") "X9FA49XE")
;; t
;; TODO: Add demo for connector URL.
;;
;; (mjr-zotero-element-match (mjr-zotero-local-api-get-entry "X9FA49XE") "978-981-283-924-4")
;; t
;; TODO: Add demo for isbn prefixes
;;
;; (mjr-zotero-element-match (mjr-zotero-local-api-get-entry "9H6MQWM9") "10.48550/arXiv.2108.01999")
;; t
;; TODO: Add demo for doi prefix and doi.org url
;;
;; (mjr-zotero-element-match (mjr-zotero-local-api-get-entry "X9FA49XE") '(:equal "itemType" "book"))
;; t
;;
;; (mjr-zotero-element-match (mjr-zotero-local-api-get-entry "X9FA49XE") '(:equal "itemType" "sbook"))
;; nil
;;
;; (mjr-zotero-element-match (mjr-zotero-local-api-get-entry "X9FA49XE") '(:equal "version" "0"))
;; t
;;
;; (mjr-zotero-element-match (mjr-zotero-local-api-get-entry "X9FA49XE") '(:equal "tags" "bib:reading"))
;; t
;;
;; (mjr-zotero-element-match (mjr-zotero-local-api-get-entry "X9FA49XE") '(:equal "tags" "bib:readings"))
;; nil
;;
;; (mjr-zotero-element-match (mjr-zotero-local-api-get-entry "X9FA49XE") '(:equal "creators" "Fortuna"))
;; t
;;
;; (mjr-zotero-element-match (mjr-zotero-local-api-get-entry "X9FA49XE") '(:equal "creators" "lastName" "Fortuna"))
;; t
;;
;; (mjr-zotero-element-match (mjr-zotero-local-api-get-entry "X9FA49XE") '(:equal "creators" "lastName" "Fortunax"))
;; nil
;;
;; (mjr-zotero-element-match (mjr-zotero-local-api-get-entry "X9FA49XE") '(and (:equal "itemType" "book") (:equal "creators" "lastName" "Fortuna")))
;; t

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; mjr-zotero-local-api
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defcustom mjr-zotero-local-api-host "127.0.0.1"
  "Host name/IP address for local API port."
  :type 'string
  :group 'mjr-zotero)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defcustom mjr-zotero-local-api-port 23119
  "TCP/IP Port for local API port"
  :type 'natnum
  :group 'mjr-zotero)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defcustom mjr-zotero-local-api-timeout 60
  "Timeout for local API calls."
  :type 'natnum
  :group 'mjr-zotero)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defcustom mjr-zotero-local-api-verbose t
  "If non-NIL then produce a `message' for each API call.
In addition to being useful for debug, this also provides a nice status display when generating a bibliography."
  :type 'boolean
  :group 'mjr-zotero)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun mjr-zotero-local-api-call (expected-type endpoint &rest query-kv-pairs)
  "Call the Zotero local API via HTTP.  Return NIL for most logical failures.
 - QUERY-KV-PAIRS
   - Each argument is a cons cell or NIL
   - The argument is ignored if it's NIL, contains NIL, contains a non-string, or contains an empty string
     - A pair with a value component of \='ignore is the typical way to have a pair ignored but not contain a NIL.
 - ENDPOINT should be a string or list of strings
   - If it is a string it will be used as the endpoint
   - If it is a list then the strings will be joined with /
 - EXPECTED-TYPE should be NIL or a type symbol
   - If EXPECTED-TYPE is NIL, then the raw string returned by the local server is returned.
   - If EXPECTED-TYPE is non-NIL, then the result is JSON parsed and the type of the result is compared with EXPECTED-TYPE.
The Zotero Local API must be enabled in the Zotero client:
   - On Windows: go to Edit > Preferences  ___or___  On MacOS: go to Zotero > Preferences
   - Navigate to the Advanced tab.
   - Check on the option to \"Allow other applications on this computer to communicate with Zotero\"."
  (let* ((ep-str   (if (stringp endpoint)
                       endpoint
                       (string-join endpoint "/")))
         (base-url (concat "http://" mjr-zotero-local-api-host ":" (number-to-string mjr-zotero-local-api-port) ep-str))
         (srch-str (string-join (remove nil (mapcar (lambda (kv) (when-let* ((  kv)
                                                                             (k (car kv))
                                                                             (  (stringp k))
                                                                             (  (not (string-empty-p k)))
                                                                             (v (cdr kv))
                                                                             (  (stringp v))
                                                                             (  (not (string-empty-p v))))
                                                                   (concat k "=" (url-hexify-string v))))
                                                    query-kv-pairs))
                                "&"))
         (full-url (concat base-url (unless (string-empty-p srch-str)
                                      (concat "?" srch-str)))))
    (when mjr-zotero-local-api-verbose
      (message "Zotero Local API Call: %s" full-url))
    (let ((res-buf  (url-retrieve-synchronously full-url t t mjr-zotero-local-api-timeout)))
      (when res-buf
        (with-current-buffer res-buf
          (goto-char (point-min))
          (re-search-forward "\n\n" nil 'move) ;; Jump to start of body
          (let ((res-str (buffer-substring-no-properties (point) (point-max))))
            (kill-buffer res-buf)
            (if (null expected-type)
                res-str
                (when (and res-str (stringp res-str) (not (string-empty-p res-str)))
                  (let ((res-lsp (json-parse-string res-str)))
                    (when (eq (type-of res-lsp) expected-type)
                      res-lsp))))))))))

;; (mjr-zotero-local-api-call 'hash-table "/api/users/0/items/UEQBISIW" )
;; (mjr-zotero-local-api-call 'vector     "/api/users/0/items/WHVVHHDH/children")
;; (mjr-zotero-local-api-call 'hash-table "/api/users/0/items/top/UEQBISIW")
;; (mjr-zotero-local-api-call 'hash-table "/api/users/0/items/WHVVHHDH")
;; (mjr-zotero-local-api-call 'hash-table "/api/users/0/items/UGQQAXPB")
;; (mjr-zotero-local-api-call 'vector     "/api/users/0/items/top" '("tag" . "bib:reading"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun mjr-zotero-local-api-get-entry (item-key)
  "Pull item data for Zotero object with the given ITEM-KEY via the Zotero Local API."
  (if-let ((responce (mjr-zotero-local-api-call 'hash-table (list "/api/users/0/items" item-key))))
      responce
    (error "mjr-zotero-local-api-get-entry: Somthing went wrong")))

;; (mjr-zotero-local-api-get-entry "UEQBISIW")
;; (mjr-zotero-local-api-get-entry "WHVVHHDH")
;; (mjr-zotero-local-api-get-entry "UGQQAXPB")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun mjr-zotero-local-api-search (&optional tag q everything)
  "Return top level Zotero object(s) matching the search criteria via the Zotero Local API.
TAG & Q are strings in the Zotero local API syntax.  For example, search for items with the tag \"art\" or \"calc\" with a TAG value of \"art||calc\"."
  (if-let ((responce (mjr-zotero-local-api-call 'vector "/api/users/0/items/top" (cons "tag" tag) (cons "q" q) (when everything '("qmode" . "everything")))))
      responce
    (error "mjr-zotero-local-api-get-entry: Somthing went wrong")))

;; (length (mjr-zotero-local-api-search nil "Murray" nil))
;; 10
;;
;; (length (mjr-zotero-local-api-search "m:applied:bio" nil nil))
;; 19
;;
;; (length (mjr-zotero-local-api-search "m:applied:bio" "Murray" nil))
;; 2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun mjr-zotero-local-api-open-attachment (item-key)
  "Vsit the URL for the primary attachment of the given Zotero object via the Zotero Local API.
WARNING: This will sometimes open the wrong attachment.  It should have a way to let the user select which attachment."
  (if-let* ((attachment-url (mjr-zotero-recursive-getum nil 'string (mjr-zotero-local-api-get-entry item-key) "links" "attachment" "href"))
            (attachment-id  (replace-regexp-in-string "^.*/" "" attachment-url))
            (enclosure-url  (mjr-zotero-recursive-getum nil 'string (mjr-zotero-local-api-get-entry attachment-id) "links" "enclosure" "href")))
      (browse-url enclosure-url)
    (error "mjr-zotero-local-api-open-attachment: Something went wrong!")))

;; (mjr-zotero-local-api-open-attachment "7JU94X7V")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun mjr-zotero-local-api-last-update (&optional tag)
  "Return a string with timestamp (in ISO 8601 format) of last DB update via the Zotero Local API.
See `mjr-zotero-local-api-search' for additional information regarding the syntax used for the TAG argument."
  (mjr-zotero-recursive-getum 'error 'string
                              (mjr-zotero-local-api-call 'vector "/api/users/0/items/top" '("sort" . "dateModified") '("limit" . "1") (cons "tag" tag))
                              0 "data" "dateModified"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defcustom mjr-zotero-local-api-bib-style "apa-annotated-bibliography"
  "bibliography style used by `mjr-zotero-db-cache-bib' and `mjr-zotero-local-api-bib'."
  :type '(choice (const nil) string)
  :group 'mjr-zotero)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defcustom mjr-zotero-prompt-bib-styles (list "apa-annotated-bibliography"
                                              "apa"
                                              "apa-single-spaced"
                                              "chicago-note-bibliography"
                                              "modern-language-association"
                                              "chicago-author-date"
                                              "harvard-cite-them-right")
  "List of bibliography styles that appear in interactive prompts.
The default includes the following:
  - apa .......................... My go-to most of the time.  Best for on the web where we can adjust it with CSS.
  - apa-annotated-bibliography ... Best for annotated bibliographies on the web where we adjust it with CSS (Not built in)
  - apa-single-spaced ............ Best for print use where we can't use CSS (Not built in)
  - chicago-note-bibliography .... This is the default style used by Zotero
  - chicago-author-date .......... It's still Chicago, but more APA-like
  - modern-language-association .. The one I used while at university
  - harvard-cite-them-right ..... Similar to APA but uses a bit more space."
  :type '(repeat string)
  :group 'mjr-zotero)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun mjr-zotero-local-api-bib (item-key-or-list-of-item-keys &optional bib-style between-string plain-text)
  "Generate a formatted bibliographic entry for an item via the Zotero Local API.
Uses `mjr-zotero-local-api-bib-style' if BIB-STYLE is not provided or is NIL."
  (mapconcat (lambda (x) (let* ((e (mjr-zotero-local-api-call 'hash-table
                                                              (concat "/api/users/0/items/" x)
                                                              (cons "include" "bib")
                                                              (cons "style" (or bib-style mjr-zotero-local-api-bib-style))))
                                (b (if e
                                       (gethash "bib" e)
                                       (error "mjr-zotero-local-api-bib: Local API call failed"))))
                           (unless (and b (stringp b) (not (string-empty-p b)))
                             (error "mjr-zotero-local-api-bib: Unable to generate formatted bibliographic entry."))
                           (if plain-text
                               (or (mjr-zotero-html-bib-to-plain-text b)
                                   (error "mjr-zotero-db-cache-bib: Plain-Text conversion failed for %s!" b))
                               b)))
             (if (listp item-key-or-list-of-item-keys)
                 item-key-or-list-of-item-keys
                 (list item-key-or-list-of-item-keys))
             (or between-string "\n\n")))

;; (mjr-zotero-local-api-bib "M2BXF445")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; mjr-zotero-connector
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun mjr-zotero-connector-link-to-item-key (url)
  "Transform a Zotero link for the Zotero connector into a Zotero item ID."
  (let ((id (string-remove-prefix "zotero://select/items/0_" url)))
    (if (string-equal url id)
        (error "mjr-zotero-connector-link-to-item-key: Invalid connector item link!")
        id)))

;; (mjr-zotero-connector-link-to-item-key "zotero://select/items/0_WHVVHHDH")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;###autoload
(defun mjr-zotero-connector-open-item (item-key)
  "Given an item-key, use the Zotero connector to open Zotero and select an item."
    (browse-url (concat "zotero://select/items/0_" item-key)))

;; (mjr-zotero-connector-open-item "7JU94X7V")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; mjr-zotero-db-cache
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar mjr-zotero-db-cache nil
  "Cache Zotero DB inside Emacs.

Cache management:
 - Manual: Simply call `mjr-zotero-db-cache-populate' & `mjr-zotero-db-cache-update' as required
 - Automatic: Set `mjr-zotero-db-cache-search-auto-refresh' non-NIL. Occasionally call `mjr-zotero-db-cache-clear' to force a full update.

Populating the cache takes time.  Limiting what is loaded into the cache can help.
 - Manual: Use the TAG argument of `mjr-zotero-db-cache-populate' & `mjr-zotero-db-cache-update'
 - Automatic: Set `mjr-zotero-db-cache-update-tag'")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar mjr-zotero-db-cache-timestamp "1972-01-01T01:01:01Z"
  "When `mjr-zotero-db-cache' is non-NIL, contains a string with an update timestamp for `mjr-zotero-db-cache'.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defcustom mjr-zotero-db-cache-include nil
  "A list of items to include in the cache.
If missing \"data\", then it will be added before use.  The inclusion of \"bib\" with a complex style can dramatically slow down cache population/update."
  :type '(repeat (choice (const "bib")
                         (const "citation")
                         (const "data")))
  :group 'mjr-zotero)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;###autoload
(defun mjr-zotero-db-cache-clear ()
  "Clear the contents of `mjr-zotero-db-cache'"
  (setq mjr-zotero-db-cache nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;###autoload
(defun mjr-zotero-db-cache-populate (&optional tag)
  "Populate `mjr-zotero-db-cache' with fresh data via the local API.
Return is the number of records found.
See `mjr-zotero-local-api-search' for additional information regarding the syntax used for the TAG argument.
Note this function makes no use of the custom variable `mjr-zotero-db-cache-update-tag'."
  (let ((start-time (current-time)))
    (message "Populating Zotero DB Cache...")
    (if-let* ((result  (mjr-zotero-local-api-call 'vector "/api/users/0/items/top"
                                                  (cons "tag" tag)
                                                  (cons "include" (string-join (delete-dups (cons "data" mjr-zotero-db-cache-include)) ","))))
              (num-elt (length result))
              (        (< 0 num-elt)))
        (progn (setq mjr-zotero-db-cache (let ((h (make-hash-table :test #'equal)))
                                           (cl-loop for e across result
                                                    for k = (gethash "key" e)
                                                    do (puthash k e h))
                                           h))
               (setq mjr-zotero-db-cache-timestamp (format-time-string "%FT%T%Z" (current-time) "Z"))
               (message "Populating Zotero DB Cache... Complete (%s objects loaded in %f seconds)!" num-elt (float-time (time-since start-time)))
               num-elt)
      (progn (mjr-zotero-db-cache-clear)
             (error "Populating Zotero DB Cache... Failed!")))))

;; (mjr-zotero-db-cache-populate "bib:reading")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defcustom mjr-zotero-db-cache-update-tag nil
  "Used by `mjr-zotero-db-cache-update'.
If this is a string, then it uses the local Zotero API syntax -- See: `mjr-zotero-local-api-search' for more information.
See `mjr-zotero-local-api-search' for additional information regarding the syntax used for the TAG argument."
  :type '(choice (const nil) string)
  :group 'mjr-zotero)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defcustom mjr-zotero-db-cache-update-limit 100
  "Maximum number of entries `mjr-zotero-db-cache-update' will pull at one time."
  :type 'natnum
  :group 'mjr-zotero)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defcustom mjr-zotero-db-cache-update-populate nil
  "If non-NIL then `mjr-zotero-db-cache-update' will do full updates via `mjr-zotero-db-cache-populate' wherever `mjr-zotero-db-cache' is stale."
  :type 'boolean
  :group 'mjr-zotero)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun mjr-zotero-db-cache-state (&optional tag)
  "Return NIL if the cache is clean, and a keyword representing the state of the cache otherwise.
Keywords that can be returned:
 - :old The cache exists and Zotero has been updated since the last sync
 - :nil The cache is NIL
 - :bad-date The cache is non-NIL, but the date is malformed"
  (cond ((null mjr-zotero-db-cache)                                                                   :nil)
        ((not (stringp mjr-zotero-db-cache-timestamp))                                       :bad-date)
        ((string-lessp mjr-zotero-db-cache-timestamp (mjr-zotero-local-api-last-update tag)) :old)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun mjr-zotero-db-cache-update (&optional populate)
  "Update the contents of `mjr-zotero-db-cache' if they are stale.  Returns the number of entries updated or NIL if no update is required.
This function attempts to preform incremental updates:
  - Successfully synced:
    - Entries with changed meta-data in Zotero
    - New entries added to Zotero
  - Some things not synced -- Use `mjr-zotero-db-cache-clear' to clear the cache so the next update will be a call to `mjr-zotero-db-cache-populate'.
    - Collection changes (like renaming a collection) are *NOT* synced
    - Deleted items"
  (when-let ((cache-state (mjr-zotero-db-cache-state mjr-zotero-db-cache-update-tag)))
    (if (or populate mjr-zotero-db-cache-update-populate (member cache-state '(:nil :bad-date)))
        (mjr-zotero-db-cache-populate mjr-zotero-db-cache-update-tag)
        (progn
          (message "Updating Zotero DB Cache...")
          (let ((tot (cl-loop for start from 0 by mjr-zotero-db-cache-update-limit
                              for entries = (let ((tmp (ignore-errors (mjr-zotero-local-api-call 'vector "/api/users/0/items/top"
                                                                                                 (cons "sort"    "dateModified")
                                                                                                 (cons "start"   (number-to-string start))
                                                                                                 (cons "limit"   (number-to-string mjr-zotero-db-cache-update-limit))
                                                                                                 (cons "include" (string-join (delete-dups (cons "data" mjr-zotero-db-cache-include)) ","))
                                                                                                 (cons "tag"     mjr-zotero-db-cache-update-tag)))))
                                              (or tmp
                                                  (progn (mjr-zotero-db-cache-clear)
                                                         (error "mjr-zotero-db-cache-update: Failure in Zotero local API call!"))))
                              for updated = (cl-loop for ne across entries
                                                     for nd = (mjr-zotero-recursive-getum 'error 'string ne "data" "dateModified")
                                                     for k  = (gethash "key" ne)
                                                     for oe = (gethash k mjr-zotero-db-cache)
                                                     for od = (when oe
                                                                (mjr-zotero-recursive-getum 'error 'string oe "data" "dateModified"))
                                                     while (string-lessp od nd)
                                                     count 1
                                                     do (puthash k ne mjr-zotero-db-cache))
                              sum updated
                              while (< 0 updated))))
            (setq mjr-zotero-db-cache-timestamp (format-time-string "%FT%T%Z" (current-time) "Z"))
            (message "Updating Zotero DB Cache... Complete (%d objects updated)!" tot)
            tot)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defcustom mjr-zotero-db-cache-search-auto-refresh nil
  "If non-NIL, then auto update `mjr-zotero-db-cache' when stale."
  :type 'boolean
  :group 'mjr-zotero)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun mjr-zotero-db-cache-search (match-specifier)
  "Return list of item-keys from `mjr-zotero-db-cache' with data blocks matching MATCH-SPECIFIER.

If MATCH-SPECIFIER `mjr-zotero-looks-like-item-key' then the `mjr-zotero-element-match' matching methodology is bypassed entirely.  In this case: if
`mjr-zotero-db-cache' contains MATCH-SPECIFIER as a key, then a single element list containing MATCH-SPECIFIER is returned otherwise NIL is returned.  To use
the standard matching methodology, provide MATCH-SPECIFIER in list form: \='([predicate] \"key\" \"value\")

If `mjr-zotero-db-cache-search-auto-refresh' is non-NIL then this function might trigger calls to `mjr-zotero-db-cache-update'.
See `mjr-zotero-element-match' for a description of the MATCH-SPECIFIER argument.  Can trigger automatic update of `mjr-zotero-db-cache'."
  (when mjr-zotero-db-cache-search-auto-refresh
    (mjr-zotero-db-cache-update))
  (unless mjr-zotero-db-cache
    (error "mjr-zotero-db-cache-search: No cached data"))
  (if (mjr-zotero-looks-like-item-key match-specifier)
      (when (gethash match-specifier mjr-zotero-db-cache)
        (list match-specifier))
      (cl-loop for e being each hash-value of mjr-zotero-db-cache
               when (mjr-zotero-element-match e match-specifier)
               collect (gethash "key" e))))

;; (mjr-zotero-db-cache-search '("ISBN" "978-0-321-63773-4"))
;; ("A7CKANL9")
;;
;; (mjr-zotero-db-cache-search "978-0-321-63773-4")
;; ("A7CKANL9")
;;
;; (mjr-zotero-db-cache-search '("creators" "Sprung"))
;; ("RDL2V4QR" "Q6EPFC7M" "2XRKZESC")
;;
;; (mjr-zotero-db-cache-search '("tags" "bib:zoo"))
;; ("MIXEQ7HJ" "Z7YQAJJ9" "JT9P48NQ" "UAP668GS" "E5Q8EIIZ" "39Q8I3ZG" "529E8MF2" "EZXIFFZW" "HQN75ZBG" "JIHPBT5V" "QG4NC4S9" "4WUZWWM9" "KF722PVR" "G8V5JGQ9" "VJFJ6B2Z" "5368V7JT" "4KBWF22Z" "2JGB9I2E" "P8Q3BN4T" "SY8CDQP6" "UCSC3Z6A" "ELEGQ7NT")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun mjr-zotero-db-cache-search-unique (&rest match-specifiers)
  "Call `mjr-zotero-db-cache-search' for each argument & trigger an error if any of the calls do not result in a single entry.
The use case is for generating bibliographies with each argument representing a unique entry in the DB.
This function returns a list with a single entry for each argument."
  (when (null match-specifiers)
    (error "mjr-zotero-db-cache-search-unique: No search criteria specified!"))
  (cl-loop for ms in match-specifiers
           for r = (mjr-zotero-db-cache-search ms)
           until (cond ((null r) (error "mjr-zotero-db-cache-search-unique: Search resulted in zero matches: %s!" ms))
                       ((cdr r)  (error "mjr-zotero-db-cache-search-unique: Search resulted in multiple matches: %s!" ms)))
           collect (car r)))

;; (mjr-zotero-db-cache-search-unique '("key" "M2BXF445") '("key" "A7CKANL9"))
;; ("M2BXF445" "A7CKANL9")
;;
;; (mjr-zotero-db-cache-search-unique '(and ("key" "M2BXF445") '("key" "A7CKANL9")))
;; !ERROR! -- no match
;;
;; (mjr-zotero-db-cache-search-unique '(or ("key" "M2BXF445") '("key" "A7CKANL9")))
;; !ERROR! -- multiple match
;;
;; (mjr-zotero-db-cache-search-unique "X9FA49XE")
;; ("X9FA49XE")
;;
;; (mjr-zotero-db-cache-search-unique "10.1142/7200")
;; ("X9FA49XE")
;;
;; (mjr-zotero-db-cache-search-unique "978-981-283-924-4")
;; ("X9FA49XE")
;;
;; (mjr-zotero-db-cache-search-unique "0-7167-1480-9")
;; ("5KZ82Z3K")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defcustom mjr-zotero-db-cache-sort-multi-keys '(("data" "creators" 0 "lastName")
                                                 ("data" "date")
                                                 ("data" "title"))
  "The function `mjr-zotero-db-cache-sort-multi-keys' uses this as the default value for the MULTI-KEYS argument."
  :type '(repeat (repeat string))
  :group 'mjr-zotero)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun mjr-zotero-db-cache-sort (match-specifiers &rest multi-keys)
  "Return a list of sorted item-keys.
Each MULTI-KEYS argument is a list applied to `mjr-zotero-recursive-getum' to extract an element of `mjr-zotero-db-cache'.  If NIL, then
`mjr-zotero-db-cache-sort-multi-keys' will be used. If both are NIL, then the item-key will be used. The sort is lexicographical across all the MULTI-KEYS --
i.e.  the data is first sorted by the first MULTI-KEYS argument, then by the second, etc...

For examples:
 - Sort by by date
   \='(\"data\" \"date\")
 - Sort by by date and then last name of first author
   \='(\"data\" \"date\") \='(\"data\" \"creators\" 0 \"lastName\")
 - Sort by first author last name and then by first name
    (mjr-zotero-db-cache-sort ms \='(\"data\" \"creators\" 0 \"lastName\") \='(\"data\" \"creators\" 0 \"firstName\")"
  (sort (mapcar (lambda (x) (car (mjr-zotero-db-cache-search-unique x))) match-specifiers)
        :lessp (lambda (x y) (cl-loop for keys in (or multi-keys mjr-zotero-db-cache-sort-multi-keys '(("key")))
                                      for xv = (apply #'mjr-zotero-recursive-getum 'error 'string mjr-zotero-db-cache x keys)
                                      for yv = (apply #'mjr-zotero-recursive-getum 'error 'string mjr-zotero-db-cache y keys)
                                      ;;do (print (message "%s %s" xv yv))
                                      when (if (null xv)
                                               (not (null yv))
                                               (and (not (null yv)) (string-lessp xv yv)))
                                      do (cl-return t)))))

;; (sort '("Z7YQAJJ9" "39Q8I3ZG" "JT9P48NQ" "E5Q8EIIZ" ))
;; ("39Q8I3ZG" "E5Q8EIIZ" "JT9P48NQ" "Z7YQAJJ9")
;;
;; (mapcar (lambda (x) (mjr-zotero-recursive-getum nil nil mjr-zotero-db-cache x "key")) '("Z7YQAJJ9" "39Q8I3ZG" "JT9P48NQ" "E5Q8EIIZ"))
;; ("Z7YQAJJ9" "39Q8I3ZG" "JT9P48NQ" "E5Q8EIIZ")
;;
;; (mjr-zotero-db-cache-sort '("Z7YQAJJ9" "39Q8I3ZG" "JT9P48NQ" "E5Q8EIIZ") '("key"))
;; ("39Q8I3ZG" "E5Q8EIIZ" "JT9P48NQ" "Z7YQAJJ9")
;;
;; (mapcar (lambda (x) (mjr-zotero-recursive-getum nil nil mjr-zotero-db-cache x "data" "creators" 0 "lastName")) '("Z7YQAJJ9" "39Q8I3ZG" "JT9P48NQ" "E5Q8EIIZ"))
;; ("Rikitake" "Chen" "Sprott" "Posch")
;;
;; (mjr-zotero-db-cache-sort '("Z7YQAJJ9" "39Q8I3ZG" "JT9P48NQ" "E5Q8EIIZ" ) '("data" "creators" 0 "lastName"))
;; ("39Q8I3ZG" "E5Q8EIIZ" "Z7YQAJJ9" "JT9P48NQ")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun mjr-zotero-db-cache-bib (match-specifiers &optional bib-style between-string fresh-bib plain-text)
  "Take a list of MATCH-SPECIFIERS, and generate a bibliography as a string.
Each element of MATCH-SPECIFIERS is processed via `mjr-zotero-db-cache-search-unique' to produce an item-key.  The entries will be processed and output in the
order they are provided.  Use `mjr-zotero-db-cache-search' to quickly identify large bibliographies and `mjr-zotero-db-cache-search' to sort them.

 - BIB-STYLE: String with a a bibliographic style known to Zotero.  If NIL, then `mjr-zotero-local-api-bib-style' is used.
   This value is *only* used when this function calls `mjr-zotero-local-api-bib' for a fresh bibliographic entry.
 - BETWEEN-STRING is used to separate each formatted bibliographic entry produced.
 - PLAIN-TEXT being non-NIL results in the HTML bib entry being converted to plain ASCII text using `mjr-zotero-html-bib-to-plain-text'
 - If FRESH-BIB is NIL, then bibliographic entries in `mjr-zotero-db-cache' are used and `mjr-zotero-local-api-bib' is only used if
   the value is not found in the cache.  When FRESH-BIB is non-NIL, `mjr-zotero-local-api-bib' is used for every entry."
  (let* ((list-of-item-keys (if (null match-specifiers)
                                (hash-table-keys mjr-zotero-db-cache)
                                (mapcar (lambda (x) (car (mjr-zotero-db-cache-search-unique x))) match-specifiers)))
         (list-of-bibs      (cl-loop for k in list-of-item-keys
                                     for e = (gethash k mjr-zotero-db-cache)
                                     for d = (gethash "data" e)
                                     for b = (let ((bc (unless fresh-bib
                                                         (gethash "bib" d))))
                                               (if (and bc (stringp bc) (not (string-empty-p bc)))
                                                   bc
                                                   (let ((ba (mjr-zotero-local-api-bib k bib-style)))
                                                     (if (and ba (stringp ba) (not (string-empty-p bc)))
                                                         (puthash "bib" ba d)
                                                         (error "mjr-zotero-db-cache-bib: Unable to produce bibliographic entry for %s!" k)))))
                                     collect (if plain-text
                                                 (or (mjr-zotero-html-bib-to-plain-text b)
                                                     (error "mjr-zotero-db-cache-bib: Plain-Text conversion failed for %s!" b))
                                                 b))))
    (string-join list-of-bibs (or between-string "\n\n"))))

;; ;; These are all the same:
;; (mjr-zotero-db-cache-bib '(("key" "M2BXF445") ("key" "A7CKANL9")))
;;
;; (mjr-zotero-db-cache-bib '("M2BXF445" "A7CKANL9"))
;;
;; ;; Identical to the above, but explicitly calling mjr-zotero-db-cache-search-unique
;; (mjr-zotero-db-cache-bib (append (mjr-zotero-db-cache-search-unique  '("key" "M2BXF445")) (mjr-zotero-db-cache-search-unique  '("key" "A7CKANL9"))))
;; (mjr-zotero-db-cache-bib (mjr-zotero-db-cache-search-unique "M2BXF445" "A7CKANL9"))
;;
;; ;; Like above, but order and uniqueness are not guarnteed
;; (mjr-zotero-db-cache-bib (mjr-zotero-db-cache-search '(or ("key" "M2BXF445") ("key" "A7CKANL9"))))
;; (mjr-zotero-db-cache-bib (mjr-zotero-db-cache-search '(or "M2BXF445" "A7CKANL9")))
;;
;; ;; I usually identify a bibliography via a tag:
;; (mjr-zotero-db-cache-bib (mjr-zotero-db-cache-search '("tags" "bib:reading")))
;;
;; ;; If LIST-OF-ENTRIES-AND-OR-MATCH-SPECIFIERS is NIL, then the entire DB is used.  The following two calls are the same:
;; (mjr-zotero-db-cache-bib (hash-table-values mjr-zotero-db-cache))
;; (mjr-zotero-db-cache-bib (hash-table-keys mjr-zotero-db-cache))
;; (mjr-zotero-db-cache-bib nil)
;;
;; doi:10.1016/0893-9659(89)90079-7

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;###autoload
(defun mjr-zotero-db-cache-open-attachment (match-specifier &optional no-error)
  "Find the Zotero object with `mjr-zotero-db-cache-search-unique', and use `mjr-zotero-local-api-open-attachment' to open it's attachment.
if MATCH-SPECIFIER matched something in `mjr-zotero-db-cache', the return is non-NIL.  If it didn't match, then NIL is when NO-ERROR is non-NIL and an error
occurs otherwise."
  (interactive (list (mjr-zotero-match-specifier-at-point)))
  (when-let ((item-key (if no-error
                           (ignore-errors (car (mjr-zotero-db-cache-search-unique match-specifier)))
                           (car (mjr-zotero-db-cache-search-unique match-specifier)))))
    (mjr-zotero-local-api-open-attachment item-key)
    t))

;; (mjr-zotero-db-cache-open-attachment "10.1016/0893-9659(89)90079-7")
;; (mjr-zotero-db-cache-open-attachment "7JU94X7V")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;###autoload
(defun mjr-zotero-db-cache-open-item (match-specifier &optional no-error)
  "Find the Zotero object with `mjr-zotero-db-cache-search-unique', and use the Zotero connector switch to zotero and select the found entry.
if MATCH-SPECIFIER matched something in `mjr-zotero-db-cache', the return is non-NIL.  If it didn't match, then NIL is when NO-ERROR is non-NIL and an error
occurs otherwise."
  (interactive (list (mjr-zotero-match-specifier-at-point)))
  (when-let ((item-key (if no-error
                               (ignore-errors (car (mjr-zotero-db-cache-search-unique match-specifier)))
                               (car (mjr-zotero-db-cache-search-unique match-specifier)))))
    (mjr-zotero-connector-open-item item-key)
    t))

;; (mjr-zotero-db-cache-open-item "10.1016/0893-9659(89)90079-7")
;; (mjr-zotero-db-cache-open-item "7JU94X7V")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;###autoload
(defun mjr-zotero-db-cache-bib-interactive (match-specifier &optional bib-style fresh-bib plain-text)
  "Find the Zotero object with `mjr-zotero-db-cache-search-unique' and generate a text bibliography.
When run interactively the text is placed on the kill ring and a message is printed.
Used interactively:
  - match-specifier is pulled from the buffer using `mjr-zotero-match-specifier-at-point'
  - Without a prefix argument
    - BIB-STYLE is NIL which means the value in `mjr-zotero-local-api-bib-style' is used
    - FRESH-BIB is NIL
    - PLAIN-TEXT is t
  - With a prefix argument
    - BIB-STYLE is queried from the user from options listed in `mjr-zotero-prompt-bib-styles'
    - FRESH-BIB is t
    - PLAIN-TEXT is queried from the user"
  (interactive (list (mjr-zotero-match-specifier-at-point)
                     (when current-prefix-arg
                       (if (and (boundp 'ido-everywhere) ido-everywhere)
                           (ido-completing-read "Bibliography Style: " mjr-zotero-prompt-bib-styles nil nil mjr-zotero-local-api-bib-style)
                           (completing-read     "Bibliography Style: " mjr-zotero-prompt-bib-styles nil nil mjr-zotero-local-api-bib-style)))
                     current-prefix-arg
                     (if current-prefix-arg
                         (y-or-n-p "Result as plain text? ")
                         t)))
  (let ((b (mjr-zotero-db-cache-bib (mjr-zotero-db-cache-search match-specifier) bib-style nil fresh-bib plain-text)))
    (when (called-interactively-p 'any)
      (kill-new b)
      (message "Bibliography (%d chars) placed on kill ring!" (length b)))
    b))

;; (mjr-zotero-db-cache-bib-interactive "10.1016/0893-9659(89)90079-7")
;; (mjr-zotero-db-cache-open-item "7JU94X7V")

;; (mjr-zotero-db-cache-bib-interactive "10.1016/0893-9659(89)90079-7" nil 't)
;; "Bogacki, P., & Shampine, L. F. (1989). A 3(2) pair of Runge-Kutta formulas. Applied Mathematics Letters, 2(4), 321-325.
;; https://doi.org/10.1016/0893-9659(89)90079-7"
;;
;; (mjr-zotero-db-cache-bib-interactive "10.1016/0893-9659(89)90079-7" "apa-annotated-bibliography" 't)
;; "Bogacki, P., & Shampine, L. F. (1989). A 3(2) pair of Runge-Kutta formulas. Applied Mathematics Letters, 2(4), 321-325.
;; https://doi.org/10.1016/0893-9659(89)90079-7"
;;
;; (mjr-zotero-db-cache-bib-interactive "10.1016/0893-9659(89)90079-7" "apa" 't)
;; "Bogacki, P., & Shampine, L. F. (1989). A 3(2) pair of Runge-Kutta formulas. Applied Mathematics Letters, 2(4), 321-325.
;; https://doi.org/10.1016/0893-9659(89)90079-7"
;;
;; (mjr-zotero-db-cache-bib-interactive "10.1016/0893-9659(89)90079-7" "apa-single-spaced" 't)
;; "Bogacki, P., & Shampine, L. F. (1989). A 3(2) pair of Runge-Kutta formulas. Applied Mathematics Letters, 2(4), 321-325.
;; https://doi.org/10.1016/0893-9659(89)90079-7"
;;
;; (mjr-zotero-db-cache-bib-interactive "10.1016/0893-9659(89)90079-7" "chicago-note-bibliography" 't)
;; "Bogacki, P., and L. F. Shampine. \"A 3(2) Pair of Runge - Kutta Formulas.\" Applied Mathematics Letters 2, no. 4 (1989): 321-25.
;; https://doi.org/10.1016/0893-9659(89)90079-7."
;;
;; (mjr-zotero-db-cache-bib-interactive "10.1016/0893-9659(89)90079-7" "modern-language-association" 't)
;; "Bogacki, P., and L. F. Shampine. \"A 3(2) Pair of Runge - Kutta Formulas.\" Applied Mathematics Letters, vol. 2, no. 4, Jan. 1989, pp.
;; 321-25, https://doi.org/10.1016/0893-9659(89)90079-7."
;;
;; (mjr-zotero-db-cache-bib-interactive "10.1016/0893-9659(89)90079-7" "chicago-author-date" 't)
;; "Bogacki, P., and L. F. Shampine. 1989. \"A 3(2) Pair of Runge - Kutta Formulas.\" Applied Mathematics Letters 2 (4): 321-25.
;; https://doi.org/10.1016/0893-9659(89)90079-7."
;;
;; (mjr-zotero-db-cache-bib-interactive "10.1016/0893-9659(89)90079-7" "harvard-cite-them-right" 't)
;; "Bogacki, P. and Shampine, L.F. (1989) \"A 3(2) pair of Runge - Kutta formulas,\" Applied Mathematics Letters, 2(4), pp. 321-325. Available
;; at: https://doi.org/10.1016/0893-9659(89)90079-7."

;; ;; Here is one I don't have in Zotero:
;; 10.1016/0771-050X(80)90013-3

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; mjr-zotero-X
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(provide 'mjr-zotero)

;; (mjr-install-mjr-packages :reinstall :git 'mjr-zotero)

;;; mjr-zotero.el ends here
