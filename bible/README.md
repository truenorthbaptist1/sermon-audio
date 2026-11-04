# King James Bible text

The Authorized (King James) Version, 1769 Cambridge text, in the public domain. The YouTube Manager pulls verses
from here **by reference** for the church's Instagram posts, so no verse is ever typed by hand or by AI.

- `kjv/books.json`: the 66 books in order, with file names and chapter counts
- `kjv/<NN>-<Book>.json`: `{"book": "...", "chapters": [["verse 1", "verse 2", ...], ...]}`
- Book names follow the church's style: `I Samuel`, `II Corinthians`, `I John`, `Psalm`, `Song of Solomon`
- Words the translators supplied (printed in *italics* in a KJV) are kept in `[square brackets]`. Paragraph marks (¶) are left out.
- 31,102 verses, 1,189 chapters.

## Where it came from and how it was checked (Nov 4, 2026)

Source: [farskipper/kjv](https://github.com/farskipper/kjv) `json/verses-1769.json`.
Every verse was compared with three other public copies (Crosswire/eBible OSIS, scrollmapper, aruljohn):

- The other copies modernize spellings ("cherubim", "ankle", "Bethel", "theirs", "thoroughly"), print "Lord" for "LORD", or
  contain errors (one repeats a phrase in I Chronicles 11:2 and drops "to" in Genesis 21:17). This text keeps the
  Cambridge readings ("Cherubims", "ancle", "Beth-el", "throughly", "vapour" in Psalm 148:8, "LORD").
- About 35 verses differ between Cambridge-family printings, nearly all in the spelling of proper names
  (e.g. Sabtecha/Sabtechah, Geba/Gaba). If an exact Pure Cambridge Edition text is wanted later, it can replace these
  files as long as the format stays the same.
