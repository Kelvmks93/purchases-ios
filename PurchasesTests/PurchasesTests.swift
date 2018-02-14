//
//  PurchasesTests.swift
//  PurchasesTests
//
//  Created by Jacob Eiting on 9/28/17.
//  Copyright © 2017 Purchases. All rights reserved.
//

import XCTest
import Nimble

import Purchases

class MockTransaction: SKPaymentTransaction {

    var mockPayment: SKPayment?
    override var payment: SKPayment {
        get {
            return mockPayment!
        }
    }

    var mockState = SKPaymentTransactionState.purchasing
    override var transactionState: SKPaymentTransactionState {
        get {
            return mockState
        }
    }
}

class PurchasesTests: XCTestCase {

    class MockRequestFetcher: RCStoreKitRequestFetcher {
        var refreshReceiptCalled = false

        override func fetchProducts(_ identifiers: Set<String>, completion: @escaping RCFetchProductsCompletionHandler) {
            let products = identifiers.map { (identifier) -> MockProduct in
                MockProduct(mockProductIdentifier: identifier)
            }
            completion(products)
        }

        override func fetchReceiptData(_ completion: @escaping RCFetchReceiptCompletionHandler) {
            refreshReceiptCalled = true
            completion()
        }
    }

    class MockBackend: RCBackend {
        var userID: String?
        override func getSubscriberData(withAppUserID appUserID: String, completion: @escaping RCBackendResponseHandler) {
            userID = appUserID
            completion(RCPurchaserInfo(), nil)
        }

        var postReceiptDataCalled = false
        var postedIsRestore: Bool?
        var postedProductID: String?
        var postedPrice: NSDecimalNumber?
        var postedPaymentMode: RCPaymentMode?
        var postedIntroPrice: NSDecimalNumber?
        var postedCurrencyCode: String?
        var postReceiptPurchaserInfo: RCPurchaserInfo?
        var postReceiptError: Error?

        override func postReceiptData(_ data: Data, appUserID: String, isRestore: Bool, productIdentifier: String?, price: NSDecimalNumber?, paymentMode: RCPaymentMode, introductoryPrice: NSDecimalNumber?, currencyCode: String?, completion: @escaping RCBackendResponseHandler) {
            postReceiptDataCalled = true
            postedIsRestore = isRestore

            postedProductID  = productIdentifier
            postedPrice = price

            postedPaymentMode = paymentMode
            postedIntroPrice = introductoryPrice

            postedCurrencyCode = currencyCode

            completion(postReceiptPurchaserInfo, postReceiptError)
        }

        var postedProductIdentifiers: [String]?
        override func getIntroElgibility(forAppUserID appUserID: String, productIdentifiers: [String], completion: @escaping RCIntroEligibilityResponseHandler) {
            postedProductIdentifiers = productIdentifiers

            var eligibilities = [String: RCIntroEligibility]()
            for productID in productIdentifiers {
                eligibilities[productID] = RCIntroEligibility(eligibilityStatus: RCIntroEligibityStatus.eligible)
            }

            completion(eligibilities);
        }
    }

    class MockStoreKitWrapper: RCStoreKitWrapper {
        var payment: SKPayment?
        override func add(_ newPayment: SKPayment) {
            payment = newPayment
        }

        var finishCalled = false
        override func finish(_ transaction: SKPaymentTransaction) {
            finishCalled = true
        }

        var mockDelegate: RCStoreKitWrapperDelegate?
        override var delegate: RCStoreKitWrapperDelegate? {
            get {
                return mockDelegate
            }
            set {
                mockDelegate = newValue
            }
        }
    }

    class MockNotificationCenter: NotificationCenter {

        var observers = [(AnyObject, Selector, NSNotification.Name?, Any?)]();

        override func addObserver(_ observer: Any, selector
            aSelector: Selector, name aName: NSNotification.Name?, object anObject: Any?) {
            observers.append((observer as AnyObject, aSelector, aName, anObject))
        }

        override func removeObserver(_ anObserver: Any, name aName: NSNotification.Name?, object anObject: Any?) {
            observers = observers.filter {$0.0 !== anObserver as AnyObject || $0.2 != aName}
        }

        func fireNotifications() {
            for (observer, selector, _, _) in observers {
                _ = observer.perform(selector, with:nil);
            }
        }
    }

    class MockUserDefaults: UserDefaults {
        var appUserID: String?
        override func string(forKey defaultName: String) -> String? {
            return appUserID
        }

