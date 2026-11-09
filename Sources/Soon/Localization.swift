import Foundation

enum Lang: String {
    case en, ru

    /// UserDefaults "language": "system" | "en" | "ru".
    static var current: Lang {
        switch UserDefaults.standard.string(forKey: "language") {
        case "en": .en
        case "ru": .ru
        default: Locale.preferredLanguages.first?.hasPrefix("ru") == true ? .ru : .en
        }
    }

    /// The user's locale (region, 24h clock) with only the language swapped.
    var locale: Locale {
        var c = Locale.Components(locale: .current)
        c.languageComponents = .init(languageCode: .init(rawValue), region: Locale.current.region)
        c.hourCycle = Locale.current.hourCycle
        return Locale(components: c)
    }
}

private let ru: [String: String] = [
    // menu
    "Upcoming in %@": "Через %@",
    "Now · %@ left": "Сейчас · осталось %@",
    "No upcoming events": "Нет предстоящих событий",
    "Today": "Сегодня",
    "Tomorrow": "Завтра",
    "All day": "Весь день",
    "Join %@ meeting": "Подключиться к %@",
    "Copy Meeting Link": "Скопировать ссылку",
    "Open in Calendar": "Открыть в Календаре",
    "Open Calendar": "Открыть Календарь",
    "Grant Calendar Access…": "Разрешить доступ к календарю…",
    "Settings…": "Настройки…",
    "Quit Soon": "Выйти из Soon",
    // status bar / durations
    "in %@": "через %@",
    "%@ left": "осталось %@",
    "now": "сейчас",
    "d": " д", "h": " ч", "m": " мин",
    // notifications
    "Starts in 10 minutes": "Начнётся через 10 минут",
    "Starts in 1 minute": "Начнётся через 1 минуту",
    "Join call": "Подключиться",
    "Test notification": "Тестовое уведомление",
    // settings window
    "Soon Settings": "Настройки Soon",
    "General": "Основные",
    "Language": "Язык",
    "System": "Системный",
    "Launch at Login": "Запускать при входе",
    "Title length in menu bar": "Длина названия в строке меню",
    "Hide title": "Скрыть название",
    "%d characters": "%d символов",
    "Notifications": "Уведомления",
    "10 minutes before": "За 10 минут",
    "1 minute before": "За 1 минуту",
    "All events, not only calls": "Все события, не только звонки",
    "Send Test Notification": "Отправить тестовое уведомление",
    "System Notification Settings…": "Системные настройки уведомлений…",
    "Notifications for Soon are turned off in System Settings": "Уведомления для Soon выключены в Системных настройках",
    "Calendars": "Календари",
]

/// English text is the key.
func L(_ s: String, _ lang: Lang = .current) -> String {
    lang == .ru ? ru[s] ?? s : s
}

func L(_ s: String, _ arg: CVarArg, _ lang: Lang = .current) -> String {
    String(format: L(s, lang), arg)
}
