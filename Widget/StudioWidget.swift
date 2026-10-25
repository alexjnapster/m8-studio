import SwiftUI
import WidgetKit

private struct DeskEntry: TimelineEntry { let date: Date }
private struct DeskProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeskEntry { DeskEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (DeskEntry) -> Void) { completion(DeskEntry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DeskEntry>) -> Void) {
        // Navigation is timeless. No polling, hardware access or invented live values.
        completion(Timeline(entries: [DeskEntry(date: .now)], policy: .never))
    }
}
struct DeskWidgetView: View {
    let english: Bool
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    private var brand: Color { colorScheme == .dark ? Color(red: 0.57, green: 0.88, blue: 0.71) : Color(red: 0.03, green: 0.39, blue: 0.28) }
    private func t(_ uk: String, _ en: String) -> String { english ? en : uk }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "display").foregroundStyle(brand)
                Text("M8 STUDIO").font(.system(size: 10, weight: .semibold)).tracking(1.2)
                Spacer(minLength: 0)
            }
            if family == .systemSmall {
                Text(t("Ваш простір.\nПід рукою.", "Your desk.\nWithin reach."))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Label(t("Відкрити керування", "Open controls"), systemImage: "arrow.up.right")
                    .font(.system(size: 10, weight: .medium))
            } else {
                HStack(spacing: 8) {
                    destination(.quick, icon: "slider.horizontal.3", title: t("Керування", "Controls"))
                    destination(.display, icon: "textformat.size", title: t("Екран", "Display"))
                    destination(.sound, icon: "speaker.wave.2", title: t("Звук", "Sound"))
                    destination(.scenes, icon: "square.stack.3d.up", title: t("Сцени", "Scenes"))
                }
                Text(t("Відкрийте потрібний розділ Studio.", "Open the right part of Studio."))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .widgetURL(StudioRoute.quick.url)
        .containerBackground(for: .widget) {
            LinearGradient(colors: colorScheme == .dark
                ? [Color(red: 0.10, green: 0.18, blue: 0.14), Color(red: 0.06, green: 0.10, blue: 0.08)]
                : [Color(red: 0.91, green: 0.96, blue: 0.91), .white], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    private func destination(_ route: StudioRoute, icon: String, title: String) -> some View {
        Link(destination: route.url) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 19, weight: .medium))
                Text(title).font(.system(size: 10, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(brand).frame(maxWidth: .infinity).padding(.vertical, 13)
            .background(brand.opacity(0.075), in: RoundedRectangle(cornerRadius: 13))
        }.accessibilityLabel(title)
    }
}
private struct DeskNavigationWidget: Widget {
    let english: Bool
    init() { english = false }
    init(english: Bool) { self.english = english }
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "M8Studio.Navigation." + (english ? "en" : "uk"), provider: DeskProvider()) { _ in
            DeskWidgetView(english: english)
        }
        .configurationDisplayName(english ? "M8 Studio · Quick access" : "M8 Studio · Швидкий доступ")
        .description(english ? "Open display, sound and scene controls. Navigation shortcuts; no live monitor readings." : "Відкривайте екран, звук і сцени. Швидкі переходи без показників монітора.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
@main struct StudioWidgetBundle: WidgetBundle {
    var body: some Widget {
        DeskNavigationWidget(english: false)
        DeskNavigationWidget(english: true)
    }
}
