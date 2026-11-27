import XCTest
@testable import Lofi

final class TimerTests: XCTestCase {
    private let start=Date(timeIntervalSince1970: 1000)
    func testLegacySessionWithoutTimerKeysRestoresAsStopwatch() throws {
        var session=FocusSession(now: start, interval: 1800)
        session.pause(at: start.addingTimeInterval(90))
        var object=try JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as! [String:Any]
        object.removeValue(forKey:"mode"); object.removeValue(forKey:"timerSettings")
        let restored=try JSONDecoder().decode(FocusSession.self,from: JSONSerialization.data(withJSONObject:object))
        XCTAssertEqual(restored.selectedMode,.normal)
        XCTAssertEqual(restored.elapsed(at:start.addingTimeInterval(500)),90)
    }
    func testPomodoroBoundariesAndLongBreakExcludeAllRestTime() {
        var s=FocusSession(now:start,interval:1800)
        s.mode = .pomodoro
        s.timerSettings=FocusTimerSettings(focusMinutes:1,shortBreakMinutes:1,longBreakMinutes:2)
        let fixtures:[(Double,Double,TimerPeriod,Double,Int)]=[
            (59,59,.focus,1,1),(60,60,.shortBreak,60,1),(119,60,.shortBreak,1,1),
            (120,60,.focus,60,2),(420,240,.longBreak,120,4),
            (539,240,.longBreak,1,4),(540,240,.focus,60,5),
            (600,300,.shortBreak,60,5),(86400,38400,.focus,60,641)
        ]
        for (time,work,period,left,round) in fixtures {
            let r=s.reading(at:start.addingTimeInterval(time))
            XCTAssertEqual(r.focusSeconds,work,"t=\(time)")
            XCTAssertEqual(r.period,period,"t=\(time)")
            XCTAssertEqual(r.remaining,left,"t=\(time)")
            XCTAssertEqual(r.round,round,"t=\(time)")
        }
        s.pause(at:start.addingTimeInterval(80))
        XCTAssertEqual(s.activeElapsed(at:start.addingTimeInterval(900)),80)
        XCTAssertEqual(s.elapsed(at:start.addingTimeInterval(900)),60)
        s.resume(at:start.addingTimeInterval(1000))
        XCTAssertEqual(s.reading(at:start.addingTimeInterval(1040)).period,.focus)
        XCTAssertEqual(s.reading(at:start.addingTimeInterval(1040)).round,2)
    }
    func testNotificationBoundariesRespectPauseAndCurrentRound() {
        var s=FocusSession(now:start,interval:1800)
        s.mode = .pomodoro
        s.timerSettings=FocusTimerSettings(focusMinutes:1,shortBreakMinutes:1,longBreakMinutes:2)
        XCTAssertEqual(s.timerEvents(at:start,limit:8).map(\.after),[60,120,180,240,300,360,420,540])
        XCTAssertTrue(s.timerEvents(at:start,limit:8)[6].body.contains("2分"))
        XCTAssertEqual(s.timerEvents(at:start.addingTimeInterval(480),limit:2).map(\.after),[60,120])
        s.pause(at:start.addingTimeInterval(480))
        XCTAssertTrue(s.timerEvents(at:start.addingTimeInterval(900)).isEmpty)
        s.mode = .countdown
        s.phase = .running
        s.resumedAt=start.addingTimeInterval(900)
        s.accumulated=0
        XCTAssertEqual(s.timerEvents(at:start.addingTimeInterval(950)).first?.after,1450)
    }
    @MainActor func testCountdownPausesCompletesOnceAndCapsLateRestoration() {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        let store=FocusStore(persistenceURL:url,startTimer:false)
        store.setConfirmation(.everySession)
        store.start(mode:.countdown,settings:FocusTimerSettings(countdownMinutes:5),at:start)
        store.pause(at:start.addingTimeInterval(65))
        store.tick(at:start.addingTimeInterval(500))
        XCTAssertEqual(store.elapsed,65)
        XCTAssertEqual(store.clockSeconds,235)
        store.resume(at:start.addingTimeInterval(500))
        let restored=FocusStore(persistenceURL:url,startTimer:false)
        restored.isForeground=false
        restored.tick(at:start.addingTimeInterval(20000))
        XCTAssertEqual(restored.elapsed,300)
        XCTAssertFalse(restored.needsReview)
        restored.isForeground=true
        restored.tick(at:start.addingTimeInterval(20001))
        XCTAssertTrue(restored.needsReview)
        XCTAssertFalse(restored.canResume)
        XCTAssertEqual(restored.elapsed,300)
        XCTAssertEqual(restored.clockSeconds,0)
        restored.commit(deducting:60)
        restored.tick(at:start.addingTimeInterval(30000))
        XCTAssertEqual(restored.data.records.count,1)
        XCTAssertEqual(restored.data.records.first?.seconds,240)
        XCTAssertEqual(restored.data.records.first?.mode,.countdown)
    }
    @MainActor func testPomodoroPersistsDuringBreakAndCreditsOnlyWork() {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        let store=FocusStore(persistenceURL:url,startTimer:false)
        store.setConfirmation(.everySession)
        XCTAssertTrue(store.useWorld(.shrine))
        store.start(mode:.pomodoro,settings:FocusTimerSettings(focusMinutes:1,shortBreakMinutes:1,longBreakMinutes:2),at:start)
        store.tick(at:start.addingTimeInterval(480))
        XCTAssertTrue(store.isOnBreak)
        XCTAssertEqual(store.previewGrowth,240)
        store.pause(at:start.addingTimeInterval(480))
        let restored=FocusStore(persistenceURL:url,startTimer:false)
        restored.tick(at:start.addingTimeInterval(5000))
        XCTAssertTrue(restored.isPaused)
        XCTAssertTrue(restored.isOnBreak)
        XCTAssertEqual(restored.clockSeconds,60)
        XCTAssertEqual(restored.elapsed,240)
        restored.resume(at:start.addingTimeInterval(5000))
        restored.requestFinish(at:start.addingTimeInterval(5060))
        restored.commit(deducting:0)
        XCTAssertEqual(restored.data.records.first?.seconds,240)
        XCTAssertEqual(restored.data.progress(for:.shrine).growthSeconds,240)
        XCTAssertEqual(restored.data.growthSeconds,0)
        XCTAssertEqual(restored.data.records.first?.mode,.pomodoro)
    }
    func testArcHitTestingUsesTheSameVisibleButtonPositions() {
        for width in [CGFloat(276),331,520,800] {
            for compact in [false,true] {
                let layout=StartModeLayout(width:width,compact:compact)
                for mode in FocusMode.allCases {
                    let center=layout.center(for:mode)
                    XCTAssertEqual(layout.hitTest(center),mode)
                    XCTAssertGreaterThanOrEqual(center.x-49,0)
                    XCTAssertLessThanOrEqual(center.x+49,width)
                }
                XCTAssertNil(layout.hitTest(layout.origin))
                XCTAssertNil(layout.hitTest(CGPoint(x:-200,y:-200)))
                XCTAssertLessThan(layout.center(for:.pomodoro).y,layout.center(for:.normal).y)
            }
        }
    }
}
