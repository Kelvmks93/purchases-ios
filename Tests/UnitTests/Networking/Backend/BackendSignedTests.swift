//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  BackendPostAttributionDataTests.swift
//
//  Created by Nacho Soto on 3/7/22.

import Foundation
import Nimble
import XCTest

@testable import RevenueCat

class BackendSignedTests: BaseBackendTests {

    override func createClient() -> MockHTTPClient {
        super.createClient(#file)
    }

    func testRequestContainsSignatureHeader() throws {
        self.httpClient.mock(
            requestPath: .health,
            response: .init(statusCode: .success)
        )

        let error = waitUntilValue { completed in
            self.internalAPI.healthRequest(signed: true, completion: completed)
        }

        expect(error).to(beNil())
    }

}