        override func set(_ value: Any?, forKey defaultName: String) {
            appUserID = value as! String?
        }
    }

    class PurchasesDelegate: RCPurchasesDelegate {
        var completedTransaction: SKPaymentTransaction?
        var purchaserInfo: RCPurchaserInfo?
        func purchases(_ purchases: RCPurchases, completedTransaction transaction: SKPaymentTransaction, withUpdatedInfo purchaserInfo: RCPurchaserInfo) {
            self.completedTransaction = transaction
            self.purchaserInfo = purchaserInfo
        }

        var failedTransaction: SKPaymentTransaction?
        func purchases(_ purchases: RCPurchases, failedTransaction transaction: SKPaymentTransaction, withReason failureReason: Error) {
            self.failedTransaction = transaction
        }

        func purchases(_ purchases: RCPurchases, receivedUpdatedPurchaserInfo purchaserInfo: RCPurchaserInfo) {
            self.purchaserInfo = purchaserInfo
        }

        var restoredPurchaserInfo: RCPurchaserInfo?
        func purchases(_ purchases: RCPurchases, restoredTransactionsWith purchaserInfo: RCPurchaserInfo) {
            restoredPurchaserInfo = purchaserInfo
        }

        var restoredError: Error?
        func purchases(_ purchases: RCPurchases, failedToRestoreTransactionsWithReason failureReason: Error) {
            restoredError = failureReason
        }
        
        var promoProduct: SKProduct?
        var shouldAddPromo = false
        var makeDeferredPurchase: RCDeferredPromotionalPurchaseBlock?
        func purchases(_ purchases: RCPurchases, shouldPurchasePromoProduct product: SKProduct, defermentBlock makeDeferredPurchase: @escaping RCDeferredPromotionalPurchaseBlock) -> Bool {
            promoProduct = product
            self.makeDeferredPurchase = makeDeferredPurchase
            return shouldAddPromo
        }
    }

    let requestFetcher = MockRequestFetcher()
    let backend = MockBackend()
    let storeKitWrapper = MockStoreKitWrapper()
    let notificationCenter = MockNotificationCenter();
    let userDefaults = MockUserDefaults();

    let purchasesDelegate = PurchasesDelegate()
    
    let appUserID = "app_user"

    var purchases: RCPurchases?

    func setupPurchases() {
        purchases = RCPurchases(appUserID: appUserID,
                                requestFetcher: requestFetcher,
                                backend:backend,
                                storeKitWrapper: storeKitWrapper,
                                notificationCenter:notificationCenter,
                                userDefaults:userDefaults)

        purchases!.delegate = purchasesDelegate
    }

    func setupAnonPurchases() {
        purchases = RCPurchases(appUserID: nil,
                                requestFetcher: requestFetcher,
                                backend:backend,
                                storeKitWrapper: storeKitWrapper,
                                notificationCenter:notificationCenter,
                                userDefaults:userDefaults)

        purchases!.delegate = purchasesDelegate
    }
    
    func testIsAbleToBeIntialized() {
        setupPurchases()
        expect(self.purchases).toNot(beNil())
    }

    func testIsAbleToFetchProducts() {
        setupPurchases()
        var products: [SKProduct]?
        let productIdentifiers = ["com.product.id1", "com.product.id2"]
        purchases!.products(withIdentifiers:productIdentifiers) { (newProducts) in
            products = newProducts
        }

        expect(products).toEventuallyNot(beNil())
        expect(products).toEventually(haveCount(productIdentifiers.count))
    }

    func testSetsSelfAsStoreKitWrapperDelegate() {
        setupPurchases()
        expect(self.storeKitWrapper.delegate).to(be(purchases))
    }

    func testAddsPaymentToWrapper() {
        setupPurchases()
        let product = MockProduct(mockProductIdentifier: "com.product.id1")
        self.purchases?.makePurchase(product)

        expect(self.storeKitWrapper.payment).toNot(beNil())
        expect(self.storeKitWrapper.payment?.productIdentifier).to(equal(product.productIdentifier))
    }

    func testTransitioningToPurchasing() {
        setupPurchases()
        let product = MockProduct(mockProductIdentifier: "com.product.id1")
        self.purchases?.makePurchase(product)

        let transaction = MockTransaction()
        transaction.mockPayment = self.storeKitWrapper.payment!
        transaction.mockState = SKPaymentTransactionState.purchasing

        self.storeKitWrapper.delegate?.storeKitWrapper(self.storeKitWrapper, updatedTransaction: transaction)

        expect(self.backend.postReceiptDataCalled).to(equal(false))
    }

