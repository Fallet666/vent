<h1 align="center">🌀 Vent</h1>
<h3 align="center">Выберите температуру.<br>Обороты Vent подберёт сам.</h3>
<p align="center">Бесплатное управление вентиляторами Mac — прямо из строки меню.</p>

<p align="center">
  <a href="https://github.com/Fallet666/vent/releases/latest"><img src="https://img.shields.io/badge/%D0%A1%D0%BA%D0%B0%D1%87%D0%B0%D1%82%D1%8C%20%D0%B4%D0%BB%D1%8F%20macOS-2563EB?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="Скачать Vent"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/Free_%26_Open_Source-0D9488?style=for-the-badge&amp;logo=opensourceinitiative&amp;logoColor=white" alt="Free and open source"></a>
</p>
<p align="center">
  <a href="https://github.com/Fallet666/vent/releases/latest"><img src="https://img.shields.io/github/v/release/Fallet666/vent?style=flat-square&amp;color=7C3AED&amp;label=stable" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-64748B?style=flat-square" alt="macOS 13 or later">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-0D9488?style=flat-square" alt="MIT license"></a>
</p>
<p align="center">
  <a href="#install">Установка</a> &nbsp; · &nbsp;
  <a href="docs/images/README.md">Интерфейс</a>
</p>
<p align="center">
  <a href="README.md">English</a> &nbsp; · &nbsp;
  <a href="README.ru.md"><strong>Русский</strong></a> &nbsp; · &nbsp;
  <a href="README.de.md">Deutsch</a> &nbsp; · &nbsp;
  <a href="README.es.md">Español</a> &nbsp; · &nbsp;
  <a href="README.fr.md">Français</a> &nbsp; · &nbsp;
  <a href="README.pt-BR.md">Português (Brasil)</a> &nbsp; · &nbsp;
  <a href="README.zh-CN.md">简体中文</a> &nbsp; · &nbsp;
  <a href="README.ja.md">日本語</a> &nbsp; · &nbsp;
  <a href="README.ko.md">한국어</a>
</p>

<p align="center">
  <img src="docs/images/temperature-light.png" width="320" alt="Целевая температура, светлое оформление">
  &nbsp;&nbsp;
  <img src="docs/images/temperature-dark.png" width="320" alt="Целевая температура, тёмное оформление">
</p>

<table>
  <tr>
    <td align="center" width="33%"><strong>🌡️ Своя температура</strong><br><br>Выберите цель — Vent регулирует обороты.</td>
    <td align="center" width="33%"><strong>👁️ Видимое предупреждение</strong><br><br>Высокие обороты заметны без звука.</td>
    <td align="center" width="33%"><strong>💚 Все режимы бесплатно</strong><br><br>Без подписки и регистрации.</td>
  </tr>
</table>

## 🌡️ Меньше настроек — больше удобства

Необязательно разбираться, какие обороты нужны при каждой нагрузке. Включите **Auto Temp**, выберите желаемую температуру, и Vent будет сам регулировать вентиляторы, стремясь к ней. Или выберите готовый профиль и возвращайтесь к своим делам.

> [!TIP]
> **Управление по температуре бесплатно.** Без подписки, платных режимов и регистрации. Исходный код открыт по лицензии MIT.

| Что нужно | Что выбрать |
|---|---|
| Доверить охлаждение macOS | **Auto** |
| Автоматически подбирать обороты под заданную температуру | **Auto Temp** |
| Выставить обороты вручную | **Manual RPM** — для всех вентиляторов или каждого отдельно |
| Быстро переключаться между настройками | **Quiet**, **Normal**, **Gaming**, **Lap** или собственный профиль |

Заданная температура — цель регулировки. Достичь её получится не при любой нагрузке: результат зависит от Mac и окружающих условий. Vent использует доступные датчики; показание в приложении не означает температуру корпуса или кожи.

## 👁️ Шумные вентиляторы видно, даже если их не слышно

При высоких оборотах в панели появляется **текстовое предупреждение о возможном шуме**. Это особенно полезно глухим и слабослышащим людям, а также тем, кто работает в наушниках.

<p align="center">
  <img src="docs/images/noise-dark.png" width="320" alt="Оранжевая плашка предупреждает: вентиляторы на 85%, возможен сильный шум">
</p>

