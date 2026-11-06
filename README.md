# Animation iOS reconstruction — incomplete

Native UIKit/Core Graphics/AVFoundation app reconstructed from an authorized Android APK using REA. This repository currently contains a working editor subset, not full functional or visual parity. See analysis/functionality_map.md.

## Build and installation

Run the **Build native iOS IPA** workflow in this private repository. It runs native core tests, generates the Xcode project via XcodeGen, compiles an unsigned device application on macOS, packages the IPA and attempts a simulator screenshot. No local Mac is needed.

Download **AnimationIOS-IPA** from the workflow artifacts. Open its IPA in Sideloadly on Windows, select the connected iPhone and sign with your own Apple account in Sideloadly. Do not share credentials in chat. The IPA is unsigned until this step.

Local macOS build, if ever needed: `brew install xcodegen`, `xcodegen generate`, then build scheme AnimationIOS. Native core checks: `swift test`.

Original fonts, artwork and icons are retained in App/Content. `original-assets/` and `decoded/` are local research inputs excluded from git; `analysis/evidence/` holds focused REA evidence.

## Онлайн-проекты через Supabase

Приложение напрямую использует Supabase Auth, PostgREST и Storage. Локальный сервер не нужен.
Публичные Project URL и publishable key находятся в App/Info.plist; это разрешённая клиентская конфигурация, не секретный ключ.

Первоначальная настройка:
1. Выполнить supabase/migrations/202611060001_community.sql в SQL Editor один раз.
2. Authentication → Sign In / Providers → Anonymous Sign-ins: включить.
3. Собрать iOS-приложение. Ник запрашивается при публикации/комментарии; email и пароль не нужны.

«Загрузить → Онлайн» открывает общую ленту внутри главного меню. Публикация — через меню редактора.
«Смотреть» использует существующий плеер. «Скачать для редактирования» сохраняет отдельную копию в проектах.
Формат .animationproject переносит JSON сцены, определения предметов, локальные картинки, свои фоны и звук.
Лимит архива — 50 МБ, распаковки — 100 МБ; пути из ZIP проверяются, симлинки запрещены.
Архивы приватного Storage bucket читаются пользователями Supabase Auth; записи защищены RLS.
Одна оценка 1–5 на анонимного пользователя, комментарии до 500 символов, лента по 30 проектов.
Сессия хранится в Keychain. При потере анонимной сессии прежний автор не восстанавливается по одному нику.
Лимит публикаций — 10/сутки, комментариев — 100/сутки на анонимного пользователя. Это не защита от создания множества анонимных аккаунтов; для большого публичного запуска нужны CAPTCHA/модерация и контроль квот Supabase.

## Настройки и совместимость

Настройки открываются в существующей панели с Roboto и цветами Android: onion (тень/скелет/выкл., 1–5 кадров), сетка, фон, камера, вибрация, полноэкранный режим, цвет костей, подсказки, качество и совместимость H.264.
Есть импорт предметов и шрифтов, экспорт своих .ati в ZIP и резервная копия Documents.
Пункты отсутствующих SVG/растровых редакторов, подписок и подарочных кодов объясняют ограничения iOS-версии. Полная функциональная идентичность Android пока не достигнута.
Кости всех спрайтов накладываются поверх изображений в редакторе; просмотр и экспорт их не рисуют.
При экспорте последний ключевой кадр удерживается, а не интерполируется к первому.
