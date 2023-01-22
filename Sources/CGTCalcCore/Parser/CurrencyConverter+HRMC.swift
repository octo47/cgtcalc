import SwiftyXMLParser


//<?xml version="1.0"?>
//<exchangeRateMonthList Period="01/Oct/2021 to 31/Oct/2021">
//  <exchangeRate>
//    <countryName>USA</countryName>
//    <countryCode>US</countryCode>
//    <currencyName>Dollar </currencyName>
//    <currencyCode>USD</currencyCode>
//    <rateNew>1.3646</rateNew>
//  </exchangeRate>
//  <exchangeRate>
//    <countryName>USA</countryName>
//    <countryCode>US</countryCode>
//    <currencyName>Dollar </currencyName>
//    <currencyCode>USD</currencyCode>
//    <rateNew>1.3646</rateNew>
//  </exchangeRate>
//</exchangeRateMonthList>

import Foundation

extension DefaultCurrencyConverter {
  
  static let symbolMap: [String: String] = [
    "€": "EUR",
    "$": "USD"
  ]
  
  public static func loadHRMC(logger: Logger, path: URL) throws -> DefaultCurrencyConverter {
    let tables = try symbolMap.map {
      try DefaultCurrencyTable.loadHRMCXML(symbol: $0.key, name: $0.value, path: path)
    }
    return DefaultCurrencyConverter(
      logger: logger,
      defaultCurrency: "£",
      currencies: tables)
  }
  
}

extension DefaultCurrencyTable {
  public static func loadHRMCXML(symbol: String, name: String, path: URL) throws -> DefaultCurrencyTable {
    
    let fm = FileManager.default

    let items = try fm.contentsOfDirectory(atPath: path.path)

    var events: [CurrencyEvent] = []
    for item in items {
      let xml = try XML.parse(String(contentsOf: path.appendingPathComponent(item)))
      let exchangeRateMonthList = xml.exchangeRateMonthList
      let (from, _) = try DefaultCurrencyTable.parsePeriod(periodStr: exchangeRateMonthList.attributes["Period"]!)
      exchangeRateMonthList.exchangeRate.forEach { elem in
        if elem.countryCode.text == name || elem.currencyCode.text == name {
          // HRCM files contain rate: symbol -> Pound,
          // so for our conversion rates from dollars to pounds we need to take 1/X
          // for example:
          //   rate in file for USD is 1.34.
          events.append(CurrencyEvent(date: from, rate: 1/Decimal(elem.rateNew.double!)))
        }
      }
    }
    return DefaultCurrencyTable(symbol: symbol, table: events)
  }
  
  // parse Period in HRMC xml:"01/Oct/2021 to 31/Oct/2021"
  static func parsePeriod(periodStr: String) throws -> (Date, Date) {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    dateFormatter.dateFormat = "dd/MMM/yyyy"

    let strippedData = periodStr.trimmingCharacters(in: .whitespaces)
    let splitData = strippedData.components(separatedBy: .whitespaces).filter { $0.count > 0 }
    
    guard let from = dateFormatter.date(from: splitData[0]) else {
      throw ParserError.InvalidDate(periodStr)
    }
    guard let to = dateFormatter.date(from: splitData[2]) else {
      throw ParserError.InvalidDate(periodStr)
    }
    
    return (from, Calendar.current.date(byAdding: .day, value: 1, to: to)!)
  }
}

