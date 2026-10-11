import Foundation
import WidgetKit

enum WidgetSyncHelper {
    static func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
