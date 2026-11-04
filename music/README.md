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


## Instrumental beds for sermon reels (`gfc-*.m4a`)

Soft piano hymn music played under the preacher in sermon reels. New reels take the next one in turn
(the list is in `youtube-manager/music.js`), and any reel can be switched on the admin page
(Change this reel → Music underneath).

- **Source:** "Hymnal Instrumental Music | No Copyright | Free Download" by GFC – Gems For Christ on YouTube,
  https://www.youtube.com/watch?v=gKuhRI9Wly0 (premiered Apr 5, 2021). Its description says: "No Copyright.
  Free Download… Feel free to download and share it with everyone." No named licence or credit requirement.
  Chosen by the church on Nov 4, 2026.
- **How they were cut:** the 46-minute track runs without gaps, so it was cut at quiet dips into 45–80 second
  parts (one part with a big swell and a short last part were left out). 0.8 s fade in, 1.5 s fade out,
  60 Hz high-pass, -22 LUFS, AAC 128k.
- These replaced earlier `bed-*` clips cut from a Taryn Harbridge album, which were removed on Nov 4, 2026
  because those recordings are sold commercially.

| File | Length | Feel | Starts at (in the original) |
|---|---|---|---|
| gfc-01.m4a | 75 s | soft | 0:02 |
| gfc-02.m4a | 52 s | soft | 1:17 |
| gfc-03.m4a | 60 s | soft | 2:09 |
| gfc-04.m4a | 57 s | soft | 3:09 |
| gfc-05.m4a | 50 s | quiet | 5:19 |
| gfc-06.m4a | 79 s | soft | 6:09 |
| gfc-07.m4a | 67 s | soft | 7:28 |
| gfc-08.m4a | 72 s | soft | 8:35 |
| gfc-09.m4a | 76 s | soft | 9:47 |
| gfc-10.m4a | 51 s | soft | 11:03 |
| gfc-11.m4a | 51 s | soft | 11:54 |
| gfc-12.m4a | 52 s | soft | 12:45 |
| gfc-13.m4a | 53 s | soft | 13:37 |
| gfc-14.m4a | 68 s | quiet | 14:30 |
| gfc-15.m4a | 53 s | quiet | 15:38 |
| gfc-16.m4a | 53 s | soft | 16:31 |
| gfc-17.m4a | 62 s | soft | 17:24 |
| gfc-18.m4a | 60 s | soft | 18:26 |
| gfc-19.m4a | 55 s | soft | 19:26 |
| gfc-20.m4a | 70 s | soft | 20:21 |
| gfc-21.m4a | 69 s | soft | 21:31 |
| gfc-22.m4a | 73 s | soft | 22:40 |
| gfc-23.m4a | 62 s | soft | 23:53 |
| gfc-24.m4a | 67 s | soft | 24:55 |
| gfc-25.m4a | 51 s | quiet | 26:02 |
| gfc-26.m4a | 53 s | quiet | 26:53 |
| gfc-27.m4a | 50 s | quiet | 27:46 |
| gfc-28.m4a | 54 s | soft | 28:36 |
| gfc-29.m4a | 59 s | soft | 29:30 |
| gfc-30.m4a | 78 s | soft | 30:29 |
| gfc-31.m4a | 54 s | soft | 31:47 |
| gfc-32.m4a | 51 s | soft | 32:41 |
| gfc-33.m4a | 74 s | soft | 33:32 |
| gfc-34.m4a | 59 s | fuller | 34:46 |
| gfc-35.m4a | 54 s | soft | 35:45 |
| gfc-36.m4a | 78 s | fuller | 36:39 |
| gfc-37.m4a | 66 s | soft | 37:57 |
| gfc-38.m4a | 71 s | soft | 39:03 |
| gfc-39.m4a | 65 s | soft | 40:14 |
| gfc-40.m4a | 76 s | fuller | 41:19 |
| gfc-41.m4a | 76 s | fuller | 42:35 |
| gfc-42.m4a | 73 s | fuller | 43:51 |
