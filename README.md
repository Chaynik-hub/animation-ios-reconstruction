# Animation iOS reconstruction — incomplete

Native UIKit/Core Graphics/AVFoundation app reconstructed from an authorized Android APK using REA. This repository currently contains a working editor subset, not full functional or visual parity. See analysis/functionality_map.md.

## Build and installation

Run the **Build native iOS IPA** workflow in this private repository. It runs native core tests, generates the Xcode project via XcodeGen, compiles an unsigned device application on macOS, packages the IPA and attempts a simulator screenshot. No local Mac is needed.

Download **AnimationIOS-IPA** from the workflow artifacts. Open its IPA in Sideloadly on Windows, select the connected iPhone and sign with your own Apple account in Sideloadly. Do not share credentials in chat. The IPA is unsigned until this step.

Local macOS build, if ever needed: `brew install xcodegen`, `xcodegen generate`, then build scheme AnimationIOS. Native core checks: `swift test`.

Original fonts, artwork and icons are retained in App/Content. `original-assets/` and `decoded/` are local research inputs excluded from git; `analysis/evidence/` holds focused REA evidence.

## Онлайн-проекты

Сервер общей ленты находится в [Server/community.py](Server/community.py).
Запустите его на Python 3.10+ за HTTPS-прокси и храните базу на постоянном диске.
По умолчанию процесс слушает 127.0.0.1:8080. Укажите путь к базе через
`ANIMATION_DB`, а при необходимости адрес и порт через `ANIMATION_HOST` и `PORT`.

При сборке приложения укажите HTTPS-адрес сервера в настройке Xcode
`ANIMATION_COMMUNITY_URL`. Вкладка «Загрузить» содержит кнопку «Онлайн»,
а публикация доступна через меню редактора. Ник сохраняется на устройстве.
Оценка от 1 до 5 заменяет предыдущую оценку этого устройства для того же проекта.
Лента и комментарии обновляются при открытии и по кнопке обновления.

Сервер принимает ATS до 16 МБ. Публикация использует существующий экспорт ATS
с его ограничениями по локальным ресурсам, включая звук и пользовательские фоны.
Этот сервер рассчитан на небольшой круг пользователей. Перед открытием общего
доступа настройте ограничения запросов и резервное копирование на стороне хостинга.
