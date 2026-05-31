import XCTest
@testable import CodexControl

final class AccountIdentityTests: XCTestCase {
    func testMatchesKeepsDifferentProviderAccountsSeparate() {
        let createdAt = Date(timeIntervalSince1970: 1_766_534_400)
        let first = StoredAccount(
            id: UUID(),
            nickname: nil,
            emailHint: "user@example.com",
            authSubject: "auth0|same-user",
            providerAccountID: "account-1",
            codexHomePath: "/tmp/a",
            source: .managedByApp,
            createdAt: createdAt,
            updatedAt: createdAt)
        let second = StoredAccount(
            id: UUID(),
            nickname: nil,
            emailHint: "user@example.com",
            authSubject: "auth0|same-user",
            providerAccountID: "account-2",
            codexHomePath: "/tmp/b",
            source: .managedByApp,
            createdAt: createdAt,
            updatedAt: createdAt)

        XCTAssertFalse(first.matches(second))
    }

    func testRemovedIdentityMatchesProviderNotSharedEmail() {
        let createdAt = Date(timeIntervalSince1970: 1_766_534_400)
        let removedAccount = StoredAccount(
            id: UUID(),
            nickname: nil,
            emailHint: "user@example.com",
            authSubject: "auth0|same-user",
            providerAccountID: "account-1",
            codexHomePath: "/tmp/a",
            source: .managedByApp,
            createdAt: createdAt,
            updatedAt: createdAt)
        let otherAccount = StoredAccount(
            id: UUID(),
            nickname: nil,
            emailHint: "user@example.com",
            authSubject: "auth0|same-user",
            providerAccountID: "account-2",
            codexHomePath: "/tmp/b",
            source: .managedByApp,
            createdAt: createdAt,
            updatedAt: createdAt)

        let removed = RemovedAccountIdentity(account: removedAccount, removedAt: createdAt)

        XCTAssertTrue(removed.matches(removedAccount))
        XCTAssertFalse(removed.matches(otherAccount))
    }
}
