import UIKit
import UniformTypeIdentifiers
import ZIPFoundation
import CoreText

enum AnimationSettings {
    static func bool(_ key: String, fallback: Bool = false) -> Bool { UserDefaults.standard.object(forKey:key) == nil ? fallback : UserDefaults.standard.bool(forKey:key) }
    static var onionMode: Int { UserDefaults.standard.object(forKey:"onionMode") == nil ? 1 : UserDefaults.standard.integer(forKey:"onionMode") }
    static var onionCount: Int { max(1,min(5,UserDefaults.standard.object(forKey:"onionCount") == nil ? 1 : UserDefaults.standard.integer(forKey:"onionCount"))) }
    static var skeletonColor: UIColor {
        switch UserDefaults.standard.integer(forKey:"skeletonColor") {
        case 1: return .original(0x00b6ff)
        case 2: return .white
        case 3: return .black
        case 4: return .original(0x72bd00)
        default: return .orange
        }
    }
    static func set(_ value: Any, _ key: String) {
        UserDefaults.standard.set(value,forKey:key); NotificationCenter.default.post(name:.animationSettingsChanged,object:nil)
        for scene in UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}) {
            for window in scene.windows { window.rootViewController?.setNeedsStatusBarAppearanceUpdate() }
        }
    }
}
extension Notification.Name { static let animationSettingsChanged = Notification.Name("AnimationSettingsChanged") }

