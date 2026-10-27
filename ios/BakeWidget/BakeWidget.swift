import SwiftUI
import WidgetKit

/// The home-screen widget: the step a bake is on, with Done and 15 more min,
/// or the recipe pinned to it when no bake is running.
///
/// Dart saves the bake's whole forecast (`bakeSnapshot`), so the timeline has
/// an entry at each step's end and every entry picks its own step: the first
/// whose end is still ahead. The app reloads the timeline whenever the bake
/// changes. Taps open `bakerscalc://widget/<route>`, a route of the app.

struct BakeStepInfo: Decodable {
  let step: Int
  let title: String
  let endsAt: Double
  let next: String?
  let sets: String?

  var end: Date { Date(timeIntervalSince1970: endsAt / 1000) }
}

struct BakeInfo: Decodable {
  let recipeId: String
  let recipeName: String
  let loaves: Int?
  let steps: [BakeStepInfo]
}

struct PinnedInfo: Decodable {
  let id: String
  let name: String
  let line: String
}

struct BakeEntry: TimelineEntry {
  let date: Date
  let bake: BakeInfo?
  let pinned: PinnedInfo?

  var step: BakeStepInfo? { bake?.steps.first { $0.end > date } }

  static let sample = BakeEntry(
    date: Date(),
    bake: BakeInfo(
      recipeId: "", recipeName: "Country loaf", loaves: nil,
      steps: [
        BakeStepInfo(
          step: 0, title: "Bulk ferment",
          endsAt: Date().addingTimeInterval(5400).timeIntervalSince1970 * 1000,
          next: "Shape", sets: nil)
      ]),
    pinned: nil)
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> BakeEntry { .sample }

  func getSnapshot(in context: Context, completion: @escaping (BakeEntry) -> Void) {
    let entry = read(at: Date())
    completion(context.isPreview && entry.bake == nil && entry.pinned == nil ? .sample : entry)
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<BakeEntry>) -> Void) {
    let now = Date()
    let first = read(at: now)
    let ends = (first.bake?.steps ?? []).map(\.end).filter { $0 > now }
    let entries = [first] + ends.map { BakeEntry(date: $0, bake: first.bake, pinned: first.pinned) }
    completion(Timeline(entries: entries, policy: .never))
  }

  private func read(at date: Date) -> BakeEntry {
    let data = UserDefaults(suiteName: bakeAppGroup)
    func decode<T: Decodable>(_ key: String) -> T? {
      guard let raw = data?.string(forKey: key)?.data(using: .utf8) else { return nil }
      return try? JSONDecoder().decode(T.self, from: raw)
    }
    return BakeEntry(date: date, bake: decode("bake"), pinned: decode("pinned"))
  }
}

/// LightPalette and DarkPalette from `app_theme.dart`.
private func tone(_ light: UInt32, _ dark: UInt32) -> Color {
  func ui(_ hex: UInt32) -> UIColor {
    UIColor(
      red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
  }
  return Color(UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
}

private let surface = tone(0xEEF2E8, 0x1C241B)
private let onSurface = tone(0x24331F, 0xE6EEDF)
private let muted = tone(0x55664F, 0xA9B8A0)
private let primary = tone(0x3F5A3C, 0xA8C99A)
private let onPrimary = tone(0xFFFFFF, 0x142012)
private let secondary = tone(0xD5E3C8, 0x34502F)
private let onSecondary = tone(0x24331F, 0xD5E8C8)

private func link(_ route: String) -> URL { URL(string: "bakerscalc://widget/\(route)")! }

struct BakeWidgetView: View {
  let entry: BakeEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      content
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .containerBackground(surface, for: .widget)
  }

  @ViewBuilder private var content: some View {
    if let bake = entry.bake {
      let plan = "recipe/\(bake.recipeId)/plan" + (bake.loaves.map { "?loaves=\($0)" } ?? "")
      label(bake.recipeName)
      if let step = entry.step {
        title(step.title)
        (Text(step.end, style: .timer) + Text(" left"))
          .font(.subheadline.monospacedDigit()).foregroundStyle(onSurface)
        detail([step.sets, step.next.map { "Then: \($0)" } ?? "Last step"].compactMap { $0 }
          .joined(separator: " · "))
        Spacer(minLength: 4)
        HStack(spacing: 8) {
          press(step.sets == nil ? "Done" : "Set done", "done", step, filled: true)
          if step.sets == nil { press("15 more min", "extend", step, filled: false) }
        }
      } else {
        title("Bake finished")
        detail("Every step is behind you.")
        Spacer(minLength: 0)
      }
      Color.clear.frame(height: 0).widgetURL(link(plan))
    } else if let pinned = entry.pinned {
      label("Pinned recipe")
      title(pinned.name)
      detail(pinned.line)
      Spacer(minLength: 4)
      Link(destination: link("recipe/\(pinned.id)/plan")) { pill("Plan a bake", filled: true) }
      Color.clear.frame(height: 0).widgetURL(link("recipe/\(pinned.id)"))
    } else {
      label("Baker's Calculator")
      title("No bake running")
      detail("Pin a recipe from its page to keep it here.")
      Spacer(minLength: 0)
      Color.clear.frame(height: 0).widgetURL(link(""))
    }
  }

  private func label(_ text: String) -> some View {
    Text(text).font(.caption).foregroundStyle(muted).lineLimit(1)
  }

  private func title(_ text: String) -> some View {
    Text(text).font(.title3.bold()).foregroundStyle(onSurface).lineLimit(1)
  }

  private func detail(_ text: String) -> some View {
    Text(text).font(.caption).foregroundStyle(muted).lineLimit(2)
  }

  private func press(_ text: String, _ action: String, _ step: BakeStepInfo, filled: Bool)
    -> some View
  {
    Button(intent: BakeIntent(url: link("press?action=\(action)&step=\(step.step)"))) {
      pill(text, filled: filled)
    }
    .buttonStyle(.plain)
  }

  private func pill(_ text: String, filled: Bool) -> some View {
    Text(text)
      .font(.subheadline.bold())
      .foregroundStyle(filled ? onPrimary : onSecondary)
      .padding(.horizontal, 16)
      .frame(height: 36)
      .background(filled ? primary : secondary, in: Capsule())
  }
}

@main
struct BakeWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "BakeWidget", provider: Provider()) { entry in
      BakeWidgetView(entry: entry)
    }
    .configurationDisplayName("Bake")
    .description("The step your bake is on, or a pinned recipe.")
    .supportedFamilies([.systemMedium])
  }
}
