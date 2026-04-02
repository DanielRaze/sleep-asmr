# SleepASMR (macOS SwiftUI)

Нативное macOS-приложение на SwiftUI + Vision + AVFoundation + IOKit.

## Что делает

- Запрашивает доступ к камере при первом запуске.
- В реальном времени определяет состояние глаз (открыты/закрыты).
- Запускает таймер непрерывно закрытых глаз.
- Если глаза открылись до порога, таймер сбрасывается.
- По достижении порога отправляет команду `pmset displaysleepnow` для выключения экрана.
- После срабатывания блокирует пользовательскую сессию (экран логина после пробуждения).
- Поддерживает адаптивный режим экономии: реже анализирует кадры при открытых глазах и чаще при закрытых.

## Интерфейс

- Предпросмотр камеры.
- Статус: `Глаза открыты` / `Глаза закрыты` / `Таймер: X сек до выключения`.
- Слайдер задержки от 30 секунд до 30 минут.
- Текстовое поле задержки в секундах.
- Кнопка `Старт/Стоп`.
- Переключатель `Выключить экран при срабатывании`.
- Переключатель `Экономить батарею (адаптивный анализ)`.

## Файлы

- `SleepASMR/SleepASMRApp.swift` — входная точка приложения.
- `SleepASMR/MainView.swift` — UI.
- `SleepASMR/MonitoringViewModel.swift` — логика мониторинга и таймера.
- `SleepASMR/CameraManager.swift` — работа с камерой.
- `SleepASMR/VisionEyeStateDetector.swift` — анализ глаз через Vision.
- `SleepASMR/DisplaySleepController.swift` — выключение экрана.
- `SleepASMR/Info.plist` — описание причины доступа к камере (`NSCameraUsageDescription`).

## Запуск

1. Откройте `SleepASMR.xcodeproj` в Xcode.
2. Выберите `My Mac` и запустите приложение.
3. При первом запуске разрешите доступ к камере.

## Примечание по CLI-сборке

Если `xcodebuild` ругается на Command Line Tools, переключите developer dir:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Удаленная сборка без локального Xcode

В репозиторий добавлен workflow GitHub Actions: [.github/workflows/build-macos.yml](.github/workflows/build-macos.yml).

Как использовать:

1. Создайте репозиторий на GitHub и отправьте код (`git push`).
2. Откройте вкладку **Actions** в GitHub.
3. Выберите workflow **Build macOS App**.
4. Нажмите **Run workflow**.
5. После завершения откройте job и скачайте artifact `SleepASMR-macOS-app`.

В artifact будет `SleepASMR.zip` с приложением `SleepASMR.app` (без подписи).
