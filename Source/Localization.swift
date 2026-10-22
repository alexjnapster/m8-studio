import Foundation

enum AppLanguage {
    static var current: String {
        get { UserDefaults.standard.string(forKey:"studioLanguage") == "en" ? "en":"uk" }
        set { let language = newValue == "en" ? "en":"uk"; UserDefaults.standard.set(language,forKey:"studioLanguage"); UserDefaults.standard.set([language,language == "uk" ? "en":"uk"],forKey:"AppleLanguages") }
    }
    static let ukrainian: [String:String] = {
        guard let url = Bundle.main.url(forResource:"Translations",withExtension:"json",subdirectory:"uk.lproj"), let data = try? Data(contentsOf:url), let values = try? JSONDecoder().decode([String:String].self,from:data) else { return [:] }
        return values
    }()
    // Runtime status messages retain their canonical values. Match their translated
    // templates here, so a language switch also updates already-visible messages.
    static let templates: [(NSRegularExpression,String)] = ukrainian.compactMap { key,value in
        guard key.contains("%@") else { return nil }
        let parts = key.components(separatedBy:"%@").map(NSRegularExpression.escapedPattern(for:))
        guard let expression = try? NSRegularExpression(pattern:"^"+parts.joined(separator:"([\\s\\S]*?)")+"$") else { return nil }
        return (expression,value)
    }.sorted { $0.0.pattern.count > $1.0.pattern.count }
}
func L(_ text:String)->String {
    guard AppLanguage.current == "uk" else { return text }
    if let exact = AppLanguage.ukrainian[text] { return exact }
    let range = NSRange(text.startIndex...,in:text)
    for (expression,template) in AppLanguage.templates {
        guard let match = expression.firstMatch(in:text,range:range) else { continue }
        var translated = template
        for index in 1..<match.numberOfRanges {
            guard let range = Range(match.range(at:index),in:text), let placeholder = translated.range(of:"%@") else { continue }
            let raw = String(text[range]); let value = L(raw)
            translated.replaceSubrange(placeholder,with:value)
        }
        return translated
    }
    return text
}
// Format slots are separate from values: a device name or mode containing the
// same punctuation cannot be accidentally reinterpreted as part of a template.
func LF(_ key:String,_ values:[String])->String {
    let template = AppLanguage.current == "uk" ? AppLanguage.ukrainian[key] ?? key:key
    let chunks = template.components(separatedBy:"%@")
    guard chunks.count == values.count+1 else { return key }
    return chunks.enumerated().map { index,chunk in (index == 0 ? "":values[index-1])+chunk }.joined()
}

func studioTime(_ date:Date)->String {
    date.formatted(.dateTime.hour().minute().locale(Locale(identifier:AppLanguage.current == "uk" ? "uk_UA":"en_GB")))
}
