import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

extension EditorController {
    func showAIAnimator(unitName: String?) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let targets = workspace.frame.units.filter { unitName == nil || $0.name == unitName }
            guard !targets.isEmpty else { message("ИИ-аниматор", "Сначала добавьте предмет."); return }
            guard targets.count <= 8, targets.reduce(0, { $0 + $1.joints.count }) <= 100 else {
                message("ИИ-аниматор", "Для этой сцены выберите один предмет."); return
            }
            let alert = UIAlertController(title: "ИИ-аниматор · эксперимент",
                                          message: "Опишите движение. Новые кадры появятся после текущего.",
                                          preferredStyle: .alert)
            alert.addTextField { $0.placeholder = "Например: пригнись, прыгни и мягко приземлись" }
            alert.addAction(UIAlertAction(title: "Создать", style: .default) { [weak self, weak alert] _ in
                let prompt = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !prompt.isEmpty else { return }
                self?.generateMotion(prompt: String(prompt.prefix(600)), targets: targets)
            })
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            present(alert, animated: true)
            return
        }
        #endif
        message("ИИ-аниматор недоступен", "Для этого режима нужна iOS 26 или новее.")
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
private struct MotionResponse {
    @Guide(description: "Motion rows, one per subject per pose, using the numeric syntax from the instructions")
    var rows: [String]
}

private struct MotionPlan { var poses: [MotionBeat] }
private struct MotionBeat { var seconds: Double; var subjects: [MotionSubject] }
private struct MotionSubject { var index: Int; var dx: Double; var dy: Double; var bends: [MotionBend] }
private struct MotionBend { var joint: Int; var degrees: Double }

private enum MotionGenerationError: LocalizedError {
    case modelUnavailable, noUsablePoses
    var errorDescription: String? {
        switch self {
        case .modelUnavailable: return "Системная модель Apple Intelligence недоступна."
        case .noUsablePoses: return "Модель не вернула пригодные позы для этого скелета."
        }
    }
}

