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


## Instrumental beds for sermon reels (`bed-*.m4a`)

Soft instrumental music played under the preacher in sermon reels. New reels take the next one in turn
(the list and order are in `youtube-manager/music.js`), and any reel can be switched on the admin page
(Change this reel → Music underneath).

- **Source:** an hour-long royalty-free instrumental track supplied by the church on Nov 4, 2026 (16 pieces).
  Source and licence/credit details: _to be added_.
- **How they were cut:** at quiet points into 45–80 second parts. Parts that swell loudly or die away to
  silence were left out, so every bed loops smoothly under speech. 0.8 s fade in, 1.5 s fade out,
  80 Hz high-pass (the track has heavy sub-bass), -22 LUFS, AAC 128k.

| File | From | Length | Feel | Starts at (in the original hour) |
|---|---|---|---|---|
| bed-01a.m4a | piece 1, part a | 52 s | gentle start, quiet | 0:03 |
| bed-01b.m4a | piece 1, part b | 55 s | soft | 0:55 |
| bed-01c.m4a | piece 1, part c | 52 s | fuller | 1:50 |
| bed-02a.m4a | piece 2, part a | 53 s | gentle start, quiet | 3:52 |
| bed-02b.m4a | piece 2, part b | 50 s | quiet | 4:45 |
| bed-03a.m4a | piece 3, part a | 72 s | soft | 7:07 |
| bed-03b.m4a | piece 3, part b | 73 s | soft | 8:19 |
| bed-03c.m4a | piece 3, part c | 61 s | fuller | 9:32 |
| bed-04a.m4a | piece 4, part a | 50 s | soft | 11:20 |
| bed-04b.m4a | piece 4, part b | 56 s | soft | 12:10 |
| bed-04c.m4a | piece 4, part c | 77 s | fuller | 13:06 |
| bed-05a.m4a | piece 5, part a | 71 s | gentle start, soft | 15:05 |
| bed-05b.m4a | piece 5, part b | 50 s | soft | 16:16 |
| bed-05c.m4a | piece 5, part c | 56 s | fuller | 17:06 |
| bed-06a.m4a | piece 6, part a | 50 s | gentle start, quiet | 18:47 |
| bed-06c.m4a | piece 6, part c | 60 s | soft | 20:28 |
| bed-07a.m4a | piece 7, part a | 56 s | gentle start, soft | 22:07 |
| bed-07b.m4a | piece 7, part b | 50 s | fuller | 23:03 |
| bed-08a.m4a | piece 8, part a | 76 s | gentle start, soft | 25:29 |
| bed-08b.m4a | piece 8, part b | 51 s | soft | 26:45 |
| bed-08c.m4a | piece 8, part c | 51 s | fuller | 27:36 |
| bed-09a.m4a | piece 9, part a | 74 s | gentle start, soft | 29:33 |
| bed-09b.m4a | piece 9, part b | 61 s | soft | 30:47 |
| bed-10a.m4a | piece 10, part a | 50 s | quiet | 32:55 |
| bed-10b.m4a | piece 10, part b | 58 s | soft | 33:45 |
| bed-11a.m4a | piece 11, part a | 64 s | gentle start, quiet | 36:15 |
| bed-11b.m4a | piece 11, part b | 77 s | soft | 37:19 |
| bed-11c.m4a | piece 11, part c | 55 s | soft | 38:36 |
| bed-11d.m4a | piece 11, part d | 68 s | soft | 39:31 |
| bed-12a.m4a | piece 12, part a | 50 s | gentle start, quiet | 40:42 |
| bed-12b.m4a | piece 12, part b | 66 s | fuller | 41:32 |
| bed-12c.m4a | piece 12, part c | 77 s | fuller | 42:38 |
| bed-13b.m4a | piece 13, part b | 55 s | soft | 45:53 |
| bed-13c.m4a | piece 13, part c | 78 s | fuller | 46:48 |
| bed-14a.m4a | piece 14, part a | 73 s | quiet | 49:11 |
| bed-14b.m4a | piece 14, part b | 72 s | soft | 50:24 |
| bed-15a.m4a | piece 15, part a | 70 s | gentle start, soft | 53:11 |
| bed-15b.m4a | piece 15, part b | 72 s | soft | 54:21 |
| bed-16a.m4a | piece 16, part a | 52 s | soft | 56:45 |
| bed-16b.m4a | piece 16, part b | 63 s | soft | 57:37 |
| bed-16c.m4a | piece 16, part c | 80 s | soft | 58:40 |
