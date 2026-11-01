import Foundation
import AVFoundation
import AppKit
let url=URL(fileURLWithPath:"/private/tmp/pond-review-calibration-a/continuous.mp4")
let asset=AVURLAsset(url:url)
let duration=CMTimeGetSeconds(asset.duration)
print("duration_seconds \(duration)")
let gen=AVAssetImageGenerator(asset:asset)
gen.appliesPreferredTrackTransform=true
gen.requestedTimeToleranceBefore=CMTime.zero
gen.requestedTimeToleranceAfter=CMTime.zero
for seconds in stride(from:0.0,to:duration,by:2.0) {
 do {
  var actual=CMTime.zero
  let img=try gen.copyCGImage(at:CMTime(seconds:seconds,preferredTimescale:600),actualTime:&actual)
  let rep=NSBitmapImageRep(cgImage:img)
  let data=rep.representation(using:.png,properties:[:])!
  let path=String(format:"/private/tmp/pond-first-look-9611660/post-review/calibration-frames/frame-%05.1f.png",seconds)
  try data.write(to:URL(fileURLWithPath:path))
  print("frame requested=\(seconds) actual=\(CMTimeGetSeconds(actual)) width=\(img.width) height=\(img.height)")
 } catch { print(error) }
}