@available(iOS 26.0, *)
private extension EditorController {
    func generateMotion(prompt: String, targets: [SceneUnit]) {
        let original = workspace.document, index = workspace.index, frame = workspace.frame
        let progress = UIAlertController(title: "Создаю движение…", message: nil, preferredStyle: .alert)
        let task = Task { @MainActor [weak self, weak progress] in
            guard let self else { return }
            do {
                let frames: [SceneFrame]
                var fallbackReason: String?
                do {
                    if let grounded = self.groundedFrames(prompt: prompt, targets: targets, frame: frame, document: original) {
                        frames = grounded
                    } else {
                        frames = try await self.generateModelFrames(prompt: prompt, targets: targets, frame: frame, document: original)
                    }
                } catch {
                    try Task.checkCancellation()
                    fallbackReason = error.localizedDescription
                    let plan = self.fallbackMotion(prompt, targets: targets)
                    frames = try self.motionFrames(plan, frame: frame, targets: targets, document: original)
                }
                guard self.workspace.document == original, self.workspace.index == index else {
                    throw SceneReadError.invalidScene
                }
                self.workspace.checkpoint()
                self.workspace.document.frames.insert(contentsOf: frames, at: index + 1)
                self.workspace.notify()
                progress?.dismiss(animated: true) { [weak self] in
                    if let fallbackReason {
                        self?.message("Созданы резервные кадры", fallbackReason)
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                progress?.dismiss(animated: true) { [weak self] in
                    self?.message("Не удалось создать движение", "Проверьте, что выбранный предмет может двигаться и сцена не изменилась во время генерации.")
                }
            }
        }
        progress.addAction(UIAlertAction(title: "Отмена", style: .cancel) { _ in task.cancel() })
        present(progress, animated: true)
    }

    func groundedFrames(prompt: String, targets: [SceneUnit], frame: SceneFrame, document: SceneDocument) -> [SceneFrame]? {
        let text = prompt.lowercased()
        func contains(_ words: [String]) -> Bool { words.contains { text.contains($0) } }
        let action: GroundedMotion.Action
        let duration: Double
        if contains(["прыг", "прыж", "jump", "hop"]) { action = .jump; duration = 1.45 }
        else if contains(["бег", "беж", "беги", "run", "sprint"]) { action = .run; duration = 1.35 }
        else if contains(["идти", "идёт", "иди", "шаг", "ходьб", "walk", "step"]) { action = .walk; duration = 2.1 }
        else if contains(["прися", "пригн", "присед", "crouch", "squat"]) { action = .crouch; duration = 1.25 }
        else { return nil }
        let rigs = targets.compactMap { unit -> (String, GroundedMotion)? in
            guard FrameManipulation.attachment(unit) == nil, let rig = GroundedMotion(unit: unit) else { return nil }
            return (unit.name, rig)
        }
        let highest = document.frames.map(\.id).max() ?? 0
        let count = max(1, Int((duration * 60 / Double(max(1, document.interframes + 1))).rounded()))
        guard !rigs.isEmpty, highest <= Int.max - count else { return nil }
        let direction = contains(["влев", "налев", "left"]) ? -1.0 : 1.0
        return (1...count).map { tick in
            var output = frame
            output.id = highest + tick
            for (name, rig) in rigs {
                guard let index = output.units.firstIndex(where: { $0.name == name }) else { continue }
                _ = FrameManipulation.pastePose(rig.pose(action, progress: Double(tick) / Double(count), direction: direction),
                                                into: &output, unitIndex: index)
            }
            return output
        }
    }

    func generateModelFrames(prompt: String, targets: [SceneUnit], frame: SceneFrame, document: SceneDocument) async throws -> [SceneFrame] {
        guard SystemLanguageModel.default.isAvailable else { throw MotionGenerationError.modelUnavailable }
        let rigs = targets.enumerated().map { index, unit in
            let title = workspace.artworkByName[UnitIdentity.baseName(unit.name)]?.displayTitle ?? unit.name
            let bones = unit.joints.map { joint in
                let label = joint.attributes["name"] ?? ""
                let x = (joint.x / document.width * 100).rounded()
                let y = (joint.y / document.height * 100).rounded()
                return "\(joint.id)/\(joint.parent ?? -1)/\(x)/\(y)/\(label)"
            }.joined(separator: " ")
            return "\(index) \(title): \(bones)"
        }.joined(separator: "\n")
        let instructions = """
            You animate editable 2D skeletons. Understand the action in any language and output numbers only.
            Each row is: seconds subject xPercent yPercent joint angleDegrees joint angleDegrees
            Example: 0.4 0 2 -5 7 28 9 -16
            The first four numbers are required. Include up to three joint-angle pairs per subject.
            A rig entry is joint/parent/x/y/label; parent -1 marks a root. Never bend roots.
            Offsets and bends are relative to the initial pose, not cumulative. Positive Y is down.
            Generate 4 to 6 poses from 0.15 to 4 seconds, using the given subject and joint IDs.
            Use anticipation, weight transfer, unequal timing and follow-through. Leave unrelated subjects still.
            """
        let request = "Action: \(prompt)\nRigs:\n\(rigs)"
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: request, generating: MotionResponse.self)
            let plan = parseMotionRows(response.content.rows, targets: targets)
            return try motionFrames(plan, frame: frame, targets: targets, document: document)
        } catch {
            try Task.checkCancellation()
            // Retry with a fresh session. Plain numeric output also works when
            // constrained decoding cannot complete the structured response.
            let retry = LanguageModelSession(instructions: instructions + "\nReturn one numeric row per line.")
            let response = try await retry.respond(to: request)
            let plan = parseMotionRows(response.content.components(separatedBy: .newlines), targets: targets)
            return try motionFrames(plan, frame: frame, targets: targets, document: document)
        }
    }

