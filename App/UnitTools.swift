import UIKit

extension EditorController {
    func mountContext(_ panel: UIView, width: CGFloat, unitMode: Bool = false) {
        let oldID=toolPanel?.accessibilityIdentifier
        let offset=(toolPanel?.subviews.first(where:{$0 is UIScrollView}) as? UIScrollView)?.contentOffset
        dismissTools(); panel.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(panel)
        NSLayoutConstraint.activate([panel.leadingAnchor.constraint(equalTo: sidebarScroll.trailingAnchor), panel.topAnchor.constraint(equalTo: view.topAnchor), panel.bottomAnchor.constraint(equalTo: view.bottomAnchor), panel.widthAnchor.constraint(equalToConstant: width)])
        toolPanel = panel; unitToolsActive = unitMode; shift.isHidden = true; if unitMode { highlightUnitTools(true) }
        if oldID==panel.accessibilityIdentifier,let offset,let scroll=panel.subviews.first(where:{$0 is UIScrollView}) as? UIScrollView {view.layoutIfNeeded();scroll.setContentOffset(CGPoint(x:0,y:min(offset.y,max(0,scroll.contentSize.height-scroll.bounds.height))),animated:false)}
    }
    func highlightUnitTools(_ active: Bool) {
        guard let button=sidebar.arrangedSubviews[3] as? UIButton else{return};var config=button.configuration
        let image=config?.image?.withRenderingMode(active ? .alwaysTemplate : .alwaysOriginal);config?.image=image;config?.background.cornerRadius=0;config?.background.backgroundColor=active ? .original(0x00bd78):.clear;config?.baseForegroundColor=active ? .white:.original(0x00bd78);button.configuration=config
    }
    func refreshUnitTools() { if unitToolsActive { showUnitTools() } }
    func showUnitTools() {
        guard let index = workspace.selected, workspace.frame.units.indices.contains(index) else { showUnitList(); return }
        let unit = workspace.frame.units[index]
        let definition = workspace.catalog.first { $0.name == UnitIdentity.baseName(unit.name) }
        let title = definition?.displayTitle ?? UnitIdentity.baseName(unit.name)
        var commands: [FrameToolsPanel.Command] = []
        var icons: [String:String] = [:]
        func add(_ id: String, _ text: String, _ icon: String, enabled: Bool = true, action: @escaping () -> Void) {
            icons[id] = icon; commands.append(.init(id: id, title: text, height: 70, enabled: enabled, action: action))
        }
        if workspace.states(for: unit).count > 1 { add("prop_set_states", "Кадры", "props_state", action: { [weak self] in self?.showAssetStates() }) }
        add("prop_delete", "Удалить", "props_delete", action: { [weak self] in self?.workspace.removeObject() })
        add("prop_set_opacity", "Прозрачн.", "props_opacity", action: { [weak self] in self?.showOpacity() })
        add("prop_flip", "Отразить", "props_flip", action: { [weak self] in self?.workspace.flip() })
        if FrameManipulation.attachment(unit) != nil { add("prop_detach", "Отсоединить", "props_detach", action: { [weak self] in
            guard let self, let selected = self.workspace.selected else { return }; var frame = self.workspace.frame
            guard UnitEditing.detach(selected, in: &frame) else { return }; self.workspace.checkpoint(); self.workspace.document.frames[self.workspace.index] = frame; self.workspace.notify()
        }) }
        let order = UnitEditing.orderedIndices(in: workspace.frame), rank = order.firstIndex(of: index) ?? 0
        add("prop_rearrange_up", "Выше", "props_down", enabled: rank < order.count - 1, action: { [weak self] in self?.rearrangeUnit(forward: true) })
        add("prop_rearrange_down", "Ниже", "props_up", enabled: rank > 0, action: { [weak self] in self?.rearrangeUnit(forward: false) })
        add("prop_copy", "Копировать", "props_copy", action: { [weak self] in
            guard let self, let selected = self.workspace.selected else { return }; self.unitClipboard = UnitEditing.snapshot(in: self.workspace.frame, selected: selected); self.workspace.selected = nil; self.update()
        })
        add("prop_lock",workspace.latchedUnitName == nil ? "Закрепить":"Отпустить",workspace.latchedUnitName == nil ? "props_lock_others":"props_unlock_others",action:{[weak self] in
            guard let self,let selected=self.workspace.selected else{return}
            if self.workspace.latchedUnitName != nil {self.workspace.latchedUnitName=nil;self.workspace.selected=nil}
            else {var root=selected;var visited=Set<Int>();while visited.insert(root).inserted,let parent=FrameManipulation.attachment(self.workspace.frame.units[root])?.0,let index=self.workspace.frame.units.firstIndex(where:{$0.name==parent}) {root=index};self.workspace.latchedUnitName=self.workspace.frame.units[root].name;self.workspace.selected=root}
            self.update()
        })
        add("unit_select_list", "Объекты", "props_close", action: { [weak self] in self?.workspace.selected = nil; self?.update() })
        let panel = FrameToolsPanel(commands: commands, accent: .original(0x00bd78), caption: title, identifier: "UnitPropertiesPanel", icons: icons)
        mountContext(panel, width: 86, unitMode: true)
    }
    func showUnitList() {
        let items = UnitEditing.orderedIndices(in: workspace.frame).reversed().map { index -> (String, UIImage?, () -> Void) in
            let unit = workspace.frame.units[index], definition = workspace.catalog.first { $0.name == UnitIdentity.baseName(unit.name) }
            let image = definition?.thumbnail.flatMap(workspace.artworkURL).flatMap { UIImage(contentsOfFile: $0.path) }
            return (definition?.displayTitle ?? unit.name, image, { [weak self] in self?.workspace.selected = index; self?.update() })
        }
        let panel = UnitListPanel(caption: "Кадр \(workspace.index + 1)", items: items, canPaste: !unitClipboard.isEmpty) { [weak self] in
            guard let self else { return }; var frame = self.workspace.frame; let pasted = UnitEditing.paste(self.unitClipboard, into: &frame)
            guard !pasted.isEmpty else { return }; self.workspace.checkpoint(); self.workspace.document.frames[self.workspace.index] = frame; self.workspace.selected = nil; self.workspace.notify()
        }
        mountContext(panel, width: 126, unitMode: true)
    }
    func rearrangeUnit(forward: Bool) {
        guard let selected = workspace.selected else { return }; var frame = workspace.frame
        guard UnitEditing.rearrange(selected, forward: forward, in: &frame) else { return }; workspace.checkpoint(); workspace.document.frames[workspace.index] = frame; workspace.notify()
    }
    func showOpacity() {
        guard let selected = workspace.selected else { return }
        let panel = OpacityPanel(value: Float(workspace.frame.units[selected].attributes["alpha"] ?? "1") ?? 1, begin: { [weak self] in self?.workspace.checkpoint() }, change: { [weak self] value in
            guard let self, self.workspace.frame.units.indices.contains(selected) else { return }; self.workspace.document.frames[self.workspace.index].units[selected].attributes["alpha"] = String(value); self.canvas.setNeedsDisplay()
        }, end: { [weak self] in self?.workspace.notify() }, close: { [weak self] in self?.showUnitTools() })
        mountContext(panel, width: 86); highlightUnitTools(true)
    }
    func showAssetStates() {
        guard let selected = workspace.selected else { return }
        let states = workspace.states(for: workspace.frame.units[selected])
        var commands = states.map { state in FrameToolsPanel.Command(id: "asset-state-\(state)", title: String(state + 1), height: 60, enabled: true, action: { [weak self] in
            guard let self, let index = self.workspace.selected else { return }; self.workspace.checkpoint(); self.workspace.document.frames[self.workspace.index].units[index].attributes["state"] = String(state); self.workspace.notify(); self.showAssetStates()
        }) }
        commands.insert(.init(id: "animation_cogs", title: "Анимация", height: 70, enabled: true, action: { [weak self] in self?.showAssetAnimation() }), at: 0)
        commands.insert(.init(id: "props_apply", title: "Готово", height: 60, enabled: true, action: { [weak self] in self?.showUnitTools() }), at: 0)
        let panel=FrameToolsPanel(commands:commands,accent:.original(0x00bd78),identifier:"UnitStatesPanel")
        panel.accessibilityValue=workspace.frame.units[selected].attributes["state"] ?? "0"
        mountContext(panel,width:86);highlightUnitTools(true)
    }
    func showAssetAnimation() {
        guard let index = workspace.selected else { return }
        let name = workspace.frame.units[index].name
        let dialog = AssetAnimationController(configuration: workspace.assetAnimations[name], frameIDs: workspace.document.frames.map(\.id)) { [weak self] config in
            guard let self else { return }; self.workspace.checkpoint(); var values = self.workspace.assetAnimations; values[name] = config; self.workspace.assetAnimations = values; self.workspace.notify()
        }
        dialog.modalPresentationStyle = .overFullScreen; present(dialog, animated: false)
    }
}
