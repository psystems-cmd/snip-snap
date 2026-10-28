# screen-ocr

Turns text that is visually present but unselectable into clipboard text.
Press the hotkey, drag a region, paste. Built for PDFs, photos and website images.

## What it does

1. `screencapture -i -c -x` — Apple's native crosshair selection, result to the clipboard as
   an image, nothing written to disk, no shutter sound
2. Vision OCR — German **and** English in a single pass, language correction **off**
3. The recognised characters replace the image on the clipboard, verbatim
4. A short `Pop` sound confirms the text is ready

## Sounds

| Sound | Meaning |
|-------|---------|
| `Pop` | text recognised and on the clipboard |
| `Basso` | grab worked but no text was found — your previous clipboard contents were put back |
| silence | you cancelled with Esc; nothing happened |

The `Basso` case used to be silent, which made a failed grab indistinguishable from a slow one.

## Clipboard safety

`screencapture -c` overwrites the clipboard with the captured image *before* anything knows
whether OCR will succeed. The tool therefore snapshots the clipboard on startup and restores
it if the grab yields no text. Without that, a failed grab left a PNG sitting where your text
used to be — which looks exactly like "the clipboard is blocked".

## Files

| File | Purpose |
|------|---------|
| `snip-ocr.swift` | The whole tool, ~45 lines. Source of truth |
| `snip-ocr` | Compiled binary |
| `build.sh` | Rebuilds the binary after editing the source |
| `screen-ocr.sh` | Raycast script-command wrapper, used only to attach the hotkey |
| `tasks/plan.md` | Architecture decisions and risk register |
| `tasks/todo.md` | Task list and verification status |

## Rebuild from source

```bash
./build.sh
```

Needs Xcode Command Line Tools, already present on this machine. No other dependencies —
Vision ships with macOS.

## Hotkey

Bound to `Cmd+Shift+ß` via **Raycast** (Settings > Extensions > Scripts). The binary itself has
no hotkey knowledge, so the binding can be moved or changed without touching the tool.

## Permissions

Needs **Screen Recording** (System Settings > Privacy & Security > Screen Recording), granted
to whichever app launches it — Raycast if bound there. Anything that reads screen pixels
requires this; it is prompted once on first use.

## Settings worth knowing

Both live in `snip-ocr.swift` and are deliberate, not defaults:

- `recognitionLanguages = ["de-DE", "en-US"]` — one pass, both languages. Left at the default
  `en-US`, German umlauts and ß get misread.
- `usesLanguageCorrection = false` — stops Vision snapping recognised text toward dictionary
  words. Essential for order numbers, IBANs, part codes and URL fragments, which otherwise get
  "corrected" into plausible-looking wrong values.

## Flags

| Flag | Purpose |
|------|---------|
| *(none)* | normal use: interactive grab |
| `--clipboard` | skip capture, OCR whatever image is already on the clipboard |
| `--warmup` | load the Vision language models and exit; touches nothing |

`SCREEN_OCR_CAPTURE_ARGS` overrides the `screencapture` arguments, so the real
snapshot/capture/restore path can be tested without a human dragging a box:

```bash
SCREEN_OCR_CAPTURE_ARGS="-R 0,0,8,8 -c -x" ./snip-ocr
```

## The occasional slow grab

Vision's language models live in `mediaanalysisd`, a system daemon. When they are not
resident, the first grab pays for loading `de-DE` and `en-US` — measured at **15.9s** once,
against **0.25s** warm. Nothing in this tool can avoid that; it is the OS loading assets.

`./snip-ocr --warmup` pays that cost without touching the clipboard. If the delay turns out to
recur daily, a login agent calling `--warmup` would absorb it in the background — not set up,
because it is unclear yet whether the cold start recurs or was a one-off asset install.

Separately, every successful grab used to block for ~2.5s waiting for the confirmation sound
to finish playing. The sound is now detached, so the clipboard is ready immediately.

## Accuracy note

OCR quality tracks source resolution. If a grab comes back wrong, zoom the PDF or image in
before capturing — it makes a far bigger difference than anything adjustable in the code.
