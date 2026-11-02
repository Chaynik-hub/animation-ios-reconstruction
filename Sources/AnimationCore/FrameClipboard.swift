import Foundation

/// Scene.pasteFrames inserts before frame zero, and after other current frames.
/// It retains the current numerical index and clones frames with fresh IDs.
public enum FrameClipboard {
    @discardableResult
    public static func paste(_ frames: [SceneFrame], into document: inout SceneDocument, currentIndex: Int) -> Range<Int>? {
        guard !frames.isEmpty, document.frames.indices.contains(currentIndex) else { return nil }
        let insertion = currentIndex == 0 ? 0 : currentIndex + 1
        let maximum = document.frames.map(\.id).max() ?? -1
        guard maximum <= Int.max - frames.count else { return nil }
        let copies = frames.enumerated().map { offset, frame -> SceneFrame in
            var copy = frame
            copy.id = maximum + offset + 1
            return copy
        }
        document.frames.insert(contentsOf: copies, at: insertion)
        return insertion..<(insertion + copies.count)
    }
}
