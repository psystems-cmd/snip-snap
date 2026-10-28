// screen-ocr: region capture -> Vision OCR (de+en, literal) -> clipboard text.
//
// Flags:
//   --clipboard  skip capture; OCR whatever image is already on the clipboard
//   --warmup     load the Vision language models and exit; touches nothing

import AppKit
import Vision

let pb = NSPasteboard.general
let args = CommandLine.arguments

// Fire and forget. Waiting on afplay added ~2.5s to every successful grab, so the
// sound is backgrounded by sh, which exits immediately and leaves afplay detached.
func ping(_ name: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/sh")
    p.arguments = ["-c", "afplay /System/Library/Sounds/\(name).aiff >/dev/null 2>&1 &"]
    try? p.run()
    p.waitUntilExit()
}

func recognise(_ cg: CGImage) -> [String] {
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.recognitionLanguages = ["de-DE", "en-US"]   // both, in a single pass
    req.usesLanguageCorrection = false              // literal characters; protects codes and IBANs
    guard (try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])) != nil else {
        return []
    }
    return (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }
}

// Vision's language models live in mediaanalysisd, which idle-exits. The first grab
// afterwards pays ~16s to reload de-DE and en-US. This loads them without touching
// the clipboard, so a login agent can absorb that cost in the background.
if args.contains("--warmup") {
    let size = NSSize(width: 160, height: 48)
    let img = NSImage(size: size)
    img.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: size).fill()
    NSAttributedString(string: "Warmlauf", attributes: [
        .font: NSFont.systemFont(ofSize: 22),
        .foregroundColor: NSColor.black,
    ]).draw(at: NSPoint(x: 8, y: 10))
    img.unlockFocus()
    if let tiff = img.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let cg = rep.cgImage {
        _ = recognise(cg)
    }
    exit(0)
}

// screencapture -c overwrites the clipboard before we know whether OCR will succeed.
// Snapshotting first is what lets a failed grab put the original contents back,
// instead of leaving a PNG where the text used to be.
typealias Snapshot = [[NSPasteboard.PasteboardType: Data]]

func snapshotClipboard() -> Snapshot {
    (pb.pasteboardItems ?? []).map { item in
        var fields: [NSPasteboard.PasteboardType: Data] = [:]
        for type in item.types {
            if let value = item.data(forType: type) { fields[type] = value }
        }
        return fields
    }
}

func restoreClipboard(_ snap: Snapshot) {
    pb.clearContents()
    let items: [NSPasteboardItem] = snap.map { fields in
        let item = NSPasteboardItem()
        for (type, value) in fields { item.setData(value, forType: type) }
        return item
    }
    if !items.isEmpty { pb.writeObjects(items) }
}

let original = snapshotClipboard()
let changeCountBefore = pb.changeCount

if !args.contains("--clipboard") {
    // -i interactive crosshair, -c to the clipboard (nothing touches disk), -x no shutter.
    // Overridable so the real snapshot -> capture -> restore path can be tested
    // non-interactively, e.g. SCREEN_OCR_CAPTURE_ARGS="-R 0,0,8,8 -c -x".
    let captureArgs = ProcessInfo.processInfo.environment["SCREEN_OCR_CAPTURE_ARGS"]
        .map { $0.split(separator: " ").map(String.init) } ?? ["-i", "-c", "-x"]
    let capture = Process()
    capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    capture.arguments = captureArgs
    try capture.run()
    capture.waitUntilExit()

    // screencapture can exit fractionally before its clipboard write becomes visible.
    // Polling changeCount closes that race, and doubles as cancel detection: Esc
    // writes nothing, so the count never moves.
    let deadline = Date().addingTimeInterval(2)
    while pb.changeCount == changeCountBefore && Date() < deadline {
        usleep(20_000)
    }
    guard pb.changeCount != changeCountBefore else { exit(0) }  // cancelled, clipboard untouched
}

guard let data = pb.data(forType: .png) ?? pb.data(forType: .tiff),
      let rep = NSBitmapImageRep(data: data),
      let cg = rep.cgImage else {
    restoreClipboard(original)
    exit(0)
}

let lines = recognise(cg)

// No text found. Put back what the capture overwrote and say so audibly — silence
// here is what made this failure impossible to tell apart from a slow run.
guard !lines.isEmpty else {
    restoreClipboard(original)
    ping("Basso")
    exit(0)
}

pb.clearContents()
// Verbatim, per AD-7: no trimming, no line joining, no cleanup heuristics.
pb.setString(lines.joined(separator: "\n"), forType: .string)
ping("Pop")
