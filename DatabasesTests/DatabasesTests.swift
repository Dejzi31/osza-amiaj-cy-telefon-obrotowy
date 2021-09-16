// Copyright (c) 2017-2018 Coinbase Inc. See LICENSE

import BigInt
@testable import CBDatabase
import RxBlocking
import XCTest

let unitTestsTimeout: TimeInterval = 3

class DatabasesTests: XCTestCase {
    let dbURL = Bundle(for: DatabasesTests.self).url(forResource: "TestDatabase", withExtension: "momd")!

    func testEmptyCount() throws {
        let database = Database(type: .memory, modelURL: dbURL)
        let count = try database.count(for: TestCurrency.self).toBlocking(timeout: unitTestsTimeout).single()
        XCTAssertEqual(0, count)
    }

    func testCountWithRecords() throws {
        let database = Database(type: .memory, modelURL: dbURL)

        var count = try database.count(for: TestCurrency.self).toBlocking(timeout: unitTestsTimeout).single()
        XCTAssertEqual(0, count)

        let currencies = [
            TestCurrency(code: "JTC", name: "JOHNNYCOIN"),
            TestCurrency(code: "ATC", name: "ANDREWCOIN"),
            TestCurrency(code: "HTC", name: "HISHCOIN"),
        ]

        _ = try database.add(currencies).toBlocking(timeout: unitTestsTimeout).single()
        count = try database.count(for: TestCurrency.self).toBlocking(timeout: unitTestsTimeout).single()

        XCTAssertEqual(currencies.count, count)
    }

    func testDataTypeWrapper() throws {
        let database = Database(type: .sqlite(nil), modelURL: dbURL)
        let expectedWallet = TestWallet(id: UUID().uuidString, name: "wallet 1", balance: BigInt(420))

        _ = try database.add(expectedWallet).toBlocking(timeout: unitTestsTimeout).single()

        let predicate = NSPredicate(format: "id == [c] %@", expectedWallet.id)
        let actualWallet: TestWallet? = try database.fetchOne(predicate: predicate)
            .toBlocking(timeout: unitTestsTimeout)
            .single()

        XCTAssertNotNil(actualWallet)
        XCTAssertEqual(expectedWallet.id, actualWallet?.id)
        XCTAssertEqual(expectedWallet.name, actualWallet?.name)
        XCTAssertEqual(expectedWallet.balance, actualWallet?.balance)

        let expectedWallet2 = TestWallet(id: expectedWallet.id, name: "wallet 1", balance: BigInt(120))
        _ = try database.addOrUpdate(expectedWallet2).toBlocking(timeout: unitTestsTimeout).single()

        let actualWallet2: TestWallet? = try database.fetchOne(predicate: predicate)
            .toBlocking(timeout: unitTestsTimeout)
            .single()

        XCTAssertNotNil(actualWallet)
        XCTAssertEqual(expectedWallet2.id, actualWallet2?.id)
        XCTAssertEqual(expectedWallet2.name, actualWallet2?.name)
        XCTAssertEqual(expectedWallet2.balance, actualWallet2?.balance)
    }
}

struct TestCurrency: DatabaseModelObject {
    let id: String
    let code: String
    let name: String
    var hashValue: Int {
        return id.hashValue
    }

    init(code: String, name: String) {
        self.code = code
        self.name = name
        id = code.lowercased()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let code = try container.decode(String.self, forKey: .code)
        let name = try container.decode(String.self, forKey: .name)
        self.init(code: code, name: name)
    }

    public static func == (lhs: TestCurrency, rhs: TestCurrency) -> Bool {
        return lhs.id == rhs.id
    }
}

struct TestWallet: IdentifiableDatabaseModelObject {
    let id: String
    let name: String?
    let balance: BigInt
}

public final class TestBigIntDBWrapper: NSObject, DBDataTypeWrapper {
    private let model: BigInt

    public var asModel: Any? { return model }

    public required init?(model: Any) {
        guard let bigIntModel = model as? BigInt else { return nil }
        self.model = bigIntModel
    }

    public required init?(coder aDecoder: NSCoder) {
        guard
            let value = aDecoder.decodeObject(forKey: "model") as? String,
            let model = BigInt(value)
        else { return nil }

        self.model = model
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(String(model), forKey: "model")
    }

    public func isEqual(to otherWrapper: Any) -> Bool {
        guard let otherWrapper = otherWrapper as? TestBigIntDBWrapper else { return false }
        return model == otherWrapper.model
    }
}