    func parseMotionRows(_ rows: [String], targets: [SceneUnit]) -> MotionPlan {
        var beats: [Double: [Int: MotionSubject]] = [:]
        for row in rows.prefix(64) {
            let values = row.split { $0.isWhitespace || $0 == "," || $0 == ";" }.map { Double($0) }
            guard values.count >= 4, let seconds = values[0], seconds.isFinite, seconds > 0, seconds <= 4,
                  let subject = values[1].flatMap(Int.init(exactly:)), targets.indices.contains(subject),
                  let x = values[2], x.isFinite, let y = values[3], y.isFinite else { continue }
            var bends: [MotionBend] = []
            for offset in stride(from: 4, to: min(values.count - 1, 10), by: 2) {
                guard let id = values[offset].flatMap(Int.init(exactly:)),
                      targets[subject].joints.contains(where: { $0.id == id && $0.parent != nil }),
                      let angle = values[offset + 1], angle.isFinite else { continue }
                bends.append(MotionBend(joint: id, degrees: angle))
            }
            beats[seconds, default: [:]][subject] = MotionSubject(index: subject, dx: x / 100, dy: y / 100, bends: bends)
        }
        return MotionPlan(poses: beats.keys.sorted().map { seconds in
            MotionBeat(seconds: seconds, subjects: beats[seconds, default: [:]].values.sorted { $0.index < $1.index })
        })
    }

    func fallbackMotion(_ prompt: String, targets: [SceneUnit]) -> MotionPlan {
        let text = prompt.lowercased()
        func matches(_ words: [String]) -> Bool { words.contains { text.contains($0) } }
        let direction = matches(["влев", "налев", "left"]) ? -1.0 : 1.0
        let jump = matches(["прыг", "прыж", "jump", "hop"])
        let walk = matches(["идти", "идёт", "иди", "шаг", "бег", "беж", "walk", "run"])
        let wave = matches(["маш", "мах", "привет", "wave"])
        let crouch = matches(["прися", "пригн", "присед", "crouch", "squat"])
        let offsets: [(Double, Double, Double, Double)]
        if jump {
            offsets = [(0.22, 0, 0.04, -22), (0.42, 0.02, -0.08, 12), (0.65, 0.04, -0.19, 25),
                       (0.88, 0.06, -0.08, 12), (1.04, 0.07, 0.03, -22), (1.28, 0.07, 0, 0)]
        } else if walk {
            offsets = [(0.20, 0.02, -0.012, 21), (0.42, 0.05, 0.008, -23), (0.64, 0.08, -0.012, 23),
                       (0.86, 0.11, 0.008, -19), (1.10, 0.14, 0, 0)]
        } else if wave {
            offsets = [(0.20, 0, 0, 34), (0.37, 0, 0, 69), (0.55, 0, 0, 44),
                       (0.73, 0, 0, 66), (1.08, 0, 0, 0)]
        } else if crouch {
            offsets = [(0.20, 0, 0.025, -12), (0.48, 0, 0.10, -33),
                       (0.70, 0, 0.10, -33), (1.12, 0, 0, 0)]
        } else {
            offsets = [(0.19, -0.012, 0.015, -12), (0.42, 0.025, -0.02, 22),
                       (0.67, 0.04, 0.006, -7), (1.02, 0.04, 0, 0)]
        }
        return MotionPlan(poses: offsets.map { time, x, y, angle in
            MotionBeat(seconds: time, subjects: targets.enumerated().map { index, unit in
                let root = unit.joints.first(where: { $0.parent == nil })
                let movable = unit.joints.filter { $0.parent != nil && $0.attributes["fixed"] != "true" }
                let candidates = movable.sorted {
                    if wave { return abs($0.x - (root?.x ?? 0)) > abs($1.x - (root?.x ?? 0)) }
                    return $0.y > $1.y
                }
                let bends = candidates.prefix(wave ? 1 : 4).enumerated().map { offset, joint in
                    let side = joint.x < (root?.x ?? 0) ? -1.0 : 1.0
                    return MotionBend(joint: joint.id, degrees: angle * side * (offset < 2 ? 1 : 0.45) * direction)
                }
                let moveX = movable.isEmpty && wave ? 0.025 * sin(time * 9) : x
                return MotionSubject(index: index, dx: moveX * direction, dy: y, bends: bends)
            })
        })
    }

