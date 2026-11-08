import UIKit
extension EditorController {
    func showProjectDrawer() {
        stop(); dismissTools()
        let entries: [(String,String,()->Void)] = [
            ("Сохранить","side_save",{[weak self] in self?.save()}),
            ("Опубликовать онлайн","side_export",{[weak self] in self?.publishOnline()}),
            ("Экспорт","side_export",{[weak self] in self?.exports()}),
            ("Параметры сцены","side_edit",{[weak self] in self?.properties()}),
            ("Звук","side_audio",{[weak self] in self?.audioPicker()}),
            ("ИИ-аниматор · эксперимент","side_varspeed",{[weak self] in self?.showAIAnimator(unitName: nil)}),
            ("Фон","side_bg",{[weak self] in self?.backgrounds()}),
            ("Вид камеры","side_camera",{[weak self] in self?.showCameraControls()}),
            ("Настройки приложения","side_tune",{[weak self] in self?.showEditorSettings()}),
            ("Проекты","side_save",{[weak self] in if let landing = self?.presentingViewController as? LandingController { self?.dismiss(animated: true) { landing.showProjects() }; return }; self?.choices("Проекты",[("Новая сцена",{[weak self] in self?.newScene()}),("Открыть",{[weak self] in self?.openFiles()}),("Мои сцены",{[weak self] in self?.savedScenes()})])}),
            ("Предыдущий кадр полупрозрачно","side_preview",{[weak self] in self?.canvas.onion.toggle();self?.update()}),
            ("Повторить действие","side_reset",{[weak self] in self?.workspace.redo()})
        ]
        let cover=UIView(frame:view.bounds);cover.autoresizingMask=[.flexibleWidth,.flexibleHeight];cover.accessibilityIdentifier="ProjectDrawer"
        let outside=UIButton(frame:cover.bounds);outside.autoresizingMask=[.flexibleWidth,.flexibleHeight];outside.backgroundColor=UIColor.black.withAlphaComponent(0.65);outside.accessibilityLabel="Закрыть меню проекта";outside.addAction(UIAction{[weak self] _ in self?.dismissTools()},for:.touchUpInside);cover.addSubview(outside)
        let inset=view.safeAreaInsets.left
        let scroll=UIScrollView(frame:CGRect(x:0,y:0,width:200+inset,height:min(view.bounds.height,CGFloat(entries.count)*50)));scroll.backgroundColor = .original(0x24252f);scroll.autoresizingMask=[.flexibleHeight];cover.addSubview(scroll)
        let stack=UIStackView();stack.axis = .vertical;stack.frame=CGRect(x:inset,y:0,width:200,height:CGFloat(entries.count)*50);scroll.addSubview(stack);scroll.contentSize=CGSize(width:200+inset,height:stack.frame.height)
        for (title,icon,action) in entries {
            let button=UIButton(type:.custom);var config=UIButton.Configuration.plain();config.title=title.uppercased();config.baseForegroundColor = .white;config.image=UIImage(contentsOfFile:Bundle.main.resourceURL!.appendingPathComponent("Content/Icons/"+icon+".png").path)?.resizedIcon(density:2);config.imagePadding=10;config.contentInsets=NSDirectionalEdgeInsets(top:0,leading:20,bottom:0,trailing:10)
            config.titleTextAttributesTransformer=UIConfigurationTextAttributesTransformer{value in var result=value;result.font=UIFont(name:"Roboto-Bold",size:14) ?? .boldSystemFont(ofSize:14);return result};button.configuration=config;button.contentHorizontalAlignment = .leading;button.accessibilityLabel=title;button.addAction(UIAction{[weak self] _ in self?.dismissTools();action()},for:.touchUpInside);stack.addArrangedSubview(button);button.heightAnchor.constraint(equalToConstant:50).isActive=true
        }
        view.addSubview(cover);toolPanel=cover
    }
}