    func testTransitioningToPurchasedSendsToBackend() {
        setupPurchases()
        let product = MockProduct(mockProductIdentifier: "com.product.id1")
        self.purchases?.makePurchase(product)

        let transaction = MockTransaction()
        transaction.mockPayment = self.storeKitWrapper.payment!

        transaction.mockState = SKPaymentTransactionState.purchasing
        self.storeKitWrapper.delegate?.storeKitWrapper(self.storeKitWrapper, updatedTransaction: transaction)

        transaction.mockState = SKPaymentTransactionState.purchased
        self.storeKitWrapper.delegate?.storeKitWrapper(self.storeKitWrapper, updatedTransaction: transaction)

        expect(self.backend.postReceiptDataCalled).to(equal(true))
        expect(self.backend.postedIsRestore).to(equal(false))
    }

    func testReceiptsSendsAsRestoreWhenAnon() {
        setupAnonPurchases()
        let product = MockProduct(mockProductIdentifier: "com.product.id1")
        self.purchases?.makePurchase(product)

        let transaction = MockTransaction()
        transaction.mockPayment = self.storeKitWrapper.payment!

        transaction.mockState = SKPaymentTransactionState.purchasing
        self.storeKitWrapper.delegate?.storeKitWrapper(self.storeKitWrapper, updatedTransaction: transaction)

        transaction.mockState = SKPaymentTransactionState.purchased
        self.storeKitWrapper.delegate?.storeKitWrapper(self.storeKitWrapper, updatedTransaction: transaction)

        expect(self.backend.postReceiptDataCalled).to(equal(true))
        expect(self.backend.postedIsRestore).to(equal(true))
    }

    func testFinishesTransactionsIfSentToBackendCorrectly() {
        setupPurchases()
        let product = MockProduct(mockProductIdentifier: "com.product.id1")
        self.purchases?.makePurchase(product)

        let transaction = MockTransaction()
        transaction.mockPayment = self.storeKitWrapper.payment!

        transaction.mockState = SKPaymentTransactionState.purchasing
        self.storeKitWrapper.delegate?.storeKitWrapper(self.storeKitWrapper, updatedTransaction: transaction)

        self.backend.postReceiptPurchaserInfo = RCPurchaserInfo()

        transaction.mockState = SKPaymentTransactionState.purchased
        self.storeKitWrapper.delegate?.storeKitWrapper(self.storeKitWrapper, updatedTransaction: transaction)

        expect(self.backend.postReceiptDataCalled).to(equal(true))
        expect(self.storeKitWrapper.finishCalled).to(beTrue())
    }
    