Vent оценивает возможный шум по оборотам: предупреждение появляется, когда наибольшие текущие обороты достигают 70% от наибольшего сообщённого максимума. **Микрофон не используется, децибелы не измеряются.**

Включите **Notify when fans are loud** в настройках и разрешите уведомления macOS. Vent проверяет обороты, пока приложение запущено, в том числе при закрытой панели. В одном периоде высоких оборотов приходит одно уведомление; небольшой запас у порога защищает от повторных оповещений.

## ✨ Всё под рукой

- Компактная панель в строке меню, светлое и тёмное системное оформление, без значка в Dock.
- Текущая температура и обороты; диапазоны регулировки берутся из данных оборудования.
- Готовые профили и сохранение собственных настроек.
- Градусы Цельсия и Фаренгейта, запуск при входе, настройка проверки обновлений.
- Закрытие панели сохраняет выбранный режим; выход из Vent возвращает управление macOS.
- `ventctl` для скриптов и диагностики — примеры в [руководстве разработчика](docs/DEVELOPMENT.md).

<a id="install"></a>

## 🚀 Установка

### Homebrew

```sh
brew tap Fallet666/homebrew-tap
brew install --cask vent
```

### Скачать DMG

1. Скачайте DMG из [последнего релиза](https://github.com/Fallet666/vent/releases/latest).
2. Перетащите **Vent** в **Applications** и откройте приложение.
3. Установите помощник по инструкции приложения. macOS запросит пароль администратора: он нужен для изменения оборотов.
4. Выберите **Auto Temp** и температуру либо готовый профиль.

В текущей упаковке используется ad-hoc-подпись без нотариализации Developer ID, поэтому macOS может заблокировать приложение. Прежде чем разрешать запуск в настройках безопасности macOS, проверьте источник загрузки и релиз.

Нужны **macOS 13+ и Mac с управляемыми вентиляторами**. В проекте есть поддержка Intel и Apple Silicon, но доступные датчики и управление зависят от модели. На MacBook Air без вентиляторов регулировать нечего. Для проверки конкретной модели пригодится [отчёт о совместимости](https://github.com/Fallet666/vent/issues/new?template=compatibility_report.yml).

## ↩️ Как вернуть управление macOS

> [!IMPORTANT]
> **При выходе из Vent вентиляторы возвращаются в Auto.** Закрытие панели сохраняет выбранные настройки.

Перед выходом Vent дожидается подтверждения автоматического управления от помощника. Если подтвердить возврат в Auto не получилось, приложение остаётся открытым и показывает ошибку. Выбрать **Auto** вручную можно в любой момент. Кнопка **Uninstall Helper** в настройках возвращает Auto и удаляет помощник. Само приложение при необходимости удаляется отдельно.

Для обновления на предварительные версии выберите **Бета** в **Настройки → Обновления → Канал обновлений**. По умолчанию выбран стабильный канал. Возврат к нему меняет будущие проверки обновлений и не откатывает установленную версию.

## 🔒 Приватность

Регистрации и аналитики нет. Управление вентиляторами происходит локально: приложение общается с `ventd` через Unix-сокет.

**Автоматическая проверка обновлений включена по умолчанию** и обращается к GitHub. Загрузка обновления также использует сеть. Автоматические проверки можно отключить в настройках: **Automatically check for updates**.

## 💚 Помочь проекту

<p align="center">
  <a href="https://github.com/Fallet666/vent"><img src="https://img.shields.io/badge/Star_Vent-F59E0B?style=for-the-badge&amp;logo=github&amp;logoColor=white" alt="Поставить звезду Vent"></a>
  <a href="https://github.com/Fallet666/vent/issues/new?template=compatibility_report.yml"><img src="https://img.shields.io/badge/Share_your_Mac-7C3AED?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="Сообщить о совместимости"></a>
</p>

Если Vent пригодился, поставьте звезду, расскажите о нём знакомым или сообщите, как он работает на вашей модели Mac. Баг-репорты, переводы и pull request тоже помогают.

Для отчёта об аппаратной проблеме укажите модель Mac, версию macOS, ожидаемый результат и вывод команд:

```sh
ventctl list
ventctl temps
ventctl daemon status
```

## 🛠️ Сборка и участие

[Руководство разработчика](docs/DEVELOPMENT.md): сборка, CLI и устройство проекта.

[Лицензия MIT](LICENSE).
