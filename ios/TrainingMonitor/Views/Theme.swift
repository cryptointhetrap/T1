import SwiftUI

/// The Go Harder Ai Training logo's palette — a bright lime green and a
/// brushed-metal silver, both set against true black — used as the app's
/// whole accent scheme. Replaces the earlier Maryland state flag gold/red.
/// Genuine warning/error states (e.g. a failed connection, high training
/// load) intentionally use system red instead, since red isn't part of
/// this brand palette and still needs to read as a warning, not an accent.
///
/// The app is forced to dark appearance (see `TrainingMonitorApp`), so
/// every color here is chosen to read clearly on true black, not tuned
/// for a light background.
extension Color {
    static let ghGreen = Color(red: 0.659, green: 0.847, blue: 0.039) // #A8D80A — sampled from the logo's lettering
    static let ghSilver = Color(red: 0.784, green: 0.784, blue: 0.776) // #C8C8C6 — sampled from the logo's brushed-metal silver
    static let ghBlack = Color.black
}
