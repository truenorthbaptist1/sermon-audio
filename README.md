# True North Baptist Church — sermon audio

MP3s of sermons from the [True North Baptist Church YouTube channel](https://www.youtube.com/@truenorthbaptistchurch4162),
North Pole, Alaska. They are made and added automatically; you don't need to do anything here.

- **Listen:** https://truenorthbaptist.com/sermon-audio/
- **Podcast feed:** https://truenorthbaptist.com/podcast.xml
- **The files:** under [Releases](https://github.com/truenorthbaptist1/sermon-audio/releases), one release per year

## How it works

1. Every Monday and Thursday the church's YouTube Manager tidies new sermon videos and puts them on a "needs audio" list.
2. The program in [`windows/`](windows) runs on the church's home computer every hour while it's on. It downloads just the
   audio, trims the dead air, evens out the volume, adds the series thumbnail as artwork, and sends the MP3 to the YouTube Manager.
3. The YouTube Manager stores the MP3 here and adds it to the website and the podcast feed.

`podcast-cover.jpg` is the podcast's main cover (3000 × 3000).

## Setting up a computer (or moving to a new one)

See [windows/README.md](windows/README.md).
