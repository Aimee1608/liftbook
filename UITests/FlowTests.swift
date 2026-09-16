import XCTest

final class FlowTests: XCTestCase {
    private func shot(_ app: XCUIApplication, _ name: String) {
        let att = XCTAttachment(screenshot: app.screenshot())
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    private func tap(_ el: XCUIElement, _ timeout: TimeInterval = 5) {
        XCTAssertTrue(el.waitForExistence(timeout: timeout), "missing \(el)")
        el.tap()
    }

    func testCoreLoop() {
        let app = XCUIApplication()
        app.launchArguments += ["-resetData"]
        addUIInterruptionMonitor(withDescription: "notifications") { alert in
            let allow = alert.buttons["允许"].exists ? alert.buttons["允许"] : alert.buttons["Allow"]
            if allow.exists { allow.tap(); return true }
            return false
        }
        app.launch()

        XCTAssertTrue(app.buttons["disclaimer-accept"].waitForExistence(timeout: 8))
        app.swipeUp()
        app.swipeUp()
        tap(app.buttons["disclaimer-accept"])

        tap(app.buttons["template-four-day-split"])
        shot(app, "01-onboarding-template")
        tap(app.buttons["onb-next"])
        shot(app, "02-onboarding-days")
        tap(app.buttons["onb-next"])
        shot(app, "03-onboarding-items")
        tap(app.buttons["onb-next"])
        shot(app, "04-onboarding-done")
        tap(app.buttons["onb-finish"])

        XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 8))
        shot(app, "05-home")
        tap(app.buttons["start-workout"])

        XCTAssertTrue(app.buttons["set-weight-1"].waitForExistence(timeout: 8))
        shot(app, "06-session-initial")
        tap(app.buttons["set-weight-1"])
        XCTAssertTrue(app.buttons["确定"].waitForExistence(timeout: 5))
        shot(app, "07-numberpad")
        app.buttons["5"].tap()
        app.buttons["0"].tap()
        app.buttons["确定"].tap()
        tap(app.buttons["set-done-1"])
        shot(app, "08-session-first-done")
        tap(app.buttons["set-done-2"])
        tap(app.buttons["set-done-3"])
        tap(app.buttons["set-done-4"])
        sleep(1)
        shot(app, "09-session-exercise-done")

        tap(app.buttons["end-workout"])
        tap(app.alerts.buttons["结束"])
        XCTAssertTrue(app.buttons["summary-done"].waitForExistence(timeout: 8))
        shot(app, "10-summary")
        tap(app.buttons["summary-done"])

        XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 8))
        shot(app, "11-home-after")

        tap(app.tabBars.buttons["历史"])
        shot(app, "12-history")
        tap(app.tabBars.buttons["动作"])
        XCTAssertTrue(app.buttons["lib-barbell-bench-press"].waitForExistence(timeout: 5))
        shot(app, "13-library")
        app.buttons["lib-barbell-bench-press"].tap()
        XCTAssertTrue(app.buttons["adjust-progress"].waitForExistence(timeout: 5))
        shot(app, "14-detail")
        tap(app.tabBars.buttons["设置"])
        shot(app, "15-settings")
    }
}
