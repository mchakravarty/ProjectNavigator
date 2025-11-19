//
//  NavigatorDemoUITests.swift
//  NavigatorDemoUITests
//
//  Created by Manuel M T Chakravarty on 18/11/2025.
//

import XCTest

final class NavigatorDemoUITests: XCTestCase {

  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.

    // In UI tests it is usually best to stop immediately when a failure occurs.
    continueAfterFailure = false

    // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  @MainActor
  func testNewDocument() throws {

    let app = XCUIApplication()
    app.activate()
    app.menuBarItems["File"].firstMatch.click()
    app.menuItems["newDocument:"].firstMatch.click()

    XCTAssertTrue(app.staticTexts["Untitled"].waitForExistence(timeout: 2), "Untitled document exists")

    app.buttons["MyText.txt"].firstMatch.click()

    app.outlines["Sidebar"].firstMatch.typeKey("q", modifierFlags:.command)
  }

  @MainActor
  func testNewFile() throws {
    let app = XCUIApplication()
    app.activate()
    app.menuBarItems["File"].firstMatch.click()
    app.menuItems["newDocument:"].firstMatch.click()

    _ = app.buttons["Untitled"].waitForExistence(timeout: 2)
    app.buttons["Untitled"].firstMatch.rightClick()
    app.menuItems["doc.badge.plus"].firstMatch.click()

    let element = app.cells.containing(.group, identifier: nil).firstMatch
    element.typeKey(.leftArrow, modifierFlags:.function)
    element.typeKey(.rightArrow, modifierFlags:[.shift, .function])
    element.typeKey(.rightArrow, modifierFlags:[.shift, .function])
    element.typeKey(.rightArrow, modifierFlags:[.shift, .function])
    element.typeKey(.rightArrow, modifierFlags:[.shift, .function])
    element.typeText("Test\r")

    XCTAssertTrue(app.buttons["Test.txt"].waitForExistence(timeout: 2), "Test.txt file exists")

    app.outlines["Sidebar"].firstMatch.typeKey("q", modifierFlags:.command)
  }

  @MainActor
  func testTwoNewFiles() throws {
    let app = XCUIApplication()
    app.activate()
    app.menuBarItems["File"].firstMatch.click()
    app.menuItems["newDocument:"].firstMatch.click()

    _ = app.buttons["Untitled"].waitForExistence(timeout: 2)
    app.buttons["Untitled"].firstMatch.rightClick()
    app.menuItems["doc.badge.plus"].firstMatch.click()

    app.buttons["Untitled"].firstMatch.rightClick()
    app.menuItems["doc.badge.plus"].firstMatch.click()

    app.cells.element(boundBy: 0).typeText("\r")
    XCTAssertTrue(app.buttons["Text1.txt"].waitForExistence(timeout: 2), "Text1.txt file exists")

    app.outlines["Sidebar"].firstMatch.typeKey("q", modifierFlags:.command)
  }

  @MainActor
  func testTwoNewDeleteOneFiles() throws {
    let app = XCUIApplication()
    app.activate()
    app.menuBarItems["File"].firstMatch.click()
    app.menuItems["newDocument:"].firstMatch.click()

    _ = app.buttons["Untitled"].waitForExistence(timeout: 2)
    app.buttons["Untitled"].firstMatch.rightClick()
    app.menuItems["doc.badge.plus"].firstMatch.click()

    app.buttons["Untitled"].firstMatch.rightClick()
    app.menuItems["doc.badge.plus"].firstMatch.click()

    app.cells.element(boundBy: 0).typeText("\r")
    XCTAssertTrue(app.buttons["Text1.txt"].waitForExistence(timeout: 2), "Text1.txt file exists")

    app.buttons["Untitled"].firstMatch.click()
    app.buttons["Text1.txt"].firstMatch.rightClick()
    app/*@START_MENU_TOKEN@*/.menuItems["trash"]/*[[".outlines.menuItems[\"Delete\"]",".menus.menuItems[\"trash\"]",".menuItems[\"trash\"]"],[[[-1,2],[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.firstMatch.click()

    XCTAssertTrue(app.buttons["Text1.txt"].waitForNonExistence(timeout: 3), "Text1.txt doesn't exist (anymore)")

    app.outlines["Sidebar"].firstMatch.typeKey("q", modifierFlags:.command)
  }

//    @MainActor
//    func testLaunchPerformance() throws {
//        // This measures how long it takes to launch your application.
//        measure(metrics: [XCTApplicationLaunchMetric()]) {
//            XCUIApplication().launch()
//        }
//    }
}
