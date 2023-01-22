//
//  CalculatorTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 09/06/2020.
//

@testable import CGTCalcCore
import XCTest

class CurrencyConverterTests: XCTestCase {
  let logger = StubLogger()

  
  func testBasicSingleAsset() throws {
    let exhangeRates = try inputs(testSet: "input1")
    let rates = try DefaultCurrencyConverter.loadHRMC(logger: BasicLogger(), path: exhangeRates)
    XCTAssertEqual(1.3406, try rates.convertCurrency(date: toDate("2018-01-15"), string: "$1.0"))
    XCTAssertEqual(1.3406, try rates.convertCurrency(date: toDate("2018-01-31"), string: "$1.0"))
    XCTAssertEqual(1.4223, try rates.convertCurrency(date: toDate("2018-02-01"), string: "$1.0"))
    XCTAssertEqual(1.3979, try rates.convertCurrency(date: toDate("2018-03-31"), string: "$1.0"))
  }
  
  // isoDate: 2016-04-14T10:44:00+0000
  func toDate(_ isoDate: String) -> Date {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    return dateFormatter.date(from: isoDate)!
  }
  
  func inputs(testSet: String) throws -> URL {
    let thisFile = URL(fileURLWithPath: #file)
    return thisFile.deletingLastPathComponent().appendingPathComponent("Exchange").appendingPathComponent(testSet)
  }
}
