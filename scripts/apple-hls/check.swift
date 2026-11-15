// Plays each "label=url" argument in AVPlayer and reports whether a video
// frame was decoded. Labels starting with "must" fail the run without one.
import AVFoundation
import Foundation

func check(_ url: URL, fromStart: Bool) -> (Bool, String) {
  let item = AVPlayerItem(url: url)
  let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
  ])
  item.add(output)
  let player = AVPlayer(playerItem: item)
  player.isMuted = true
  player.play()
  let deadline = Date().addingTimeInterval(30)
  var frame = false, requestedStart = false, seeked = !fromStart
  while Date() < deadline && !frame && item.status != .failed {
    RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    // Match IosPlayerBridge: EVENT seeks must wait for readiness.
    if fromStart && !requestedStart && item.status == .readyToPlay {
      requestedStart = true
      player.seek(to: .zero) { finished in seeked = finished }
    }
    if !seeked { continue }
    let time = item.currentTime()
    if output.hasNewPixelBuffer(forItemTime: time),
      output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) != nil
    {
      frame = true
    }
  }
  // Let audio run a little, so "audio only" is visible in the report.
  RunLoop.main.run(until: Date().addingTimeInterval(2))
  let kinds = item.tracks.compactMap { $0.assetTrack?.mediaType.rawValue }
  let report =
    "status=\(item.status.rawValue) size=\(item.presentationSize) "
    + "time=\(item.currentTime().seconds) tracks=\(kinds) "
    + "error=\(item.error?.localizedDescription ?? "none")"
  let position = item.currentTime().seconds
  let atBeginning = position.isFinite && position >= 0 && position < 5
  player.pause()
  player.replaceCurrentItem(with: nil)
  return (frame && (!fromStart || atBeginning), report)
}

var failed = false
for argument in CommandLine.arguments.dropFirst() {
  let parts = argument.split(separator: "=", maxSplits: 1).map(String.init)
  guard parts.count == 2, let url = URL(string: parts[1]) else { continue }
  let (frame, report) = check(url, fromStart: parts[0].hasPrefix("must-start-"))
  print("\(parts[0]): video=\(frame) \(report)")
  if parts[0].hasPrefix("must") && !frame { failed = true }
}
exit(failed ? 1 : 0)
