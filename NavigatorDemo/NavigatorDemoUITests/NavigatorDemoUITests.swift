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
    app/*@START_MENU_TOKEN@*/.menuBarItems["File"]/*[[".menuBarItems",".containing(.menuItem, identifier: \"Open Recent\")",".containing(.menuItem, identifier: \"openDocument:\")",".containing(.menuItem, identifier: \"newDocument:\")",".menuBars.menuBarItems[\"File\"]",".menuBarItems[\"File\"]"],[[[-1,5],[-1,4],[-1,0,1]],[[-1,3],[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.firstMatch.click()
    app/*@START_MENU_TOKEN@*/.menuItems["newDocument:"]/*[[".menus",".menuItems[\"New\"]",".menuItems[\"newDocument:\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.firstMatch.click()

    XCTAssertTrue(app.staticTexts["Untitled"].waitForExistence(timeout: 3), "Untitled document exists")

    app/*@START_MENU_TOKEN@*/.buttons["MyText.txt"]/*[[".cells.buttons[\"MyText.txt\"]",".buttons[\"MyText.txt\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.firstMatch.click()
    app/*@START_MENU_TOKEN@*/.outlines["Sidebar"].firstMatch/*[[".scrollViews.outlines[\"Sidebar\"].firstMatch",".outlines",".containing(.outlineRow, identifier: nil).firstMatch",".firstMatch",".outlines[\"Sidebar\"].firstMatch"],[[[-1,4],[-1,1,1],[-1,0]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.typeKey("q", modifierFlags:.command)
  }

//    @MainActor
//    func testLaunchPerformance() throws {
//        // This measures how long it takes to launch your application.
//        measure(metrics: [XCTApplicationLaunchMetric()]) {
//            XCUIApplication().launch()
//        }
//    }
}
