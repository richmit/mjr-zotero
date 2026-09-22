<!-- :shell>>> ~/core/codeBits/bin/emacs_package_com_to_md.rb mjr-zotero.el -->
# Zero Dependency Zotero Integration for Emacs

See the README: https://github.com/richmit/mjr-zotero/

## Introduction

This package is a loose collection of experimental bits of code related to Zotero.  That said, I use this package almost everyday.

My primary use cases are to do the following based on ISBNs, DOIs, Zotero item-ids, and/or complex search criteria:

  - Open Zotero and select an item
  - Open Zotero PDF attachments without using the Zotero connector
  - Create bibliographies for org-mode documents exported to HTML

The first two items can be achieved interactively -- i.e. mark the criteria in the buffer, and run the function.

## General Package Organization

The mjr-zotero Emacs package provides four general categories of functionality.

The highest level functions work with a cache of Zotero data synced from a Zotero instance via the local API.  This collection of tools enables
sophisticated searching and data manipulation wholly within Emacs. These are the functions an end user is most likely to use.

 - `mjr-zotero-db-cache-bib`             Generate a bibliography -- usually from results of `mjr-zotero-db-cache-search`
 - `mjr-zotero-db-cache-bib-interactive` Interactive version of `mjr-zotero-db-cache-bib` 
 - `mjr-zotero-db-cache-search`          Sophisticated meta data searching with arbitrarily complex boolean expressions
 - `mjr-zotero-db-cache-sort`            Sort a list of entries
 - `mjr-zotero-db-cache-search-unique`   Like `mjr-zotero-db-cache-search`, but errors if results are not a single entry
 - `mjr-zotero-db-cache-populate`        Empty the Emacs Zotero DB cache, and then fill it with fresh data from Zotero
 - `mjr-zotero-db-cache-update`          Used for automatic `mjr-zotero-db-cache` updates
 - `mjr-zotero-db-cache-open-attachment` Search for an entry in `mjr-zotero-db-cache`, and open it's attachment
 - `mjr-zotero-db-cache-open-item`     Search for an entry in `mjr-zotero-db-cache`, and open it in Zotero

The next level of functionality works directly with the Zotero Local API.  The intent is to provide a low friction interface to the Zotero Local API for
programmatic use.  These functions form the ground work for the higher level functions mentioned above.  I expect these functions are rarely called directly
by end users.

 - `mjr-zotero-local-api-get-entry`       Given an item-key, pull the entry from the DB
 - `mjr-zotero-local-api-open-attachment` Given an item-key, open the item's primary attachment
 - `mjr-zotero-local-api-bib`             Given an item-key, or list of item-keys, produce a formatted bibliography
 - `mjr-zotero-local-api-call`            A nice interface to the Zotero local API
 - `mjr-zotero-local-api-search`          Search via the API (tags & quick only)
 - `mjr-zotero-local-api-last-update`     Return the date of the most recent modification

The next level of functionality works with the Zotero connector.  

 - `mjr-zotero-connector-link-to-item-key` Extract an item-key from a connector link
 - `mjr-zotero-connector-open-item`        Open an item in Zotero

The lowest level of functionality provides what might be called Zotero adjacent operations.  For example working with data structures used by by all of
the functions above.

 - `mjr-zotero-recursive-getum`            Pull elements from nested hashes/arrays
 - `mjr-zotero-element-match`              Match a Zotero entry against criteria (for searches)
 - `mjr-zotero-connector-link-to-item-key` Convert a "Zotero Connector" item link to an item-key
 - `mjr-zotero-looks-like-item-key`        Return non-NIL if the given object looks like a Zotero item-id
 - `mjr-zotero-html-bib-to-plain-text`     Convert HTML bibliographic entries to plain text

## Performance

The following observations are made in reference to a 2020 vintage laptop against a Zotero instance with 20K entries.

 - `mjr-zotero-db-cache-populate` can pull 2500 include=data entries per second into Emacs
 - `mjr-zotero-db-cache-populate` include=data,bib drops performance to 130 entries per second (a 20x hit)
 - `mjr-zotero-local-api-bib` can generate 16 apa entries per second when not using cache data
 - `mjr-zotero-local-api-bib` can generate over 50K apa entries per second when using fully cached data

Keep performance in mind when selecting a cache management strategy.

## Bibliographies in org-mode HTML exports 

We can produce nice HTML bibliographies with a code block like the following:

        #+begin_src elisp :exports none :results value :wrap "export html"
        (setq mjr-zotero-db-cache-bib-style "apa-annotated-bibliography")
        (mjr-zotero-db-cache-populate "bib:reading")
        (mjr-zotero-cache-db-make-bib)
        #+end_src

This will wrap the results in a "#+begin_export html" block.

I use a similar strategy for the combined collection of bibliographies on my web page located at https://www.mitchr.me/SS/reading/index.html which is
generated from an org-mode file found here: https://www.mitchr.me/SS/reading/index.org

## Generating A Bibliography

Two functions directly generate a bibliography.  `mjr-zotero-local-api-bib` takes one or more Zotero item-key values and uses the local API to
dynamically pull formatted bibliographic entries directly from Zotero.  This is a simple and direct method; however, it requires Zotero item-keys for the
entries.  This can be problematic because Zotero item-keys are not consistent across different instances of Zotero, and pulling them out of Zotero requires
some effort.  `mjr-zotero-db-cache-bib` takes one or more match-specifiers generates the bibliography using data in the `mjr-zotero-db-cache`.

## Installing

The easiest way to install mjr-zotero is to pull it directly from github:

     (package-vc-install (list 'mjr-zotero
                          :url "https://github.com/richmit/mjr-zotero"
                          :rev 'newest))
