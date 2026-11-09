// On-device-style OCR for the form bench: Apple Vision text lines with
// pixel boxes (top-left origin), like the app's ML Kit lines.
// Usage: swift ocr.swift page.jpg  -> JSON [{"text":..., "box":[x0,y0,x1,y1]}]
import Foundation
import Vision
import AppKit

let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let image = NSImage(contentsOf: url),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
  FileHandle.standardError.write("can't open image\n".data(using: .utf8)!)
  exit(1)
}
let w = Double(cg.width), h = Double(cg.height)
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = false
try VNImageRequestHandler(cgImage: cg).perform([request])
var out: [[String: Any]] = []
for obs in request.results ?? [] {
  guard let text = obs.topCandidates(1).first?.string else { continue }
  let b = obs.boundingBox
  out.append([
    "text": text,
    "box": [Int(b.minX * w), Int((1 - b.maxY) * h), Int(b.maxX * w), Int((1 - b.minY) * h)],
  ])
}
let data = try JSONSerialization.data(withJSONObject: out)
FileHandle.standardOutput.write(data)
