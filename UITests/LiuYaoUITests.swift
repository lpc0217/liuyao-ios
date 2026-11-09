import XCTest

final class LiuYaoUITests: XCTestCase {
    @MainActor
    func testSavedClassicsSourcesCanBeExpanded() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--open-latest"]
        app.launch()
        let summary = app.staticTexts["interpretation-summary"].firstMatch
        try XCTSkipUnless(summary.waitForExistence(timeout: 5), "需要预置含古籍引用的本机记录。")
        let sources = app.buttons["knowledge-sources"].firstMatch
        for _ in 0..<16 {
            if sources.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(sources.isHittable)
        sources.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "[P0028-01]")).firstMatch.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "真实回答古籍来源"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testClassicsLibraryCanBeOpened() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["设置"].tap()
        reveal(app.buttons["classics-library"], in: app)
        app.buttons["classics-library"].tap()
        let status = app.staticTexts["classics-status"]
        let empty = app.staticTexts["classics-empty"]
        XCTAssertTrue(status.waitForExistence(timeout: 3) || empty.waitForExistence(timeout: 3))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "古籍资料库"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testSavedSummaryIsShown() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--open-latest"]
        app.launch()
        let summary = app.staticTexts["interpretation-summary"].firstMatch
        try XCTSkipUnless(summary.waitForExistence(timeout: 5), "此用例需要预置含一句话总结的已保存解卦。")
        reveal(summary, in: app)
        XCTAssertTrue(summary.isHittable)
        XCTAssertFalse(summary.label.isEmpty)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "一句话总结"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testExampleChartAndHistorySurviveRelaunch() {
        let app = XCUIApplication()
        app.launch()
        reveal(app.buttons["fill-example"], in: app)
        app.buttons["fill-example"].tap()
        app.buttons["create-reading"].tap()
        XCTAssertTrue(app.staticTexts["original-name"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["original-name"].label, "火泽睽")
        XCTAssertEqual(app.staticTexts["changed-name"].label, "山泽损")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "排盘结果"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate()
        app.launch()
        app.tabBars.buttons["卦记"].tap()
        XCTAssertTrue(app.staticTexts["火泽睽 → 山泽损"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testKeychainSaveAndRemove() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-keychain"]
        app.launch()
        app.tabBars.buttons["设置"].tap()
        let field = app.secureTextFields["api-key"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("ui-test-placeholder")
        app.buttons["save-key"].tap()
        XCTAssertEqual(app.staticTexts["key-status"].label, "已保存", app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | "))
        app.terminate()
        app.launch()
        app.tabBars.buttons["设置"].tap()
        XCTAssertEqual(app.staticTexts["key-status"].label, "已保存")
        app.buttons["remove-key"].tap()
        app.buttons["移除密钥"].tap()
        let removed = NSPredicate(format: "label == %@", "未配置")
        expectation(for: removed, evaluatedWith: app.staticTexts["key-status"])
        waitForExpectations(timeout: 5)
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 {
            if element.isHittable { return }
            app.swipeUp()
        }
    }

    @MainActor
    func testLiveInterpretationAndSavedAnswer() throws {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["设置"].tap()
        try XCTSkipUnless(app.staticTexts["key-status"].label == "已保存", "仅在本机已安全配置真实密钥时执行。")
        app.tabBars.buttons["起卦"].tap()
        reveal(app.buttons["fill-example"], in: app)
        app.buttons["fill-example"].tap()
        app.buttons["create-reading"].tap()
        reveal(app.buttons["interpret"], in: app)
        app.buttons["interpret"].tap()
        XCTAssertTrue(app.buttons["发送追问"].waitForExistence(timeout: 150), "真实解卦应返回完整回答")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "真实DeepSeek解读"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate()
        app.launch()
        app.tabBars.buttons["卦记"].tap()
        app.staticTexts["火泽睽 → 山泽损"].firstMatch.tap()
        XCTAssertTrue(app.buttons["发送追问"].waitForExistence(timeout: 10), "重启后仍应保留真实回答")
    }
}
