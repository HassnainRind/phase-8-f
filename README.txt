Petalhaven - Flutter rebuild, PHASE 8g (all screens, all 10 games, forms, backup, animations, exact hero photos)

Build the APK on GitHub (no installs):
 1. New GitHub repo -> upload everything in this folder (keep the .github folder; if it is skipped,
    create the file .github/workflows/build-apk.yml by hand and paste the contents from this zip).
 2. Actions tab -> "Build Flutter APK" -> wait ~6-8 min (first run downloads Flutter).
 3. Open the finished run -> Artifacts -> Petalhaven-Flutter-APK -> unzip -> install app-release.apk.

If the build fails, open the red step and send me the error text. This code has not been compiled yet.

Backup compatibility: "Share full backup" / "Choose file" use the same JSON format as the website,
so a backup exported from the original Petalhaven HTML can be imported here (and vice versa).

Phase 8b changes: real vibration for Breathing haptics (vibration package + VIBRATE permission added by the workflow),
Challenge -/+ removed from Snake and Meadow maze, alarm sound + vibration when the exercise timer ends (audioplayers,
assets/sounds/alarm.wav), calendar cell number no longer jumps during the tap ripple, mini exercise cards now show a
static GIF fully inside the card (hero images and full-page GIFs untouched).

Phase 8d: "Remove this day only" in the daily log for period days (splits/shortens a period instead of deleting the batch),
tap haptics on buttons/cells/game pads, rhythm game note sounds, exercise sheet can be dragged down to close.

Phase 8f: every bottom sheet (exercise, history, settings, daily log, breathing...) now follows your finger: hold & drag the top handle, or pull down when scrolled to the top.

Phase 8g: breathing sound cues, game win/lose sounds (all games), 'done' chime on Mark complete, global Sound on/off (Settings + Breathing screen).