    func testSendsProductInfoIfProductIsCached() {
        setupPurchases()
        let productIdentifiers = ["com.product.id1", "com.product.id2"]
        purchases!.products(withIdentifiers:productIdentifiers) { (newProducts) in
            let product = newProducts[0];
            self.purchases?.makePurchase(product)
            
            let transaction = MockTransaction()
            transaction.mockPayment = self.storeKitWrapper.payment!
            
            transaction.mockState = SKPaymentTransactionState.purchasing
            self.storeKitWrapper.delegate?.storeKitWrapper(self.storeKitWrapper, updatedTransaction: transaction)
            
            self.backend.postReceiptPurchaserInfo = RCPurchaserInfo()
            
            transaction.mockState = SKPaymentTransactionState.purchased
            self.storeKitWrapper.delegate?.storeKitWrapper(self.storeKitWrapper, updatedTransaction: transaction)
            
            expect(self.backend.postReceiptDataCalled).to(equal(true))
            expect(self.backend.postReceiptData).toNot(beNil())

            expect(self.backend.postedProductID).to(equal(product.productIdentifier))
            expect(self.backend.postedPrice).to(equal(product.price))

            if #available(iOS 11.2, *) {
                expect(self.backend.postedPaymentMode).to(equal(RCPaymentMode.payAsYouGo))
                expect(self.backend.postedIntroPrice).to(equal(product.introductoryPrice?.price))
            } else {
                expect(self.backend.postedPaymentMode).to(equal(RCPaymentMode.none))
                expect(self.backend.postedIntroPrice).to(beNil())
            }
            
            expect(self.backend.postedCurrencyCode).to(equal(product.priceLocale.currencyCode))

            expect(self.storeKitWrapper.finishCalled).to(beTrue())
        }
    }
    
    func testDoesntSendProductInfoIfProductIsntCached() {
        setupPurchases()
        let product = MockProduct(mockProductIdentifier: "com.product.id1")
        self.purchases?.makePurchase(product)
        
        let transaction = MockTransaction()
        transaction.mockPayment = self.storeKitWrapper.payment!
        
        transaction.mockState = SKPaymentTransactionState.purchasing
        self.storeKitWrapper.delegate?.storeKitWrapper(self.storeKitWrapper, updatedTransaction: transaction)
        
        self.backend.postReceiptPurchaserInfo = RCPurchaserInfo()
        
        transaction.mockState = SKPaymentTransactionState.purchased
        self.storeKitWrapper.delegate?.storeKitWrapper(self.storeKitWrapper, updatedTransaction: transaction)
        

        expect(self.backend.postedProductID).to(beNil())
        expect(self.backend.postedPrice).to(beNil())
        expect(self.backend.postedIntroPrice).to(beNil())
        expect(self.backend.postedCurrencyCode).to(beNil())
    }
    
    enum BackendError: Error {
        case unknown
    }

    func testAfterSendingDoesntFinishTransactionIfBackendError() {
        setupPurchases()
        let product = MockProduct(mockProductIdentifier: "com.product.id1")
        self.purchases?.makePurchase(product)

        let transaction = MockTransaction()
        transaction.mockPayment = self.storeKitWrapper.payment!

        self.backend.postReceiptError = NSError(domain: "error_domain", code: RCUnfinishableError, userInfo: nil)

        transaction.mockState = SKPaymentTransactionState.purchased
        self.storeKitWrapper.delegate?.storeKitWrapper(self.storeKitWrapper, updatedTransaction: transaction)

        expect(self.backend.postReceiptDataCalled).to(equal(true))
        expect(self.storeKitWrapper.finishCalled).to(beFalse())
    }

    func testAfterSendingFinishesFromBackendErrorIfAppropriate() {
        setupPurchases()
        let product = MockProduct(mockProductIdentifier: "com.product.id1")
        self.purchases?.makePurchase(product)

        let transaction = MockTransaction()
        transaction.mockPayment = self.storeKitWrapper.payment!

        self.backend.postReceiptError = NSError(domain: "error_domain", code: RCFinishableError, userInfo: nil)

        transaction.mockState = SKPaymentTransactionState.purchased
        self.storeKitWrapper.delegate?.storeKitWrapper(self.storeKitWrapper, updatedTransaction: transaction)

        expect(self.backend.postReceiptDataCalled).to(equal(true))
        expect(self.storeKitWrapper.finishCalled).to(beTrue())
    }

    func testNotifiesIfTransactionFailsFromBackend() {
        setupPurchases()
        let product = MockProduct(mockProductIdentifier: "com.product.id1")
        self.purchases?.makePurchase(product)

        let transaction = MockTransaction()
        transaction.mockPayment = self.storeKitWrapper.payment!

        self.backend.postReceiptError = NSError(domain: "error_domain", code: RCUnfinishableError, userInfo: nil)

        transaction.mockState = SKPaymentTransactionState.purchased
        self.storeKitWrapper.delegate?.storeKitWrapper(self.storeKitWrapper, updatedTransaction: transaction)

        expect(self.backend.postReceiptDataCalled).to(equal(true))
        expect(self.storeKitWrapper.finishCalled).to(beFalse())
        expect(self.purchasesDelegate.failedTransaction).to(be(transaction))
    }

    func testNotifiesIfTransactionFailsFromStoreKit() {
        setupPurchases()
        let product = MockProduct(mockProductIdentifier: "com.product.id1")
        self.purchases?.makePurchase(product)

        let transaction = MockTransaction()
        transaction.mockPayment = self.storeKitWrapper.payment!

        self.backend.postReceiptError = BackendError.unknown

        transaction.mockState = SKPaymentTransactionState.failed
        self.storeKitWrapper.delegate?.storeKitWrapper(self.storeKitWrapper, updatedTransaction: transaction)

        expect(self.backend.postReceiptDataCalled).to(equal(false))
        expect(self.storeKitWrapper.finishCalled).to(beTrue())
        expect(self.purchasesDelegate.failedTransaction).to(be(transaction))
    }

    func testCallsDelegateAfterBackendResponse() {
        setupPurchases()
        let product = MockProduct(mockProductIdentifier: "com.product.id1")
        self.purchases?.makePurchase(product)

        let transaction = MockTransaction()
        transaction.mockPayment = self.storeKitWrapper.payment!

        self.backend.postReceiptPurchaserInfo = RCPurchaserInfo()

        transaction.mockState = SKPaymentTransactionState.purchased
        self.storeKitWrapper.delegate?.storeKitWrapper(self.storeKitWrapper, updatedTransaction: transaction)

        expect(self.purchasesDelegate.completedTransaction).to(be(transaction))
        expect(self.purchasesDelegate.purchaserInfo).to(be(self.backend.postReceiptPurchaserInfo))
    }

    func testDoesntIgnorePurchasesThatDoNotHaveApplicationUserNames() {
        setupPurchases()
        let transaction = MockTransaction()

        let payment = SKMutablePayment()

        expect(payment.applicationUsername).to(equal(""))

        transaction.mockPayment = payment
        transaction.mockState = SKPaymentTransactionState.purchased

        self.storeKitWrapper.delegate?.storeKitWrapper(self.storeKitWrapper, updatedTransaction: transaction)

        expect(self.backend.postReceiptDataCalled).to(equal(true))
    }

    func testDoesntSetWrapperDelegateUntilDelegateIsSet() {
        setupPurchases()
        purchases!.delegate = nil

        expect(self.storeKitWrapper.delegate).to(beNil())

        purchases!.delegate = purchasesDelegate

        expect(self.storeKitWrapper.delegate).toNot(beNil())
    }

    func testSubscribesToUIApplicationDidBecomeActive() {
        setupPurchases()
        expect(self.notificationCenter.observers.count).to(equal(1));
        if self.notificationCenter.observers.count > 0 {
            let (_, _, name, _) = self.notificationCenter.observers[0];
            expect(name).to(equal(NSNotification.Name.UIApplicationDidBecomeActive))
        }
    }

    func testTriggersCallToBackend() {
        setupPurchases()
        notificationCenter.fireNotifications();
        expect(self.backend.userID).toEventuallyNot(beNil());
    }

    func testAutomaticallyFetchesPurchaserInfoOnDidBecomeActive() {
        setupPurchases()
        notificationCenter.fireNotifications();
        expect(self.purchasesDelegate.purchaserInfo).toEventuallyNot(beNil());
    }

    func testRemovesObservationWhenDelegateNild() {
        setupPurchases()
        purchases!.delegate = nil

        expect(self.notificationCenter.observers.count).to(equal(0));
    }

    func testSettingDelegateUpdatesSubscriberInfo() {
        let purchases = RCPurchases(appUserID: appUserID,
                                    requestFetcher: requestFetcher,
                                    backend: backend,
                                    storeKitWrapper: storeKitWrapper,
                                    notificationCenter: notificationCenter,
                                    userDefaults: userDefaults)!
        purchases.delegate = nil

        purchasesDelegate.purchaserInfo = nil

        purchases.delegate = purchasesDelegate

        expect(self.purchasesDelegate.purchaserInfo).toEventuallyNot(beNil())
    }

    func testRestoringPurchasesPostsTheReceipt() {
        setupPurchases()
        purchases!.restoreTransactions { (_, _) in

        }
        expect(self.backend.postReceiptDataCalled).to(equal(true))
    }

    func testRestoringPurchasesRefreshesAndPostsTheReceipt() {
        setupPurchases()
        purchases!.restoreTransactions { (_, _) in

        }
        expect(self.requestFetcher.refreshReceiptCalled).to(equal(true))
    }

    func testRestoringPurchasesSetsIsRestore() {
        setupPurchases()
        purchases!.restoreTransactions { (_, _) in

        }
        expect(self.backend.postedIsRestore!).to(equal(true))
    }

    func testRestoringPurchasesSetsIsRestoreForAnon() {
        setupAnonPurchases()
        purchases!.restoreTransactions { (_, _) in

        }
        expect(self.backend.postedIsRestore!).to(equal(true))
    }

    func testRestoringPurchasesCallsSuccessDelegateMethod() {
        setupPurchases()
        let purchaserInfo = RCPurchaserInfo()
        self.backend.postReceiptPurchaserInfo = purchaserInfo

        var restoredPurchaserInfo: RCPurchaserInfo?

        purchases!.restoreTransactions { (newPurchaserInfo, _) in
            restoredPurchaserInfo = newPurchaserInfo
        }

        expect(restoredPurchaserInfo).toEventually(equal(purchaserInfo))
    }

    func testRestorePurchasesCallsFailureDelegateMethodOnFailure() {
        setupPurchases()
        let error = NSError(domain: "error_domain", code: RCFinishableError, userInfo: nil)
        self.backend.postReceiptError = error

        var restoredPurchaserInfo: RCPurchaserInfo?
        var restoreError: Error?

        purchases!.restoreTransactions { (newPurchaserInfo, newError) in
            restoredPurchaserInfo = newPurchaserInfo
            restoreError = newError
        }

        expect(restoredPurchaserInfo).toEventually(beNil())
        expect(restoreError).toEventuallyNot(beNil())
    }
    
    func testCallsShouldAddPromoPaymentDelegateMethod() {
        setupPurchases()
        let product = MockProduct(mockProductIdentifier: "mock_product")
        let payment = SKPayment.init()
        
        storeKitWrapper.delegate?.storeKitWrapper(storeKitWrapper, shouldAddStore: payment, for: product)
        
        expect(self.purchasesDelegate.promoProduct).to(be(product))
    }
    
    func testShouldAddPromoPaymentDelegateMethodPassesUpResult() {
        setupPurchases()
        let product = MockProduct(mockProductIdentifier: "mock_product")
        let payment = SKPayment.init()
        
        let randomBool = (arc4random() % 2 == 0) as Bool
        purchasesDelegate.shouldAddPromo = randomBool
        
        let result = storeKitWrapper.delegate?.storeKitWrapper(storeKitWrapper, shouldAddStore: payment, for: product)
        
        expect(randomBool).to(equal(result))
    }
    
    func testShouldCacheProductsFromPromoPaymentDelegateMethod() {
        setupPurchases()
        let product = MockProduct(mockProductIdentifier: "mock_product")
        let payment = SKPayment.init(product: product)
        
        storeKitWrapper.delegate?.storeKitWrapper(storeKitWrapper, shouldAddStore: payment, for: product)
        
        let transaction = MockTransaction()
        transaction.mockPayment = payment
        
        transaction.mockState = SKPaymentTransactionState.purchasing
        self.storeKitWrapper.delegate?.storeKitWrapper(self.storeKitWrapper, updatedTransaction: transaction)
        
        transaction.mockState = SKPaymentTransactionState.purchased
        self.storeKitWrapper.delegate?.storeKitWrapper(self.storeKitWrapper, updatedTransaction: transaction)
        
        expect(self.backend.postReceiptDataCalled).to(equal(true))
        expect(self.backend.postedProductID).to(equal(product.productIdentifier))
        expect(self.backend.postedPrice).to(equal(product.price))
    }
    
    func testDeferBlockMakesPayment() {
        setupPurchases()
        let product = MockProduct(mockProductIdentifier: "mock_product")
        let payment = SKPayment.init(product: product)
        
        purchasesDelegate.shouldAddPromo = false
        storeKitWrapper.delegate?.storeKitWrapper(storeKitWrapper, shouldAddStore: payment, for: product)
        
        expect(self.purchasesDelegate.makeDeferredPurchase).toNot(beNil())
        
        expect(self.storeKitWrapper.payment).to(beNil())
        
        self.purchasesDelegate.makeDeferredPurchase!()
        
        expect(self.storeKitWrapper.payment).to(be(payment))
    }

    func testGetUpdatedPurchaserInfo() {
        setupPurchases()
        var purchaserInfo: RCPurchaserInfo?
        purchases!.updatedPurchaserInfo { (info, error) in
            purchaserInfo = info
        }
        expect(self.backend.postReceiptDataCalled).to(beFalse());
        expect(purchaserInfo).toEventuallyNot(beNil());
    }

    func testAnonPurchasesGeneratesAnAppUserID() {
        setupAnonPurchases()
        expect(self.purchases?.appUserID).toNot(beEmpty())
    }

    func testAnonPurchasesSavesTheAppUserID() {
        setupAnonPurchases()
        expect(self.userDefaults.appUserID).toNot(beNil())
    }

    func testAnonPurchasesReadsSavedAppUserID() {
        let appUserID = "jerry"
        userDefaults.appUserID = appUserID
        setupAnonPurchases()

        expect(self.purchases?.appUserID).to(equal(appUserID))
    }
    
    func testGetEligibility() {
        purchases!.checkTrialOrIntroductoryPriceEligibility([]) { (eligibilities) in}
    }
}
