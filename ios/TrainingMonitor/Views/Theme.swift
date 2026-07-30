import SwiftUI

/// The Maryland state flag's palette — Calvert gold/black, Crossland
/// red/white — used as the app's whole accent scheme in place of the
/// assorted orange/blue/purple/green/yellow used ad hoc elsewhere.
///
/// The app is forced to dark appearance (see `TrainingMonitorApp`), so
/// every color here is chosen to read clearly on true black, not tuned
/// for a light background.
extension Color {
    static let mdGold = Color(red: 1.00, green: 0.761, blue: 0.055) // #FFC20E — plenty bright on black as-is
    static let mdRed = Color(red: 1.00, green: 0.271, blue: 0.227) // #FF453A — Apple's own dark-mode system red; the flag's #E03C31 is too muted on true black
    static let mdBlack = Color.black
}
