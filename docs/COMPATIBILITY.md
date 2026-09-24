# 📱 Compatibility — will my phone work?

> 🇷🇺 [Русская версия ниже ↓](#ru)

**Short answer:** almost any Android phone from the last ~10 years works. What changes is **how** it works.
The deciding factor is the phone's **real Android version**, not its brand or skin (EMUI 12 is Android 10, Magic UI 4 is Android 10, and so on).
`SETUP.bat` reads it for you (`ro.build.version.sdk`) and picks the mode automatically.

## 1. The rule

| Real Android version | Mode | Picture | Phone mic in OBS | Flashlight |
|---|---|---|---|---|
| **12 or newer** (API 31+) | 📷 **CAMERA** — the sensor stream, no UI | clean, up to 1920×1080 | ✅ | ✅ |
| **11** (API 30) | 🖥️ **SCREEN** — phone runs a camera app, its screen is mirrored | camera app preview | ✅ phone must be **unlocked** when the camera starts | in the app |
| **5 – 10** (API 21–29) | 🖥️ **SCREEN** | camera app preview | ❌ use a PC/USB mic | in the app |
| 4.x or older | ❌ not supported by scrcpy | — | — | — |
| HarmonyOS NEXT / 5+ | ❌ no Android inside, no adb | — | — | — |

Sources: scrcpy [README](https://github.com/Genymobile/scrcpy/blob/master/README.md#prerequisites) (screen: Android 5+, audio: Android 11+), [camera.md](https://github.com/Genymobile/scrcpy/blob/master/doc/camera.md) (camera: Android 12+), [audio.md](https://github.com/Genymobile/scrcpy/blob/master/doc/audio.md) (Android 11 unlock rule). Flashlight needs scrcpy **4.0+** ([release](https://github.com/Genymobile/scrcpy/releases/tag/v4.0)); use **4.1+** — 4.0 had a camera bug on some Galaxy A51 / POCO phones ([#6919](https://github.com/Genymobile/scrcpy/issues/6919)). `SETUP.bat` checks this.

**Check it yourself:** Settings › About phone › Android version — or, with the phone connected: `adb shell getprop ro.build.version.sdk` (31+ = camera mode).

## 2. What every phone needs

1. **Developer options → USB debugging: ON** (tap *Build number* 7 times first — exact place per brand below).
2. A USB cable **that carries data** (many cheap cables only charge).
3. Tap **Allow** (and *Always allow from this computer*) on the phone the first time.
4. **Camera mode only:** turn off features that secretly use the front camera to "keep the screen on while you look at it". Android gives the camera to whoever is in the foreground, so these features kick the webcam out every few seconds ([Android CameraManager docs](https://developer.android.com/reference/android/hardware/camera2/CameraManager#openCamera(java.lang.String,%20android.hardware.camera2.CameraDevice.StateCallback,%20android.os.Handler))). *Observed on our Galaxy S10: Smart stay evicted the webcam every few seconds until switched off.*
5. **Android 12+:** the Quick Settings tile **Camera access** must be ON — otherwise the picture is black ([Android docs](https://developer.android.com/training/permissions/explaining-access)).

## 3. Brand cheat sheet

| Brand | Tap 7× on… | Developer options are in… | Extra switch you may need | Turn OFF (uses the front camera) |
|---|---|---|---|---|
| **Samsung** | About phone › Software information › Build number | bottom of Settings | One UI 6+: Security and privacy › **Auto Blocker OFF** (it greys out USB debugging) | Advanced features › Motions and gestures › **Keep screen on while viewing** (old: *Smart stay*) — `SETUP` offers to switch it off |
| **Xiaomi / Redmi / POCO** | About phone › (Detailed info and specs ›) MIUI / OS version | Additional settings › Developer options | *USB debugging (Security settings)* + reboot — only for taps from the PC, video works without it | HyperOS **Gaze detection** (if present) |
| **OPPO** | About device › Version › Build number | Additional settings › Developer options | *Disable permission monitoring* (only if scrcpy says it can't change settings) | Display & brightness › **Adaptive Sleep**; notification anti-peeping |
| **realme** | About phone › Version › Build number | Additional settings › Developer options | *Disable permission monitoring* (as above) | Display & brightness › **Adaptive Sleep / Screen attention**; **Smart notification hiding** |
| **OnePlus** (OxygenOS 12+) | About device › Version › Build number | Additional settings › Developer options | *Disable permission monitoring* (as above) | **Adaptive Sleep**; **Smart notification hiding** |
| **vivo / iQOO** | More settings (System management) › About phone › Software version | More settings / System management | — | Smart motion › Smart turn on/off screen › **Smart keep bright** |
| **Google Pixel** | About phone › Build number | System › Developer options | — | **Screen attention / Adaptive timeout**; Auto-rotate › **Face Detection** — `SETUP` offers to switch Screen attention off |
| **Motorola** | About phone › (Device identifiers ›) Build number | System › Developer options | — | Display › Screen timeout › **Attentive Display** |
| **Huawei** | search "Software version" › Build number | System & updates › Developer options | **Allow ADB debugging in charge only mode** | Accessibility features › **Smart Sensing** (all of it) |
| **Honor** | About phone › Build number | System & updates › Developer options | **Allow ADB debugging in charge only mode** | HONOR AI (or Assistant) › **Smart Sensing**; **Eye Tracking** |
| **Tecno / Infinix / itel** | My Phone (About phone) › Build number | System | — | none known |
| **Sony** | About phone › Build number | System › (Advanced ›) Developer options | Sony ADB driver on old Windows builds | none (Smart backlight uses motion, not the camera) |
| **Nothing / CMF** | About phone › Software info › Build number | System › Developer options | — | Display › Screen timeout › **Screen attention** |
| **Asus** | About phone › Software information › Build number | System › Developer options | — | older ZenUI: **Smart Screen On** |
| **Nokia (HMD)** | (System ›) About phone › Build number | System › (Advanced ›) Developer options | — | none known |
| **ZTE / Nubia / RedMagic** | About phone › Build number | System (ZTE) / System and updates (RedMagic) | if the PC doesn't see the phone: USB mode = MTP (ZTE advice) | none known |
| **Meizu** | About phone › Build number | Accessibility › Developer options (unverified) | scrcpy 3.3.4+ | none known |

**Any brand — the camera drops every time you unlock the phone?** Set Developer options › *Default USB configuration* = **No data transfer / charging only** (scrcpy maintainer's advice, [#2995](https://github.com/Genymobile/scrcpy/issues/2995#issuecomment-1029114499)). Huawei/Honor need *Allow ADB debugging in charge only mode* for that.

**Android 11+ forgets the PC after 7 days?** Developer options › *Disable adb authorization timeout*.

## 4. Popular older phones — which mode?

Final **official** Android version. 📷 = camera mode, 🖥️ = screen mode. A custom ROM (e.g. LineageOS) with Android 12+ turns a 🖥️ phone into a 📷 phone.

| Brand | 📷 Camera mode (Android 12+) | 🖥️ Screen mode (Android 5–11) |
|---|---|---|
| Samsung | Galaxy S10 / S10e / S10+, Note10, S20 series, A51 / A71 (incl. 5G), A52 / A52s and newer | Galaxy S8 / Note8 (9), S9 / Note9 (10), A10 / A20 / A30s / A50 (11) |
| Google | Pixel 3, 3a (12), Pixel 4 / 4a (13), 4a 5G / 5 / 5a (14) | Pixel, Pixel 2 (11) |
| Xiaomi / Redmi / POCO | Mi 10 / 10 Pro, Mi 10T, Redmi Note 9 / 9S / 9 Pro, Redmi Note 10 series, Redmi 9, POCO X3 NFC, X3 Pro, F2 Pro | Mi 9 / 9T / 9 SE (11), Redmi Note 7 (10), Redmi Note 8 / 8 Pro (11), **POCO F1 (10)**, Redmi 9A / 9C (10) |
| OnePlus | OnePlus 7 / 7 Pro / 7T (12), Nord (12), OnePlus 8 (13) | OnePlus 5 / 5T (10), 6 / 6T (11), 7 Pro 5G (10), Nord N10 / N100 (11) |
| OPPO | Reno3, Reno4 (12), Find X2 / X2 Pro (13) | Reno 10x Zoom, Reno2, A5 2020, A9 2020, A54 (11) |
| realme | realme 7 / 7 Pro (12), realme 8 (13) | realme 3 / 5 (10), 3 Pro, 5 Pro, 6 / 6 Pro, X2 Pro, C3 (11) |
| vivo | V20, V21, Y20, Y21 (12) | Y11 / Y12 (11) |
| Motorola | Moto G30, G60, G100, Moto G Pro, Edge+ 2020 (12) | Moto G6 (9), G7 family (10), G8 / G8 Power, G9 Plus, G 5G Plus (11) |
| Sony | Xperia 1 II, 5 II, 10 II (12), Xperia 1 III (13) | Xperia XZ2 / XZ3 (10), Xperia 1, Xperia 5 (11) |
| Asus | Zenfone 7 (12), Zenfone 8 (13), ROG Phone 3 (12), ROG Phone 5 (13) | Zenfone 5Z (10), Zenfone 6, ROG Phone II (11) |
| Nokia | Nokia 8.3 5G, 5.3 (12), G10 / G20 (13), X10 / X20 / XR20 (14) | Nokia 6.1 / 6.1 Plus / 7 Plus (10), Nokia 7.2 (11) |
| Honor | Honor 50 (13), Honor 70, Magic4 Pro (launched on 12) | Honor 20 / 20 Pro / View 20, Honor 10 (10) |
| Huawei | HarmonyOS 3/4 (China) report Android 12 — untested | P30 / P30 Pro (10, even on EMUI 12), Mate 20, P20 (10) |
| Nothing | every model (launched on Android 12+) | — |
| Tecno / Infinix | Camon 17 / 18, Infinix Note 11 / 12 (12) | most budget Spark / Hot / Smart / Pop — check the version |
| ZTE / Nubia | Blade A53 / A54 / A73, RedMagic 6 / 6 Pro (12+) | Axon 10 Pro (10), Blade A51 / A52 / A71 / A72 (11), RedMagic 5G / 5S (11) |

Sources for each row are in the research notes: Samsung ([SamMobile](https://www.sammobile.com/news/galaxy-s10-android-12-stable-update-released/)), Pixel ([Wikipedia](https://en.wikipedia.org/wiki/Google_Pixel)), Xiaomi ([XiaomiFirmwareUpdater](https://github.com/XiaomiFirmwareUpdater/miui-updates-tracker/blob/master/data/latest.yml)), OnePlus ([Wikipedia](https://en.wikipedia.org/wiki/OnePlus_7)), Asus ([Asus FAQ](https://www.asus.com/global/support/faq/1046891/)), Huawei ([GSMArena](https://www.gsmarena.com/huawei_p30_pro-9635.php)), Nothing ([Android Police](https://www.androidpolice.com/nothing-phone-1s-final-big-android-update-here/)). Regional firmware can differ — **the version on your phone is what counts.**

**✅ Tested by us:** Samsung Galaxy S10 (SM-G973F, Android 12) — camera mode, flashlight, phone mic, auto-reconnect.

## 5. Screen mode (Android 5–11): make the camera app look clean

Use **[Open Camera](https://opencamera.org.uk/)** (free, open source; Android 5 needs version **1.55**, Android 6+ the latest). `SETUP` detects it and opens it automatically every time the camera starts.

In Open Camera › Settings › **On screen GUI**:
- **Immersive mode → "Hide everything"** — only the preview stays on screen (don't touch the phone after that).
- **Keep display on → ON**.
- **Show on-screen messages → OFF**.
- *Force maximum brightness → OFF* (less heat; brightness doesn't affect the picture).

Then lock auto-rotate and put the phone in **landscape**. Use `ROTATE.bat` if the picture is sideways.
Why not the stock camera app? Samsung's closes itself after ~2 minutes idle ([scrcpy #2171](https://github.com/Genymobile/scrcpy/issues/2171)).

## 6. Known problem phones

| Phone | Problem | Fix |
|---|---|---|
| OPPO / OnePlus / realme (ColorOS) | camera crash `OplusCamera2StatisticsManager` | fixed in scrcpy 2.3 — keep scrcpy updated ([#4392](https://github.com/Genymobile/scrcpy/issues/4392)) |
| vivo / iQOO | `does not match caller's uid 2000` | fixed in scrcpy 3.0 ([#4883](https://github.com/Genymobile/scrcpy/issues/4883)) |
| Galaxy A51, POCO (MediaTek) on Android 13 | "Camera configuration error" | fixed in scrcpy 4.1 ([#6919](https://github.com/Genymobile/scrcpy/issues/6919)) |
| Galaxy S22 (Android 16), Moto G24 | camera 0 in error state | set another `cameraId` in `config.json` ([#6514](https://github.com/Genymobile/scrcpy/issues/6514), open) |
| Galaxy A53 | camera stops after minutes | keep 1920×1080 or lower ([#4865](https://github.com/Genymobile/scrcpy/issues/4865), open) — the tool reconnects automatically |
| Nothing Phone (3a) Pro | front camera crashes the camera stack | use the back camera ([#6717](https://github.com/Genymobile/scrcpy/issues/6717), open) |
| Xiaomi and many others | extra lenses (ultra-wide, macro) not listed | vendor restriction, won't fix ([#4392](https://github.com/Genymobile/scrcpy/issues/4392)) |

---

<a id="ru"></a>
<details>
<summary><b>🇷🇺 Совместимость — русская версия</b></summary>

## Подойдёт ли мой телефон?

**Коротко:** подойдёт почти любой Android-телефон за последние ~10 лет, меняется только **способ**. Решает **настоящая версия Android**, а не бренд или оболочка (EMUI 12 — это Android 10, Magic UI 4 — Android 10). `SETUP.bat` сам её узнаёт и выбирает режим.

### 1. Правило

| Версия Android | Режим | Картинка | Микрофон телефона | Фонарик |
|---|---|---|---|---|
| **12 и новее** | 📷 **КАМЕРА** — чистый поток с сенсора | до 1920×1080, без интерфейса | ✅ | ✅ |
| **11** | 🖥️ **ЭКРАН** — на телефоне открыто приложение камеры, экран передаётся на ПК | превью приложения | ✅ телефон должен быть **разблокирован** при старте | в приложении |
| **5 – 10** | 🖥️ **ЭКРАН** | превью приложения | ❌ нужен микрофон на ПК | в приложении |
| 4.x и старше, HarmonyOS NEXT | ❌ не поддерживается | | | |

Нужен scrcpy **4.1+** (фонарик появился в 4.0, а 4.0 ломал камеру на части Galaxy A51 / POCO). `SETUP.bat` это проверяет.

### 2. Что нужно на любом телефоне
1. **Параметры разработчика → Отладка по USB: ВКЛ** (сначала 7 раз нажать «Номер сборки», где именно — в таблице).
2. Кабель, который **передаёт данные**.
3. При первом подключении нажать **«Разрешить»** (и «Всегда разрешать с этого компьютера»).
4. **Для режима «камера»:** выключить функции, которые тайком включают фронтальную камеру («не гасить экран, пока смотрю»). Android отдаёт камеру тому, кто на переднем плане, и такие функции выбивают веб-камеру каждые несколько секунд. *На нашем Galaxy S10 это было точно: Smart Stay выбивала камеру, пока её не выключили.*
5. **Android 12+:** плитка быстрых настроек **«Доступ к камере»** должна быть включена, иначе картинка чёрная.

### 3. Шпаргалка по брендам

| Бренд | 7 раз нажать | Параметры разработчика | Доп. переключатель | Выключить (фронтальная камера) |
|---|---|---|---|---|
| **Samsung** | Сведения о телефоне › Сведения о ПО › Номер сборки | внизу Настроек | One UI 6+: Безопасность › **Автоблокировка ВЫКЛ** | Дополнительные функции › Движения и жесты › **Удержание экрана при просмотре** (Smart Stay) — `SETUP` выключит сам |
| **Xiaomi / Redmi / POCO** | О телефоне › (Все параметры ›) Версия MIUI / ОС | Расширенные настройки › Для разработчиков | «Отладка по USB (настройки безопасности)» + перезагрузка — только для нажатий с ПК | HyperOS: **отслеживание взгляда** (если есть) |
| **OPPO / realme / OnePlus** | О телефоне › Версия › Номер сборки | Дополнительные настройки › Для разработчиков | «Отключить мониторинг разрешений» — если scrcpy пишет, что не может менять настройки | **Адаптивный сон / Внимание к экрану**; **Умное скрытие уведомлений** |
| **vivo / iQOO** | О телефоне › Версия ПО | Ещё / Управление системой | — | Умные движения › **Умная подсветка** |
| **Google Pixel** | О телефоне › Номер сборки | Система › Для разработчиков | — | **Адаптивный экран / Внимание к экрану**; Автоповорот › **Распознавание лица** — `SETUP` выключит сам |
| **Motorola** | О телефоне › Номер сборки | Система › Для разработчиков | — | **Attentive Display** |
| **Huawei / Honor** | О телефоне › Номер сборки | Система и обновления › Для разработчиков | **«Разрешить отладку ADB в режиме только зарядки»** | **Умное распознавание (Smart Sensing)** — всё; Honor: **Отслеживание взгляда** |
| **Tecno / Infinix, Sony, Nokia, ZTE, Meizu** | О телефоне › Номер сборки | Система | — | не найдено |
| **Nothing / CMF** | О телефоне › Информация о ПО › Номер сборки | Система › Для разработчиков | — | Экран › Тайм-аут › **Внимание к экрану** |
| **Asus** | О телефоне › Сведения о ПО › Номер сборки | Система › Для разработчиков | — | старые ZenUI: **Smart Screen On** |

**Камера отваливается при каждой разблокировке телефона?** Параметры разработчика › «Конфигурация USB по умолчанию» = **Без передачи данных / Только зарядка**.

### 4. Популярные старые телефоны

📷 режим «камера» (Android 12+): Galaxy S10 / Note10 / S20 / A51 / A52, Pixel 3–5, Mi 10, Redmi Note 9 / 10, POCO X3 NFC / X3 Pro / F2 Pro, OnePlus 7 / 8 / Nord, OPPO Reno3 / Reno4 / Find X2, realme 7 / 8, vivo V20 / V21, Moto G30 / G60 / G100, Xperia 1 II / 5 II / 10 II, Zenfone 7 / 8, Nokia 8.3 / 5.3 / G10 / G20, Honor 50, все Nothing.

🖥️ режим «экран» (Android 5–11): Galaxy S8 / S9 / A10 / A50, Pixel 2, Mi 9, Redmi Note 7 / 8, **POCO F1**, OnePlus 5 / 6, realme 3 / 5 / 6, Moto G6–G9, Xperia 1 / 5, Zenfone 6, Honor 20, Huawei P30.

Полная таблица с источниками — в английской версии выше. Прошивка по регионам бывает разной, **решает версия на вашем телефоне**. Кастомная прошивка с Android 12+ (например, LineageOS) переводит телефон из 🖥️ в 📷.

**✅ Проверено нами:** Samsung Galaxy S10 (Android 12): режим «камера», фонарик, микрофон, автопереподключение.

### 5. Режим «экран»: чистая картинка

Поставьте **[Open Camera](https://opencamera.org.uk/)** (Android 5 — версия **1.55**). `SETUP` найдёт её и будет открывать сам. В Open Camera › Настройки › **Интерфейс на экране**: **Режим погружения → «Скрыть всё»**, **Не выключать экран → ВКЛ**, **Показывать сообщения → ВЫКЛ**. Выключите автоповорот, положите телефон горизонтально; если картинка боком — `ROTATE.bat`. Стандартная камера Samsung сама закрывается через ~2 минуты.

</details>
