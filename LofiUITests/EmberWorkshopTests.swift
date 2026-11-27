import XCTest

final class EmberWorkshopTests: XCTestCase {
    func testFiveRankPreviewsAndNoStoryEntry() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--preview-world=ember-workshop", "--preview-rank=5", "--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["startWork"].waitForExistence(timeout: 10))
        let work = XCTAttachment(screenshot: app.screenshot())
        work.name = "Ember workshop work canvas"; work.lifetime = .keepAlways; add(work)
        app.buttons["tab_コレクション"].tap()
        let collection = app.buttons["collection_ember-workshop"]
        XCTAssertTrue(collection.waitForExistence(timeout: 5))
        collection.tap()
        XCTAssertTrue(app.buttons["useCollectionScene"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["readCollectionStory"].exists)
        for rank in 1...5 {
            app.buttons["ランク\(rank)を表示"].tap()
            XCTAssertTrue(app.buttons["collectionRank_\(rank)"].isSelected)
            XCTAssertTrue(app.otherElements["collectionDetailArtwork"].exists)
        }
        let detail = XCTAttachment(screenshot: app.screenshot())
        detail.name = "Storyless ember workshop collection"; detail.lifetime = .keepAlways; add(detail)
        app.buttons["collectionSoundSettings"].tap()
        XCTAssertTrue(app.buttons["toggleSound_embers"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["toggleSound_clockwork"].exists)
        XCTAssertFalse(app.buttons["toggleSound_brush"].exists)
        XCTAssertFalse(app.buttons["toggleSound_rain"].exists)
        let sounds = XCTAttachment(screenshot: app.screenshot())
        sounds.name = "Ember workshop sound settings"; sounds.lifetime = .keepAlways; add(sounds)
        app.buttons["閉じる"].tap()
        app.buttons["useCollectionScene"].tap()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: app.buttons["startWork"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        app.buttons["startWork"].tap()
        XCTAssertTrue(app.buttons["startMode_normal"].waitForExistence(timeout: 5))
        app.buttons["startMode_normal"].tap()
        XCTAssertTrue(app.buttons["finishWork"].waitForExistence(timeout: 5))
        app.buttons["finishWork"].tap()
        XCTAssertTrue(app.buttons["confirmTime"].waitForExistence(timeout: 5))
        app.buttons["confirmTime"].tap()
        XCTAssertTrue(app.buttons["closeResult"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["resultStory"].exists)
        let result = XCTAttachment(screenshot: app.screenshot())
        result.name = "Ember workshop result without story"; result.lifetime = .keepAlways; add(result)
    }
}
