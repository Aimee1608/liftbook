import XCTest

/// 上架截图。这个文件**不在 UITests target 里**,平时不会跑;要出图时复制进
/// UITests/ 跑一次,导出后删掉(见 docs/release-guide.md)。
final class StoreShotTests: XCTestCase {
    private func shot(_ app: XCUIApplication, _ name: String) {
        let att = XCTAttachment(screenshot: app.screenshot())
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    private func tap(_ el: XCUIElement, _ timeout: TimeInterval = 8) {
        XCTAssertTrue(el.waitForExistence(timeout: timeout), "missing \(el)")
        el.tap()
    }

    private func tab(_ app: XCUIApplication, _ name: String) {
        let bar = app.tabBars.buttons[name]
        if bar.waitForExistence(timeout: 2) { bar.tap() } else { tap(app.buttons.matching(identifier: name).firstMatch) }
    }

    func testStoreScreens() {
        let app = XCUIApplication()
        app.launchArguments += ["-resetData", "-demoData"]
        addUIInterruptionMonitor(withDescription: "notifications") { alert in
            let allow = alert.buttons["允许"].exists ? alert.buttons["允许"] : alert.buttons["Allow"]
            if allow.exists { allow.tap(); return true }
            return false
        }
        app.launch()

        XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 15))
        sleep(1)
        shot(app, "1-home")

        tap(app.buttons["start-workout"])
        XCTAssertTrue(app.buttons["set-done-1"].waitForExistence(timeout: 8))
        tap(app.buttons["set-done-1"])
        sleep(1)
        app.swipeDown()
        tap(app.buttons["set-done-2"])
        sleep(2)
        shot(app, "2-session")

        tap(app.buttons["set-done-3"])
        tap(app.buttons["set-done-4"])
        sleep(1)
        tap(app.buttons["set-done-1"])
        tap(app.buttons["set-done-2"])
        tap(app.buttons["set-done-3"])
        if app.buttons["set-done-4"].waitForExistence(timeout: 2) { app.buttons["set-done-4"].tap() }
        sleep(1)
        tap(app.buttons["end-workout"])
        tap(app.alerts.buttons["结束"])
        XCTAssertTrue(app.buttons["summary-done"].waitForExistence(timeout: 8))
        sleep(1)
        shot(app, "3-summary")
        tap(app.buttons["summary-done"])

        tab(app, "历史")
        sleep(1)
        shot(app, "4-history")

        tab(app, "动作")
        tap(app.buttons["lib-barbell-bench-press"])
        XCTAssertTrue(app.buttons["adjust-progress"].waitForExistence(timeout: 8))
        sleep(1)
        shot(app, "5-detail")

        tab(app, "训练")
        tap(app.buttons["switch-day"])
        sleep(1)
        shot(app, "6-switch-day")
    }
}
