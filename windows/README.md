# Sermon audio program for Windows

Makes the sermon MP3s. Runs by itself a few minutes after you sign in, then every hour while the computer is on.
If the computer is off for a while, it simply catches up next time.

## Install (about 5 minutes)

1. On the **YouTube Manager** admin page: **Settings & tools → Sermon audio settings → Add a computer**. Copy the code it shows.
2. On this page's repository: green **Code** button → **Download ZIP**. Open the ZIP and drag the `windows` folder to your Desktop.
3. Double-click **Install.cmd** in that folder. (If Windows says "Windows protected your PC", click **More info → Run anyway**.)
4. Paste the code when asked. Say **Y** to make the first sermon as a test.

That's it. You can delete the `windows` folder from the Desktop afterwards; the program lives in
`%LOCALAPPDATA%\TNBC Sermon Audio` (with a short `log.txt`).

## Moving to a new computer

1. Admin page: **Add a computer** for the new one, and run the install above on it.
2. Admin page: **Remove** the old computer (its code stops working).
3. On the old computer, double-click **Uninstall.cmd** (optional).

## Good to know

- **Only the sermon is kept.** For whole-service recordings it finds the longest stretch of preaching (singing and
  instruments have almost no pauses; preaching has constant short ones) and cuts the songs and announcements around it.
  The admin page shows which part of the video was kept, and you can set exact times there for any sermon.
- It updates itself once a day from this repository, so it never needs reinstalling for fixes.

- It uses only free tools, downloaded from their official pages: yt-dlp, ffmpeg and deno.
- It updates yt-dlp once a week, since YouTube changes often.
- It runs at low priority and doesn't open any windows.
- To run it right away and watch: double-click **Run now.cmd** in `%LOCALAPPDATA%\TNBC Sermon Audio`.
- Problems show on the admin page, and you get a phone alert if a sermon can't be made.
