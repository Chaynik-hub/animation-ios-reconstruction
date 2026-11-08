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
private struct MotionPlan {
    var poses: [MotionBeat]
}

@available(iOS 26.0, *)
@Generable
private struct MotionBeat {
    @Guide(description: "Absolute time in seconds since the initial pose, between 0.15 and 4")
    var seconds: Double
    var subjects: [MotionSubject]
}

@available(iOS 26.0, *)
@Generable
private struct MotionSubject {
    var index: Int
    @Guide(description: "Horizontal offset as a fraction of scene width from the initial position")
    var dx: Double
    @Guide(description: "Vertical offset as a fraction of scene height, positive is down")
    var dy: Double
    var bends: [MotionBend]
}

@available(iOS 26.0, *)
@Generable
private struct MotionBend {
    var joint: Int
    @Guide(description: "Relative clockwise rotation of the bone ending at this joint, in degrees")
    var degrees: Double
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
                var usedFallback = false
                do {
                    guard SystemLanguageModel.default.isAvailable else { throw SceneReadError.invalidScene }
                    let rigs = targets.enumerated().map { number, unit in
                        let bones = unit.joints.map { joint in
                            "\(joint.id):p\(joint.parent ?? -1)@\(joint.x.rounded()),\(joint.y.rounded())"
                        }.joined(separator: " ")
                        let name = UnitIdentity.baseName(unit.name)
                        let title = self.workspace.artworkByName[name]?.displayTitle ?? name
                        return "\(number) \(title): \(bones)"
                    }.joined(separator: "\n")
                    let session = LanguageModelSession(instructions: """
                        You direct 2D skeletal animation. Return 4 to 6 chronological poses within 4 seconds.
                        Use only the listed subjects and bone IDs, never rotate a root joint.
                        Offsets and angles are absolute relative to the starting rig, not accumulated.
                        Specify each moving subject at each beat with only its 1 to 3 most relevant bends.
                        Use anticipation, weight transfer,
                        asymmetric timing, follow-through and a settled ending. Use small joint angles for
                        balance and larger ones only where needed. Match the requested action and rig.
                        Coordinates grow down and right. Leave unrelated subjects unchanged.
                        """)
                    let result = try await session.respond(to: "Action: \(prompt)\nScene: \(original.width)×\(original.height)\nRigs: \(rigs)",
                                                           generating: MotionPlan.self)
                    try Task.checkCancellation()
                    frames = try self.motionFrames(result.content, frame: frame, targets: targets, document: original)
                } catch {
                    try Task.checkCancellation()
                    usedFallback = true
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
                    if usedFallback {
                        self?.message("Кадры созданы", "Системная модель не смогла построить движение. Применён резервный вариант, который можно отредактировать.")
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
            throw SceneReadError.invalidScene
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