final class SettingsController: OriginalListController, UIDocumentPickerDelegate {
    private let close: () -> Void
    private var pickingFont = false
    init(close: @escaping () -> Void) { self.close = close; super.init(nibName:nil,bundle:nil) }
    required init?(coder: NSCoder) { nil }
    override func viewDidLoad() { super.viewDidLoad(); render() }
    private func toggle(_ title: String, _ key: String, fallback: Bool = false) {
        let on = AnimationSettings.bool(key,fallback:fallback)
        let button = row(title) { [weak self] in AnimationSettings.set(!on,key); self?.render() }
        let image = UIGraphicsImageRenderer(size:CGSize(width:22,height:22)).image { context in
            let box=CGRect(x:2,y:2,width:18,height:18)
            if on {UIColor.original(0x72bd00).setFill();context.fill(box)}
            else {UIColor.lightGray.setStroke();context.cgContext.setLineWidth(2);context.cgContext.stroke(box)}
            if on {
                context.cgContext.setStrokeColor(UIColor.white.cgColor);context.cgContext.setLineWidth(2)
                context.cgContext.move(to:CGPoint(x:5,y:11));context.cgContext.addLine(to:CGPoint(x:9,y:15));context.cgContext.addLine(to:CGPoint(x:17,y:7));context.cgContext.strokePath()
            }
        }
        button.setImage(image.withRenderingMode(.alwaysOriginal),for:.normal)
        button.titleEdgeInsets.left=10;button.accessibilityLabel=title;button.accessibilityValue=on ? "Включено" : "Выключено"
    }
    private func render() {
        clear(); row("‹ Настройки") { [weak self] in self?.close() }
        label("Основные настройки")
        row("Режим onion: " + ["Без onion","Тень","Скелет","Серая тень"][min(3,max(0,AnimationSettings.onionMode))]) { [weak self] in
            self?.options("Режим onion", ["Без onion","Тень","Скелет","Серая тень"]) { AnimationSettings.set($0,"onionMode") }
        }
        row("Предыдущие кадры: \(AnimationSettings.onionCount)") { [weak self] in self?.options("Предыдущие кадры",(1...5).map(String.init)) { AnimationSettings.set($0+1,"onionCount") } }
        toggle("Показывать сетку","showGridPref")
        toggle("Показывать фон","showbgPref",fallback:true)
        toggle("Вибрация","vibroPref",fallback:true)
        toggle("Показывать камеру","showCamera",fallback:true)
        toggle("Полноэкранный режим","fullScreen",fallback:true)
        row("Цвет скелетов") { [weak self] in self?.options("Цвет скелетов",["Оранжевый","Голубой","Белый","Чёрный","Зелёный"]) { AnimationSettings.set($0,"skeletonColor") } }
        toggle("Показывать подсказки","show_tips",fallback:true)
        toggle("Высокое качество видео","high_video_quality_2")
        toggle("Режим совместимости видео","compatibility_mode")
        row("Чёткий SVG / растровый редактор / SVG 2×") { [weak self] in self?.message("Графические редакторы","Эти пункты Android управляют редакторами SVG и растровых предметов. В текущем iOS-проекте этих редакторов ещё нет; импорт .ati и изображений работает через меню добавления.") }
        label("Информация")
        row("Конфиденциальность") { [weak self] in self?.message("Онлайн-проекты","Публикуются только выбранные вами проекты, ник, оценки и комментарии. Архив включает свои спрайты, фон и звук. Облако Supabase хранит анонимный идентификатор. Ник не подтверждён регистрацией. Не публикуйте личные данные.") }
        row("Возраст пользователя") { [weak self] in self?.options("Возраст пользователя",["До 13 лет","13–17 лет","18 лет и старше","Не указывать"]) { AnimationSettings.set($0,"user_age") } }
        row("Подписки") { [weak self] in self?.message("Подписки","В этой версии нет платных подписок и покупок.") }
        row("О приложении") { [weak self] in self?.message("Рисуем мультфильмы 2 · iOS","Редактор мультфильмов с импортом .ati, экспортом MP4 и обменом проектами через Supabase.") }
        row("Пересмотреть интро") { [weak self] in self?.message("Как создать мультфильм","1. Создайте мультфильм и добавьте спрайт.\n2. Двигайте точки; нажмите корневую точку для масштаба и поворота.\n3. Добавляйте кадры справа.\n4. «Пуск» — просмотр; меню проекта — сохранение, MP4 и публикация.\n5. Чужие мультфильмы — «Загрузить → Онлайн».") }
        label("Другое")
        row("Действия с предметами") { [weak self] in self?.items() }
        row("Бэкап") { [weak self] in self?.backup() }
        row("Возможности") { [weak self] in self?.message("Возможности","Редактирование поз и кадров, свои спрайты .ati, фоны, звук, MP4/GIF, облачные публикации, оценки и комментарии.") }
        row("Подарочный код") { [weak self] in self?.message("Подарочный код","Коды магазина Android в этой iOS-версии не используются.") }
        row("Изменить ник в онлайне") { [weak self] in
            guard let self else { return }; UserDefaults.standard.removeObject(forKey:"community.nickname")
            CommunityAPI.enterNickname(on:self) { _ in }
        }
    }
    private func options(_ title: String, _ values: [String], select: @escaping (Int) -> Void) {
        clear(); row("‹ Настройки") { [weak self] in self?.render() }; label(title)
        for (index,value) in values.enumerated() { row(value) { [weak self] in select(index); self?.render() } }
    }
    private func items() {
        clear(); row("‹ Настройки") { [weak self] in self?.render() }
        row("Найти предметы (.ati)") { [weak self] in self?.pick(font:false) }
        row("Найти шрифты (.ttf, .otf)") { [weak self] in self?.pick(font:true) }
        row("Экспорт предметов") { [weak self] in self?.exportItems() }
    }
    private func pick(font: Bool) {
        pickingFont = font
        let picker = UIDocumentPickerViewController(forOpeningContentTypes:[.data],asCopy:true); picker.delegate = self; present(picker,animated:true)
    }
    func documentPicker(_ controller: UIDocumentPickerViewController,didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        do {
            let directory = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
            if pickingFont {
                guard ["ttf","otf"].contains(url.pathExtension.lowercased()) else { throw SceneReadError.invalidScene }
                let folder = directory.appendingPathComponent("Fonts"); try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
                let target = folder.appendingPathComponent(UUID().uuidString+"."+url.pathExtension)
                try FileManager.default.copyItem(at:url,to:target)
                guard CTFontManagerRegisterFontsForURL(target as CFURL,.process,nil) else { try? FileManager.default.removeItem(at:target); throw SceneReadError.invalidScene }
            } else { _ = try UserSpriteLibrary.importATI(url,directory:directory) }
            controller.dismiss(animated:true) { self.message("Добавлено") }
        } catch { controller.dismiss(animated:true) { self.message("Ошибка",error.localizedDescription) } }
    }
    private func share(_ url: URL) {
        let sheet = UIActivityViewController(activityItems:[url],applicationActivities:nil)
        sheet.popoverPresentationController?.sourceView = view; sheet.popoverPresentationController?.sourceRect = CGRect(x:view.bounds.midX,y:view.bounds.midY,width:1,height:1)
        present(sheet,animated:true)
    }
    private func exportItems() {
        do {
            let directory = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
            let records = UserSpriteLibrary.records(in:directory)
            guard !records.isEmpty else { message("Нет своих предметов"); return }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+"-items.zip")
            let archive = try Archive(url:url,accessMode:.create)
            for (index,record) in records.enumerated() {
                let data = try Data(contentsOf:directory.appendingPathComponent(record.archive))
                try archive.addEntry(with:"item-\(index).ati",type:.file,uncompressedSize:Int64(data.count),compressionMethod:.deflate) { offset,count in data.subdata(in:Int(offset)..<Int(offset)+count) }
            }; share(url)
        } catch { message("Ошибка",error.localizedDescription) }
    }
    private func backup() {
        do {
            let directory = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Animation-backup-"+UUID().uuidString+".zip")
            try FileManager.default.zipItem(at:directory,to:url,shouldKeepParent:false); share(url)
        } catch { message("Ошибка бэкапа",error.localizedDescription) }
    }
}