    func motionFrames(_ plan: MotionPlan, frame: SceneFrame, targets: [SceneUnit], document: SceneDocument) throws -> [SceneFrame] {
        let rate = 60.0 / Double(max(1, document.interframes + 1))
        var anchors: [(tick: Int, frame: SceneFrame)] = [(0, frame)]
        var previousTime = 0.0
        for beat in plan.poses.filter({ $0.seconds.isFinite }).sorted(by: { $0.seconds < $1.seconds }).prefix(9) {
            guard beat.seconds.isFinite, beat.seconds > previousTime, beat.seconds <= 4 else { continue }
            previousTime = beat.seconds
            let tick = max(1, Int((beat.seconds * rate).rounded()))
            guard tick > (anchors.last?.tick ?? 0) else { continue }
            var pose = frame
            for subject in beat.subjects.prefix(targets.count) {
                guard targets.indices.contains(subject.index), subject.dx.isFinite, subject.dy.isFinite,
                      let index = pose.units.firstIndex(where: { $0.name == targets[subject.index].name }) else { continue }
                let unit = try directedPose(targets[subject.index], subject: subject, width: document.width, height: document.height)
                _ = FrameManipulation.pastePose(unit, into: &pose, unitIndex: index)
            }
            anchors.append((tick, pose))
        }
        guard anchors.count >= 2, anchors.dropFirst().contains(where: { $0.frame != frame }) else {
            throw MotionGenerationError.noUsablePoses
        }
        let highestID = document.frames.map(\.id).max() ?? 0
        guard highestID < Int.max - 241 else { throw SceneReadError.resourceLimit }
        var frames: [SceneFrame] = []
        for (left, right) in zip(anchors, anchors.dropFirst()) {
            for tick in (left.tick + 1)...right.tick {
                let fraction = Double(tick - left.tick) / Double(right.tick - left.tick)
                // Preserve more velocity through moving poses while easing into each beat.
                let t = 0.55 * fraction + 0.45 * fraction * fraction * (3 - 2 * fraction)
                var sample = left.frame
                for index in sample.units.indices {
                    let before = left.frame.units[index]
                    let after = right.frame.units[index]
                    if before != after,
                       let pose = try? PoseInterpolation.between(before, after, progress: t) {
                        _ = FrameManipulation.pastePose(pose, into: &sample, unitIndex: index)
                    }
                }
                sample.id = highestID + tick
                frames.append(sample)
            }
        }
        return frames
    }

    func directedPose(_ source: SceneUnit, subject: MotionSubject, width: Double, height: Double) throws -> SceneUnit {
        let original = Dictionary(source.joints.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let bends = Dictionary(subject.bends.prefix(100).filter { $0.degrees.isFinite }.map {
            ($0.joint, min(160, max(-160, $0.degrees)) * .pi / 180)
        }, uniquingKeysWith: { _, last in last })
        let dx = min(1, max(-1, subject.dx)) * width, dy = min(1, max(-1, subject.dy)) * height
        var cache: [Int: (Joint, Double)] = [:]
        var visiting = Set<Int>()
        func resolve(_ joint: Joint) throws -> (Joint, Double) {
            if let value = cache[joint.id] { return value }
            guard visiting.insert(joint.id).inserted else { throw PoseError.cyclicSkeleton }
            var point = joint
            var rotation = 0.0
            if let parentID = joint.parent, let parent = original[parentID] {
                let (anchor, parentRotation) = try resolve(parent)
                rotation = parentRotation + (bends[joint.id] ?? 0)
                let x = joint.x - parent.x, y = joint.y - parent.y
                point.x = anchor.x + x * cos(rotation) - y * sin(rotation)
                point.y = anchor.y + x * sin(rotation) + y * cos(rotation)
            } else {
                point.x += dx
                point.y += dy
            }
            visiting.remove(joint.id)
            cache[joint.id] = (point, rotation)
            return (point, rotation)
        }
        var output = source
        output.joints = try source.joints.map { try resolve($0).0 }
        return output
    }
}
#endif
