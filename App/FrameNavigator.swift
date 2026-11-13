import UIKit

/// SeekFramesBar's default bitmap navigation: 12pt spacing, 5pt fixed pad,
/// windowed frame indices, and selection at the nearest marker within 10pt.
final class FrameNavigator:UIView {
    var count=1 {didSet{if oldValue != count {setNeedsDisplay();updateAccessibility()}}}
    var current=0 {didSet{if oldValue != current {setNeedsDisplay();updateAccessibility()}}}
    var seek:((Int)->Void)?
    var selectRange: (() -> Void)?
    var selectedRange: ClosedRange<Int>? { didSet { if oldValue != selectedRange { setNeedsDisplay() } } }
    func pageTarget(_ direction: Int) -> Int {
        min(max(0, count - 1), max(0, first + direction * capacity))
    }
    private let normal=UIImage(contentsOfFile:Bundle.main.resourceURL!.appendingPathComponent("Content/Icons/frame_stick_notsel.png").path)
    private let active=UIImage(contentsOfFile:Bundle.main.resourceURL!.appendingPathComponent("Content/Icons/frame_stick_sel.png").path)
    private var capacity:Int{max(1,Int((bounds.height-10)/12))}
    private var first:Int{current/capacity*capacity}
    private var end:Int{min(count,first+capacity)}
    override init(frame:CGRect){super.init(frame:frame);isOpaque=false;isAccessibilityElement=true;accessibilityIdentifier="FrameNavigator";accessibilityLabel="Кадры";accessibilityTraits = .adjustable;updateAccessibility()}
    required init?(coder:NSCoder){fatalError()}
    private func updateAccessibility(){accessibilityValue="\(current+1) / \(count)"}
    private func y(_ index:Int)->CGFloat{5+CGFloat(index%capacity)*12+6.5}
    override func draw(_ rect:CGRect) {
        guard count>0 else{return}
        for index in first..<end {
            let selected = index == current || selectedRange?.contains(index) == true
            let bitmap = selected ? active : normal
            bitmap?.draw(in:CGRect(x:(bounds.width-13)/2,y:y(index),width:13,height:13))
        }
        let font=UIFont(name:"Roboto-Bold",size:14) ?? .boldSystemFont(ofSize:14)
        (String(current+1) as NSString).draw(at:CGPoint(x:5,y:bounds.height/2-font.ascender),withAttributes:[.font:font,.foregroundColor:UIColor.black])
        let small=UIFont(name:"Roboto-Bold",size:10) ?? .boldSystemFont(ofSize:10)
        let attributes:[NSAttributedString.Key:Any]=[.font:small,.foregroundColor:UIColor.black.withAlphaComponent(0.5)]
        (String(first+1) as NSString).draw(at:CGPoint(x:10,y:10-small.ascender),withAttributes:attributes)
        (String(end) as NSString).draw(at:CGPoint(x:10,y:bounds.height-10-small.ascender),withAttributes:attributes)
    }
    override func layoutSubviews(){super.layoutSubviews();setNeedsDisplay()}
    override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent?) {
        guard let touch = touches.first else { return }
        if touch.tapCount == 2, let selectRange {
            selectRange()
            return
        }
        guard count>0,let nearest=(first..<end).min(by:{abs(y($0)-touch.location(in:self).y)<abs(y($1)-touch.location(in:self).y)}),abs(y(nearest)-touch.location(in:self).y)<=10 else{return}
        seek?(nearest)
    }
    override func accessibilityIncrement(){seek?(min(count-1,current+1))}
    override func accessibilityDecrement(){seek?(max(0,current-1))}
}
