import XCTest

final class SecondaryFlowTests: XCTestCase {
    private func shot(_ app: XCUIApplication, _ name: String) {
        let att = XCTAttachment(screenshot: app.screenshot())
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    private func tab(_ app: XCUIApplication, _ name: String) {
        let bar = app.tabBars.buttons[name]
        if bar.waitForExistence(timeout: 2) { bar.tap() } else { tap(app.buttons.matching(identifier: name).firstMatch) }
    }

    private func tap(_ el: XCUIElement, _ timeout: TimeInterval = 5) {
        XCTAssertTrue(el.waitForExistence(timeout: timeout), "missing \(el)")
        el.tap()
    }

    func testSecondaryFlows() {
        let app = XCUIApplication()
        app.launchArguments += ["-resetData"]
        addUIInterruptionMonitor(withDescription: "notifications") { alert in
            let allow = alert.buttons["允许"].exists ? alert.buttons["允许"] : alert.buttons["Allow"]
            if allow.exists { allow.tap(); return true }
            return false
        }
        app.launch()

        XCTAssertTrue(app.buttons["disclaimer-accept"].waitForExistence(timeout: 8))
        app.swipeUp(); app.swipeUp()
        tap(app.buttons["disclaimer-accept"])
        tap(app.buttons["template-three-day-split"])
        tap(app.buttons["onb-next"]); tap(app.buttons["onb-next"]); tap(app.buttons["onb-next"])
        tap(app.buttons["onb-finish"])

        tap(app.buttons["switch-day"])
        shot(app, "20-switch-day")
        tap(app.buttons["day-option-腿"])
        XCTAssertTrue(app.staticTexts["腿"].waitForExistence(timeout: 5))
        tap(app.buttons["start-workout"])

        XCTAssertTrue(app.buttons["set-weight-1"].waitForExistence(timeout: 8))
        tap(app.buttons["set-reps-1"])
        XCTAssertTrue(app.buttons["确定"].waitForExistence(timeout: 5))
        shot(app, "21-reps-pad")
        app.buttons["确定"].tap()
        tap(app.buttons["session-add-exercise"])
        XCTAssertTrue(app.buttons["pick-barbell-bench-press"].waitForExistence(timeout: 5) || app.cells.firstMatch.waitForExistence(timeout: 5))
        shot(app, "22-picker")
        if app.buttons["pick-barbell-bench-press"].exists { app.buttons["pick-barbell-bench-press"].tap() } else { app.cells.firstMatch.tap() }
        tap(app.buttons["picker-add"])
        sleep(1)
        shot(app, "23-session-added")
        tap(app.buttons["session-exit"])
        tap(app.buttons["保留进度，稍后继续"])
        XCTAssertTrue(app.buttons["resume-workout"].waitForExistence(timeout: 5))
        shot(app, "24-home-active")
        tap(app.buttons["resume-workout"])
        tap(app.buttons["end-workout"])
        tap(app.alerts.buttons["结束"])
        tap(app.buttons["summary-done"])

        tap(app.buttons["nav-plans"])
        XCTAssertTrue(app.staticTexts["三分化"].waitForExistence(timeout: 5))
        shot(app, "25-plan-list")
        app.staticTexts["三分化"].tap()
        XCTAssertTrue(app.staticTexts["推"].waitForExistence(timeout: 5))
        shot(app, "26-plan-editor")
        app.staticTexts["推"].tap()
        XCTAssertTrue(app.staticTexts["目标肌群"].waitForExistence(timeout: 5))
        shot(app, "27-day-editor")

        tab(app, "动作")
        tap(app.buttons["lib-add"])
        let nameField = app.textFields["动作名称（必填）"]
        tap(nameField)
        nameField.typeText("测试动作")
        tap(app.buttons["muscle-abs"])
        shot(app, "28-custom-editor")
        tap(app.buttons["custom-save"])
        sleep(1)

        tab(app, "设置")
        tap(app.buttons["lb"])
        tab(app, "动作")
        sleep(1)
        shot(app, "29-library-lb")

        tab(app, "历史")
        tap(app.descendants(matching: .any).matching(identifier: "history-0").firstMatch)
        XCTAssertTrue(app.buttons["编辑"].waitForExistence(timeout: 5))
        tap(app.buttons["编辑"])
        shot(app, "30-history-edit")
    }
}
