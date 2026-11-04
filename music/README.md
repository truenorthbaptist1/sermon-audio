# Hymn music for the Scripture and question reels

Soft piano versions of public-domain hymn tunes, played under the verses in the church's Scripture and question
reels on Instagram. Sermon reels also get one softly under the preacher's voice.

- **Recordings:** by Clyde McLennan (1941–2022), a Baptist pastor, from [SmallChurchMusic.com](https://www.smallchurchmusic.com/),
  which lists his recordings as public domain and free to download. "Piano & Instrumental" versions (made from the hymnal scores
  with virtual instruments). Only his recordings are used, not those of other contributors to the site.
  The list and source links are in `scm-hymns.json`; the workflow `.github/workflows/scm-music.yml` downloads them,
  trims silence, adds a short fade in and evens them out to -22 LUFS. In use: version `alt` (Piano & Instrumental, chosen Nov 4).
  Run it with version `main` for the plainer "Simple Piano" versions.
- Switched Nov 4, 2026. The earlier FluidR3 versions (made from Open Hymnal Project scores) are kept in `fluidr3/`.
- If the church ever records its own piano player, those recordings can replace these files (same names) and the
  reels will use them automatically.

| File | Hymn (tune) | Used for |
|---|---|---|
| amazing-grace.m4a | Amazing Grace (New Britain) | grace, salvation |
| rock-of-ages.m4a | Rock of Ages (Toplady) | sin, the cross, cleansing |
| when-i-survey.m4a | When I Survey the Wondrous Cross (Hamburg) | the cross |
| it-is-well.m4a | It Is Well with My Soul (Ville du Havre) | peace, assurance |
| blessed-assurance.m4a | Blessed Assurance (Assurance) | assurance |
| holy-holy-holy.m4a | Holy, Holy, Holy (Nicaea) | God, His holiness, the Creator |
| what-a-friend.m4a | What a Friend We Have in Jesus (Converse) | comfort, prayer |
| come-thou-fount.m4a | Come, Thou Fount (Nettleton) | grace, wandering, coming home |
| how-firm-a-foundation.m4a | How Firm a Foundation (Foundation) | truth, the Word |
| abide-with-me.m4a | Abide with Me (Eventide) | death, eternity |
| pass-me-not.m4a | Pass Me Not, O Gentle Savior | repentance, invitation |
| christ-arose.m4a | Christ Arose | the resurrection |
