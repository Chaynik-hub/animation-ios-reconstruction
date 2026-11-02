import UIKit
import AVFoundation

/// Separate full-screen route, following FullPreviewActivity/simple_preview_fragment.xml.
final class PreviewController:UIViewController {
    let workspace:Workspace
    let audio:AVAudioPlayer?
    lazy var canvas=SceneCanvas(workspace)
    private var link:CADisplayLink?
    private var start=0.0
    private var accumulated=0.0
    private var playing=true
    init(workspace:Workspace,audio:AVAudioPlayer?){self.workspace=workspace;self.audio=audio;super.init(nibName:nil,bundle:nil);modalPresentationStyle = .fullScreen}
    required init?(coder:NSCoder){fatalError()}
    override var prefersStatusBarHidden:Bool{true}
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask{.landscape}
    override func viewDidLoad(){
        super.viewDidLoad();view.backgroundColor=UIColor(white:34/255,alpha:1)
        canvas.frame=view.bounds;canvas.autoresizingMask=[.flexibleWidth,.flexibleHeight];canvas.handles=false;canvas.onion=false;canvas.isUserInteractionEnabled=false;canvas.accessibilityIdentifier="PreviewCanvas";canvas.isAccessibilityElement=true;view.addSubview(canvas)
        view.addGestureRecognizer(UITapGestureRecognizer(target:self,action:#selector(toggle)))
        let back=UIScreenEdgePanGestureRecognizer(target:self,action:#selector(back(_:)));back.edges = .left;view.addGestureRecognizer(back)
        start=CACurrentMediaTime();let link=CADisplayLink(target:self,selector:#selector(tick(_:)));link.preferredFrameRateRange=CAFrameRateRange(minimum:30,maximum:60,preferred:60);link.add(to:.main,forMode:.common);self.link=link;audio?.currentTime=0;audio?.play()
    }
    override func viewWillDisappear(_ animated:Bool){super.viewWillDisappear(animated);link?.invalidate();link=nil;audio?.pause()}
    override func accessibilityPerformEscape()->Bool{dismiss(animated:true);return true}
    @objc private func back(_ gesture:UIScreenEdgePanGestureRecognizer){if gesture.state == .ended && gesture.translation(in:view).x>40{dismiss(animated:true)}}
    @objc private func toggle(){playing.toggle();if playing {start=CACurrentMediaTime();audio?.play()}else{accumulated+=CACurrentMediaTime()-start;audio?.pause()}}
    @objc private func tick(_ sender:CADisplayLink){
        let time=accumulated+(playing ? sender.timestamp-start:0)
        let duration=Double(max(1,workspace.document.interframes+1))/60
        let position=max(0,time/duration),index=Int(position)%workspace.document.frames.count
        var frame=workspace.document.frames[index];let next=workspace.document.frames[(index+1)%workspace.document.frames.count]
        for i in frame.units.indices{if let end=next.units.first(where:{$0.name==frame.units[i].name}),let pose=try? PoseInterpolation.between(frame.units[i],end,progress:position-floor(position)){frame.units[i]=pose}}
        canvas.displayed=frame;canvas.setNeedsDisplay()
    }
}
