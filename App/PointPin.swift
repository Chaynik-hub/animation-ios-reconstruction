import UIKit

extension EditorController {
    func selectPointToPin(unitName: String) {
        let prompt = UIAlertController(title: "Фиксация точки", message: "Нажмите на подвижную точку предмета. Её текущая позиция станет целью для выбранных кадров.", preferredStyle: .alert)
        prompt.addAction(UIAlertAction(title: "Выбрать точку", style: .default) { [weak self] _ in
            guard let self else { return }
            self.dismissTools()
            self.canvas.pinPointSelection = { [weak self] joint in self?.showPointPinRange(unitName: unitName, jointID: joint) }
        })
        prompt.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(prompt, animated: true)
    }

    private func showPointPinRange(unitName: String, jointID: Int) {
        guard let point = workspace.frame.units.first(where: { $0.name == unitName })?.joints.first(where: { $0.id == jointID }) else { return }
        let alert = UIAlertController(title: "Фиксация точки", message: "Первый и последний кадры включительно. Основная точка останется на месте.", preferredStyle: .alert)
        for (placeholder, value) in [("С кадра", workspace.index + 1), ("До кадра", workspace.document.frames.count)] {
            alert.addTextField { $0.placeholder = placeholder; $0.text = String(value); $0.keyboardType = .numbersAndPunctuation }
        }
        alert.addAction(UIAlertAction(title: "Применить", style: .default) { [weak self, weak alert] _ in
            guard let self, let fields = alert?.textFields,
                  let first = Int(fields[0].text ?? ""), let last = Int(fields[1].text ?? ""),
                  first >= 1, first <= last, last <= self.workspace.document.frames.count else {
                self?.message("Неверный диапазон", "Укажите номера кадров этой сцены.")
                return
            }
            var document = self.workspace.document
            var applied = 0
            for frameIndex in (first - 1)..<last {
                var frame = document.frames[frameIndex]
                guard let index = frame.units.firstIndex(where: { $0.name == unitName }) else { continue }
                var unit = frame.units[index]
                let roots = unit.joints.filter { $0.parent == nil || $0.attributes["base"] == "true" }
                guard unit.joints.contains(where: { $0.id == jointID && $0.parent != nil && $0.attributes["base"] != "true" }),
                      (try? InverseKinematics.solve(&unit, jointID: jointID, x: point.x, y: point.y)) != nil,
                      FrameManipulation.pastePose(unit, into: &frame, unitIndex: index),
                      roots.allSatisfy({ root in
                          frame.units[index].joints.contains { $0.id == root.id && $0.x == root.x && $0.y == root.y }
                      }) else { continue }
                document.frames[frameIndex] = frame
                applied += 1
            }
            guard applied > 0 else { self.message("Не удалось зафиксировать точку", "В выбранных кадрах нет подходящего скелета."); return }
            self.workspace.checkpoint()
            self.workspace.document = document
            self.workspace.notify()
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        present(alert, animated: true)
    }
}
