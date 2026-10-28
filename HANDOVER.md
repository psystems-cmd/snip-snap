# Handover — screen-ocr

**Status:** working, in daily use. Last worked on 22.10.2026.

## What it is

`Cmd+Shift+ß` → native crosshair region select → Vision OCR → text on the clipboard.
Built for text that is visually present but unselectable: PDFs, photos, website images.
Hotkey bound via Raycast; the binary itself knows nothing about hotkeys.

Everything lives in this folder. `README.md` is the reference; this file is just the state
of play.

## Built 21.10.2026

Swift binary over Apple's Vision framework, ~126 lines. Chosen over an Apple Shortcut because
Shortcuts could not be shown to expose the two settings that matter, and `shortcuts sign`
rejected a hand-authored plist. Those two settings are the whole point of the tool:

- `recognitionLanguages = ["de-DE", "en-US"]` — one pass, both languages
- `usesLanguageCorrection = false` — stops Vision rewriting order numbers and IBANs into
  dictionary words

Verified with `QX7-ßtr44-ZZ`, which must survive character-for-character.

## Fixed 22.10.2026 — reported as "sometimes takes longer or blocks my clipboard"

Four defects, all in the original implementation:

1. **Clipboard clobbered on a no-text grab.** `screencapture -c` overwrites the clipboard with
   the image before OCR runs. Bailing out on no-text left the PNG there, destroying whatever
   had been copied. Now snapshots on startup and restores on failure. This was the "blocked
   clipboard".
2. **~2.5s dead time on every success** — the process waited for `Pop.aiff` to finish playing
   after the clipboard was already set. Sound is now detached. A full run is 0.30s.
3. **Race on the clipboard read** — read immediately after `screencapture` exited, with no
   guarantee the write had landed. Now polls the pasteboard change counter, which also
   detects an Esc cancel properly.
4. **Silent failure** — a no-text grab made no sound, indistinguishable from a slow run.
   Now plays `Basso`.

## Open question

**Does the ~16s cold start recur?** Vision's models live in `mediaanalysisd`. Measured once at
15.9s cold against 0.25s warm. Unknown whether that was a one-off language-asset install or a
daily occurrence after the daemon idle-exits.

- If it recurs: add a LaunchAgent calling `snip-ocr --warmup` at login. Deliberately not built
  yet — it is a background job installed on a guess.
- To find out: note when a grab hangs for seconds. If it is the first grab after a reboot or
  after hours of not using it, the daemon is the cause.

## Testing without a human

The interactive grab normally needs someone to drag a box. This hook replaces the capture
arguments so the real snapshot → capture → restore path runs non-interactively:

```bash
printf 'SENTINEL' | pbcopy
SCREEN_OCR_CAPTURE_ARGS="-R 0,0,8,8 -c -x" ./snip-ocr
pbpaste   # must still be SENTINEL — proves the restore works
```

`--clipboard` is weaker: it OCRs an image already on the clipboard, so it cannot exercise the
snapshot ordering. That gap is what hid defect 1 originally.

## Out of scope, settled

Table-to-spreadsheet reconstruction, translation, keeping screenshot files, snippet history.
Recognised text goes to the clipboard verbatim — no trimming, no line joining, no cleanup.
