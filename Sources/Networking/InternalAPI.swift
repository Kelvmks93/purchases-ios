//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  InternalAPI.swift
//
//  Created by Nacho Soto on 10/5/22.

import Foundation

final class InternalAPI {

    typealias ResponseHandler = (BackendError?) -> Void

    private let backendConfig: BackendConfiguration
    private let callbackCache: CallbackCache<HealthOperation.Callback>

    init(backendConfig: BackendConfiguration) {
        self.backendConfig = backendConfig
        self.callbackCache = .init()
    }

    func healthRequest(signed: Bool, completion: @escaping ResponseHandler) {
        let factory = HealthOperation.createFactory(httpClient: self.backendConfig.httpClient,
                                                    callbackCache: self.callbackCache,
                                                    signed: signed)

        let callback = HealthOperation.Callback(cacheKey: factory.cacheKey, completion: completion)
        let cacheStatus = self.callbackCache.add(callback)

        self.backendConfig.addCacheableOperation(with: factory,
                                                 withRandomDelay: false,
                                                 cacheStatus: cacheStatus)
    }

}

// MARK: - Health

private final class HealthOperation: CacheableNetworkOperation {

    struct Callback: CacheKeyProviding {

        let cacheKey: String
        let completion: InternalAPI.ResponseHandler

    }

    struct Configuration: NetworkConfiguration {

        let httpClient: HTTPClient

    }

    private let callbackCache: CallbackCache<Callback>
    private let signed: Bool

    static func createFactory(
        httpClient: HTTPClient,
        callbackCache: CallbackCache<Callback>,
        signed: Bool
    ) -> CacheableNetworkOperationFactory<HealthOperation> {
        return .init({ .init(httpClient: httpClient, callbackCache: callbackCache, cacheKey: $0, signed: signed) },
                     individualizedCacheKeyPart: "")
    }

    private init(httpClient: HTTPClient,
                 callbackCache: CallbackCache<Callback>,
                 cacheKey: String,
                 signed: Bool) {
        self.callbackCache = callbackCache
        self.signed = signed

        super.init(configuration: Configuration(httpClient: httpClient), cacheKey: cacheKey)
    }

    override func begin(completion: @escaping () -> Void) {
        let request: HTTPRequest = self.signed
            ? .createSignedRequest(method: .get, path: .health)
            : .init(method: .get, path: .health)

        self.httpClient.perform(request) { (response: HTTPResponse<HTTPEmptyResponseBody>.Result) in
            self.callbackCache.performOnAllItemsAndRemoveFromCache(withCacheable: self) { callback in
                callback.completion(
                    response
                        .mapError(BackendError.networkError)
                        .error
                )
            }

            completion()
        }
    }

}
