import AppKit

/// Keeps status-item clicks from racing `didResignActive`, while still allowing
/// normal app switches (Cmd-Tab, clicking another app) to dismiss the panel.
enum PanelDismissalPolicy {
    static func shouldCloseAfterResign(
        isShown: Bool,
        isClosing: Bool,
        cursorOverStatusButton: Bool,
        mouseButtonDown: Bool
    ) -> Bool {
        guard isShown, !isClosing else { return false }
        // A status-bar click can resign the app just before the button action
        // toggles the panel. Ignore only the actual press, not a parked cursor.
        return !(cursorOverStatusButton && mouseButtonDown)
    }

    static func regressionProbe() -> Bool {
        let cases: [(Bool, Bool, Bool, Bool, Bool)] = [
            (true, false, true, true, false),
            (true, false, true, false, true),
            (true, false, false, true, true),
            (true, false, false, false, true),
            (false, false, true, true, false),
            (true, true, true, true, false),
        ]
        return cases.allSatisfy { shown, closing, cursor, mouseDown, expected in
            shouldCloseAfterResign(
                isShown: shown,
                isClosing: closing,
                cursorOverStatusButton: cursor,
                mouseButtonDown: mouseDown) == expected
        }
    }
}
