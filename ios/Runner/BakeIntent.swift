import AppIntents
import Foundation
#if !WIDGET_EXTENSION
  import home_widget
#endif

/// Shared with Dart's `HomeScreenWidget.appGroup` and both targets'
/// entitlements.
let bakeAppGroup = "group.dev.bengid.bakersCalculator"

/// A widget button: hands its `bakerscalc://widget/press` link to Dart, which
/// applies it exactly as a reminder's button.
///
/// Compiled into the app and the widget extension. Only the app's copy does
/// anything: the press has to reach Dart, which only the app can run, and
/// [ForegroundContinuableIntent] is what makes the system run it there.
@available(iOS 17, *)
struct BakeIntent: AppIntent {
  static var title: LocalizedStringResource = "Bake step"
  static var isDiscoverable = false

  @Parameter(title: "Link")
  var url: URL

  init() {}

  init(url: URL) {
    self.url = url
  }

  func perform() async throws -> some IntentResult {
    #if !WIDGET_EXTENSION
      await HomeWidgetBackgroundWorker.run(url: url, appGroup: bakeAppGroup)
    #endif
    return .result()
  }
}

@available(iOS 17, *)
@available(iOSApplicationExtension, unavailable)
extension BakeIntent: ForegroundContinuableIntent {}
