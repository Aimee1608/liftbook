import XCTest

/// App 预览录屏的操作脚本。**不在 UITests target 里**,录制时才复制进 UITests/。
/// 配合 `xcrun simctl io <udid> recordVideo` 一起跑,节奏靠 sleep 控制。
/// XCUITest 每步查找元素都有开销,实际录出来比这里 sleep 的总和长不少——
/// 策略是「录长了再裁」,不要掐着 30 秒写脚本。
final class PreviewVideoTests: XCTestCase {
    private func pause(_ seconds: Double) { Thread.sleep(forTimeInterval: seconds) }

    private func tap(_ el: XCUIElement, _ timeout: TimeInterval = 10) {
        XCTAssertTrue(el.waitForExistence(timeout: timeout), "missing \(el)")
        el.tap()
    }

    func testRecordPreview() {
        let app = XCUIApplication()
        app.launchArguments += ["-resetData", "-demoData"]
        app.launch()

        // 1. 首页:今天练哪一天、每个动作多重
        XCTAssertTrue(app.buttons["start-workout"].waitForExistence(timeout: 20))
        pause(1.8)

        // 2. 进训练页,目标已经预填好
        tap(app.buttons["start-workout"])
        XCTAssertTrue(app.buttons["set-done-1"].waitForExistence(timeout: 10))
        pause(1.2)

        // 3. 达标一点打卡,休息计时器自动开始
        tap(app.buttons["set-done-1"])
        pause(1.1)
        tap(app.buttons["set-done-2"])
        pause(0.7)

        // 4. 没做够时改数字:次数面板 −1
        tap(app.buttons["set-reps-3"])
        XCTAssertTrue(app.buttons["确定"].waitForExistence(timeout: 5))
        pause(0.6)
        if app.buttons["−1"].exists { app.buttons["−1"].tap() }
        pause(0.5)
        tap(app.buttons["确定"])
        pause(0.3)
        tap(app.buttons["set-done-3"])
        pause(0.4)
        tap(app.buttons["set-done-4"])

        // 5. 动作做完,标题旁立刻出现下次目标徽章
        pause(1.8)

        // 6. 结束训练 → 完成页的渐进建议
        tap(app.buttons["end-workout"])
        if app.alerts.buttons["结束"].waitForExistence(timeout: 3) { app.alerts.buttons["结束"].tap() }
        XCTAssertTrue(app.buttons["summary-done"].waitForExistence(timeout: 10))
        pause(2.8)

        tap(app.buttons["summary-done"])
        pause(1.0)

        // 7. 历史日历:练过的日子一眼可见
        let history = app.tabBars.buttons["历史"]
        if history.waitForExistence(timeout: 3) { history.tap() } else { tap(app.buttons.matching(identifier: "历史").firstMatch) }
        pause(2.4)
    }
}
