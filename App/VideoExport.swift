import UIKit
import AVFoundation

extension EditorController {
    func exportVideo() {
        stop()
        let width = min(AnimationSettings.bool("high_video_quality_2") ? 1920 : 1280,Int(workspace.document.width)/2*2)
        let height = max(2,Int(Double(width)*workspace.document.height/workspace.document.width)/2*2)
        guard width>=2,height<=4096 else {message("Ошибка экспорта","Недопустимый размер видео");return}
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".mp4")
        do {
            let writer=try AVAssetWriter(outputURL:url,fileType:.mp4)
            var compression:[String:Any] = [AVVideoAverageBitRateKey: width*height*(AnimationSettings.bool("high_video_quality_2") ? 12 : 6)]
            if AnimationSettings.bool("compatibility_mode") {compression[AVVideoProfileLevelKey]=AVVideoProfileLevelH264BaselineAutoLevel}
            let input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:width,AVVideoHeightKey:height,AVVideoCompressionPropertiesKey:compression])
            let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,kCVPixelBufferWidthKey as String:width,kCVPixelBufferHeightKey as String:height,kCVPixelBufferCGImageCompatibilityKey as String:true,kCVPixelBufferCGBitmapContextCompatibilityKey as String:true])
            guard writer.canAdd(input) else {throw SceneReadError.invalidScene};writer.add(input)
            guard writer.startWriting() else {throw writer.error ?? SceneReadError.invalidScene}
            writer.startSession(atSourceTime:.zero)
            let count=workspace.document.frames.count*workspace.document.ticksPerKeyframe
            let originalStart=startFrame;startFrame=0
            var frameIndex=0
            view.isUserInteractionEnabled=false
            let indicator=UIActivityIndicatorView(style:.large);indicator.center=view.center;indicator.startAnimating();view.addSubview(indicator)
            input.requestMediaDataWhenReady(on:.main){[weak self] in
                guard let self else{input.markAsFinished();writer.cancelWriting();return}
                var failure:Error?
                while input.isReadyForMoreMediaData && frameIndex<count {
                    autoreleasepool {
                        var buffer:CVPixelBuffer?
                        guard let pool=adaptor.pixelBufferPool,CVPixelBufferPoolCreatePixelBuffer(nil,pool,&buffer)==kCVReturnSuccess,let buffer else{failure=SceneReadError.resourceLimit;return}
                        self.canvas.displayed=self.frameAt(Double(frameIndex)/60)
                        let image=self.canvas.snapshot(size:CGSize(width:width,height:height))
                        CVPixelBufferLockBaseAddress(buffer,[])
                        if let context=CGContext(data:CVPixelBufferGetBaseAddress(buffer),width:width,height:height,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(buffer),space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipFirst.rawValue),let cg=image.cgImage {
                            context.draw(cg,in:CGRect(x:0,y:0,width:width,height:height))
                        } else {failure=SceneReadError.resourceLimit}
                        CVPixelBufferUnlockBaseAddress(buffer,[])
                        if !adaptor.append(buffer,withPresentationTime:CMTime(value:Int64(frameIndex),timescale:60)){failure=writer.error ?? SceneReadError.invalidScene}
                        frameIndex+=1
                    }
                    if failure != nil{break}
                }
                if frameIndex==count || failure != nil || writer.status == .failed {
                    input.markAsFinished()
                    self.startFrame=originalStart;self.canvas.displayed=nil;self.update()
                    let finish:()->Void = {self.view.isUserInteractionEnabled=true;indicator.removeFromSuperview()}
                    if let failure {writer.cancelWriting();finish();self.message("Ошибка экспорта",String(describing:failure));return}
                    writer.finishWriting {DispatchQueue.main.async{finish();if writer.status == .completed {self.mixAudio(video:url)}else{self.message("Ошибка экспорта",writer.error?.localizedDescription ?? "MP4 не записан")}}}
                }
            }
        } catch {message("Ошибка экспорта",error.localizedDescription)}
    }
    private func mixAudio(video:URL) {
        guard let sound=audio?.url else{share(video);return}
        let videoAsset=AVURLAsset(url:video),soundAsset=AVURLAsset(url:sound)
        let composition=AVMutableComposition()
        do {
            guard let videoTrack=videoAsset.tracks(withMediaType:.video).first,let output=composition.addMutableTrack(withMediaType:.video,preferredTrackID:kCMPersistentTrackID_Invalid) else{throw SceneReadError.invalidScene}
            try output.insertTimeRange(CMTimeRange(start:.zero,duration:videoAsset.duration),of:videoTrack,at:.zero)
            if let audioTrack=soundAsset.tracks(withMediaType:.audio).first,let outputAudio=composition.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid){try outputAudio.insertTimeRange(CMTimeRange(start:.zero,duration:CMTimeMinimum(videoAsset.duration,soundAsset.duration)),of:audioTrack,at:.zero)}
            guard let session=AVAssetExportSession(asset:composition,presetName:AVAssetExportPresetHighestQuality) else{throw SceneReadError.invalidScene}
            let url=video.deletingLastPathComponent().appendingPathComponent(UUID().uuidString+".mp4");session.outputURL=url;session.outputFileType = .mp4
            session.exportAsynchronously{DispatchQueue.main.async{if session.status == .completed{self.share(url)}else{self.message("Ошибка звуковой дорожки",session.error?.localizedDescription ?? "Не удалось добавить звук")}}}
        } catch {message("Ошибка звуковой дорожки",error.localizedDescription)}
    }
}
