import XCTest

final class StartModeTests: XCTestCase {
    private func launch() -> XCUIApplication {
        continueAfterFailure=false
        let app=XCUIApplication()
        app.launchArguments=["--preview-rank=1","--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["startWork"].waitForExistence(timeout:10))
        return app
    }
    private func attach(_ app: XCUIApplication,_ name: String) {
        let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)
    }
    func testSpectrumPanelShowsAmbienceWithMusicOff() {
        continueAfterFailure=false
        let app=XCUIApplication()
        app.launchArguments=["--preview-rank=3","--ui-testing"]
        app.launch()
        let panel=app.descendants(matching:.any).matching(identifier:"soundSettings").firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout:10))
        XCTAssertTrue(panel.label.contains("すべての音がオフ"))
        XCTAssertLessThan(panel.frame.height,100)
        let outside=CGPoint(x:panel.frame.midX,y:panel.frame.minY-24)
        app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:outside.x,dy:outside.y)).tap()
        XCTAssertFalse(app.staticTexts["この場所の音"].exists)
        app.buttons["世界の操作を表示・非表示"].tap()
        let ready=XCTNSPredicateExpectation(predicate:NSPredicate(format:"isHittable == true"),object:panel)
        XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:4),.completed)
        panel.tap()
        let wind=app.buttons["toggleSound_wind"]
        XCTAssertTrue(wind.waitForExistence(timeout:4))
        wind.tap()
        app.buttons["閉じる"].tap()
        let ambient=XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@","環境音、再生中"),object:panel)
        XCTAssertEqual(XCTWaiter.wait(for:[ambient],timeout:4),.completed)
        attach(app,"Larger spectrum reacts to ambience with BGM off")
        panel.tap()
        app.buttons["toggleMusic"].tap()
        app.buttons["閉じる"].tap()
        let music=XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@","Night Signal、再生中"),object:panel)
        XCTAssertEqual(XCTWaiter.wait(for:[music],timeout:4),.completed)
        attach(app,"Larger spectrum with music and ambience")
    }
    func testArcTapStartsNormalAndCanCancel() {
        let app=launch()
        app.buttons["startWork"].tap()
        attach(app,"After tapping start")
        let normal=app.buttons["startMode_normal"], pomo=app.buttons["startMode_pomodoro"], countdown=app.buttons["startMode_countdown"]
        XCTAssertTrue(normal.waitForExistence(timeout:3));XCTAssertTrue(pomo.exists);XCTAssertTrue(countdown.exists)
        attach(app,"Three modes in an arch")
        XCTAssertEqual(normal.label,"計測")
        XCTAssertEqual(countdown.label,"タイマー")
        XCTAssertLessThan(pomo.frame.midY,normal.frame.midY)
        XCTAssertLessThan(pomo.frame.midY,countdown.frame.midY)
        app.buttons["startWork"].tap()
        XCTAssertFalse(normal.isHittable)
        app.buttons["startWork"].tap()
        // Select immediately, while the options are still flying into place.
        app.buttons["startMode_normal"].tap()
        XCTAssertTrue(app.buttons["pauseResume"].waitForExistence(timeout:3))
        let background=app.buttons["世界の操作を表示・非表示"]
        background.tap()
        XCTAssertFalse(app.buttons["pauseResume"].isHittable)
        XCTAssertTrue(app.staticTexts["elapsedTime"].exists)
        XCTAssertEqual(app.staticTexts["sessionStatus"].label,"作業中")
        attach(app,"Clock remains visible with controls hidden")
        background.tap()
        app.buttons["pauseResume"].tap()
        XCTAssertTrue(app.staticTexts["一時停止中"].waitForExistence(timeout:3))
        background.tap()
        XCTAssertTrue(app.staticTexts["elapsedTime"].exists)
        XCTAssertEqual(app.staticTexts["sessionStatus"].label,"一時停止中")
        background.tap()
        app.buttons["finishWork"].tap()
        XCTAssertTrue(app.buttons["confirmTime"].waitForExistence(timeout:3))
    }
    func testCountdownSetupAndStart() {
        let app=launch()
        app.buttons["startWork"].tap()
        app.buttons["startMode_countdown"].tap()
        XCTAssertTrue(app.buttons["startTimedWork"].waitForExistence(timeout:3))
        app.buttons["countdownPreset_15"].tap()
        attach(app,"Countdown duration setup")
        app.buttons["startTimedWork"].tap()
        XCTAssertTrue(app.staticTexts["sessionMode"].waitForExistence(timeout:3))
        XCTAssertEqual(app.staticTexts["sessionMode"].label,"タイマー")
        XCTAssertTrue(app.buttons["pauseResume"].exists)
    }
    func testPomodoroSetupAndStart() {
        let app=launch()
        app.buttons["startWork"].tap()
        app.buttons["startMode_pomodoro"].tap()
        XCTAssertTrue(app.buttons["startTimedWork"].waitForExistence(timeout:3))
        XCTAssertEqual(app.pickerWheels.count,3)
        app.pickerWheels.element(boundBy:0).adjust(toPickerWheelValue:"30分")
        XCTAssertEqual(app.buttons["startTimedWork"].label,"30分の作業をはじめる")
        attach(app,"Pomodoro setup")
        app.buttons["startTimedWork"].tap()
        XCTAssertTrue(app.staticTexts["sessionMode"].waitForExistence(timeout:3))
        XCTAssertTrue(app.staticTexts["sessionMode"].label.contains("ポモドーロ"))
        attach(app,"Pomodoro working clock")
    }
    func testLongPressSlideReleaseChoosesCountdown() {
        let app=launch()
        // Read the actual laid-out button center, close, and use the same position
        // for a single uninterrupted long-press/drag/release gesture.
        app.buttons["startWork"].tap()
        let option=app.buttons["startMode_countdown"]
        XCTAssertTrue(option.waitForExistence(timeout:3))
        let point=CGPoint(x:option.frame.midX,y:option.frame.midY)
        app.buttons["startWork"].tap()
        let target=app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:point.x,dy:point.y))
        app.buttons["startWork"].coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).press(forDuration:0.5,thenDragTo:target)
        XCTAssertTrue(app.buttons["startTimedWork"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["countdownDuration"].exists)
        attach(app,"Long press slide release selection")
    }
}
