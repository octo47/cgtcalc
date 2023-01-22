//
//  File.swift
//  
//
//  Created by Andrey Stepachev on 22/01/2023.
//

import Foundation

public protocol CurrencyConverter {
  func convertCurrency(date: Date, string: String) throws -> Decimal?
}

public class DefaultCurrencyConverter: CurrencyConverter {
  
  private let logger: Logger
  private let defaultCurrency: String
  private let currencies: [String: CurrencyTable]
  
  public init(logger: Logger, defaultCurrency: String = "£", currencies: [CurrencyTable] = []) {
    self.logger = logger
    self.defaultCurrency = defaultCurrency
    self.currencies = Dictionary(uniqueKeysWithValues: currencies.map{($0.symbol, $0)})
  }
  
  public func convertCurrency(date: Date, string: String) throws -> Decimal? {
    let valueString = string.filter {
      CharacterSet(charactersIn: "0123456789.,").isSuperset(of: CharacterSet(charactersIn: String($0)))
    }.trimmingCharacters(in: .whitespacesAndNewlines)
    
    guard let decimal = Decimal(string: valueString) else {
      return nil
    }
    
    let symbol = string.replacingOccurrences(of: valueString, with: "")
    if symbol != "" && symbol != defaultCurrency {
      guard let table = currencies[symbol] else {
        throw ParserError.UnknownCurrency(symbol)
      }
      let converted = table.convert(at: date, from: decimal)
      logger.debug("Converted: \(date): \(string) -> \(String(describing: converted)) using \(table.symbol)")
      return converted
    } else  {
      return decimal
    }
  }
}



/// CurrencyTable holds events of currency conversions from `symbol` to `defaultCurrency`
public protocol CurrencyTable {
  
  
  /// Symbol this currency table supports convesion for
  var symbol: String {
    get
  }
  
  /// convert will find the rate on a date and convert value
  /// note: for any date `t` table should contain t-1 and t+1 and converter will take t-1 rate
  ///  if no t+1 found, convert will return nil
  func convert(at date: Date, from: Decimal) -> Decimal?
}

public struct CurrencyEvent {
  /// date of the conversion
  public let date: Date
  /// rate holds conversion of the currency in the table to default currency
  public let rate: Decimal
  
  public init(date: Date, rate: Decimal) {
    self.date = date
    self.rate = rate
  }
}

public class DefaultCurrencyTable: CurrencyTable {
  
  public let symbol: String
  
  internal let table: [CurrencyEvent]
  
  public func convert(at date: Date, from: Decimal) -> Decimal? {
    let lastDate = table.last { el in
      el.date <= date
    }
    return lastDate.map { $0.rate * from }
  }
  
  init(symbol: String, table: [CurrencyEvent]) {
    self.symbol = symbol
    self.table = table.sorted { a, b in a.date < b.date }
  }
}


extension DefaultCurrencyTable {
  public static func load(symbol: String, fromData data: String) throws -> DefaultCurrencyTable {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    dateFormatter.dateFormat = "dd/MM/yyyy"
    
    var events: [CurrencyEvent] = []
    try data
      .split { $0.isNewline }
      .forEach { rowData in
        guard rowData.count > 0, rowData.first != "#" else {
          return
        }
        
        let strippedData = data.trimmingCharacters(in: .whitespaces)
        let splitData = strippedData.components(separatedBy: .whitespaces).filter { $0.count > 0 }
        
        guard splitData.count == 2 else {
          throw ParserError.IncorrectNumberOfFields(String(data))
        }
        
        guard let date = dateFormatter.date(from: splitData[0]) else {
          throw ParserError.InvalidDate(String(data))
        }
        guard let rate = Decimal(string: splitData[1]) else {
          throw ParserError.InvalidValue(String(data))
        }
        events.append(CurrencyEvent(date: date, rate: rate))
      }
    return DefaultCurrencyTable(symbol: symbol, table: events)
  }
}
