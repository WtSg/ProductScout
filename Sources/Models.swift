//
//  Models.swift
//  Product Scout
//

import Foundation
import SwiftUI
import AppKit
import UserNotifications

// MARK: - Alert History Model
struct AlertHistoryItem: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let productName: String
    let productURL: String
    let price: String
    let previousStatus: String
    let newStatus: String
    var acknowledged: Bool
    
    init(timestamp: Date, productName: String, productURL: String, price: String, previousStatus: String, newStatus: String, acknowledged: Bool = false) {
        self.id = UUID()
        self.timestamp = timestamp
        self.productName = productName
        self.productURL = productURL
        self.price = price
        self.previousStatus = previousStatus
        self.newStatus = newStatus
        self.acknowledged = acknowledged
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// MARK: - General Settings Model
struct GeneralSettings: Codable {
    var appTitle: String = "Product Scout"
    var autoCheckEnabled: Bool = false
    var checkInterval: Int = 300 // 5 minutes
    var soundAlertsEnabled: Bool = true
    var notificationsEnabled: Bool = true
    var openBrowserEnabled: Bool = true
    var selectedSoundName: String = "Glass"
    var maxConcurrentChecks: Int = 1 // DEFAULT TO 1 (Sequential)!
    var themeColorHex: String = "#81D4E3" // Default Tiffany Blue
}

// MARK: - Notification Settings Model
struct NotificationSettings: Codable {
    // Email settings
    var emailEnabled: Bool = false
    var emailMethod: String = "sendgrid" // DEFAULT to automatic! Options: "sendgrid", "emailjs", "smtp"
    var emailAPIKey: String = ""
    var emailServiceID: String = "" // For EmailJS
    var emailTemplateID: String = "" // For EmailJS
    var fromEmail: String = ""
    var recipientEmails: [String] = []
    // Legacy SMTP settings (kept for compatibility)
    var smtpServer: String = ""
    var smtpPort: Int = 587
    var smtpUsername: String = ""
    var smtpPassword: String = ""
    
    // Pushover settings
    var pushoverEnabled: Bool = false
    var pushoverUserKey: String = ""
    var pushoverApiToken: String = ""
    
    // SMS/Phone settings
    var smsEnabled: Bool = false
    var phoneCallEnabled: Bool = false
    var phoneNumber: String = ""
    // Method selection
    var smsMethod: String = "shortcuts" // "shortcuts", "twilio"
    var callMethod: String = "shortcuts" // "shortcuts", "twilio"
    // Shortcuts settings
    var smsShortcutName: String = "SendProductAlert"
    var callShortcutName: String = "CallProductAlert"
    // Twilio settings
    var twilioAccountSID: String = ""
    var twilioAuthToken: String = ""
    var twilioFromNumber: String = "" // Your Twilio phone number
    
    // Instant Messaging
    var telegramEnabled: Bool = false
    var telegramBotToken: String = ""
    var telegramChatID: String = ""
    
    // Discord (already have webhook support)
    var discordEnabled: Bool = false
    var discordWebhookURL: String = ""
    
    // Enhanced notification settings
    var persistentNotifications: Bool = false
    var criticalAlerts: Bool = false
    var retryFailedNotifications: Bool = false
    var maxRetryAttempts: Int = 3
    
    // Webhook settings
    var webhookEnabled: Bool = false
    var webhookURLs: [String] = []
}

// MARK: - Product Model
struct Product: Identifiable, Codable {
    let id = UUID()
    let url: String
    var name: String
    var customName: String = "" // User-editable custom name
    var status: String = "Not checked"
    var price: String = "—"
    var lastCheckTime: String?
    var alertEnabled: Bool = false // Default OFF for notifications
    var isChecking: Bool = false
    var priceLimit: Double? = nil // Optional price limit for alerts
    var website: SupportedWebsite = .unsupported // Automatically detected website
    var detectionConfidence: Double = 0.0 // Detection confidence level
    
    // Display the custom name if set, otherwise the original name
    var displayName: String {
        return customName.isEmpty ? name : customName
    }
    
    // Check if price limit is set
    var hasPriceLimit: Bool {
        return priceLimit != nil
    }
    
    // Format price limit for display
    var formattedPriceLimit: String {
        guard let limit = priceLimit else { return "No limit" }
        return String(format: "$%.2f", limit)
    }
    
    // Parse current price to Double for comparison
    var currentPriceValue: Double? {
        let cleanPrice = price
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleanPrice)
    }
    
    // Check if current price is within limit
    var isPriceWithinLimit: Bool {
        guard let limit = priceLimit,
              let currentValue = currentPriceValue else { return true }
        return currentValue <= limit
    }
    
    init(url: String) {
        self.url = url
        self.name = Self.extractName(from: url)
        
        // Automatically detect website
        let detectionResult = WebsiteDetector.detectWebsite(from: url)
        self.website = detectionResult.website
        self.detectionConfidence = detectionResult.confidence
    }
    
    static func extractName(from url: String) -> String {
        // Try to extract product name from URL structure
        let components = url.split(separator: "/")
        
        // Look for URL segments that might contain product names
        for component in components {
            let componentStr = String(component)
            
            // Skip common URL parts
            if componentStr.contains("www.") || componentStr.contains(".com") || 
               componentStr.contains("http") || componentStr.contains("site") ||
               componentStr.contains("pdp") || componentStr.isEmpty {
                continue
            }
            
            // Look for segments with product-like patterns (dashes and reasonable length)
            if componentStr.contains("-") && componentStr.count > 15 {
                let name = componentStr
                    .split(separator: "-")
                    .prefix(6) // Take first 6 words
                    .joined(separator: " ")
                    .capitalized
                return String(name.prefix(50))
            }
        }
        
        // Fallback: Try to extract from domain
        if url.contains("bestbuy") {
            return "Best Buy Product"
        } else if url.contains("target") {
            return "Target Product"
        } else if url.contains("canon") {
            return "Canon Product"
        }
        
        return "Product"
    }
    
    enum CodingKeys: String, CodingKey {
        case url, name, customName, status, price, lastCheckTime, alertEnabled, priceLimit, website, detectionConfidence
    }
}

// MARK: - Product Store
@MainActor
class ProductStore: ObservableObject {
    @Published var products: [Product] = []
    @Published var alertHistory: [AlertHistoryItem] = []
    @Published var notificationSettings: NotificationSettings = NotificationSettings() {
        didSet {
            saveNotificationSettings()
        }
    }
    @Published var generalSettings = GeneralSettings() {
        didSet {
            saveGeneralSettings()
        }
    }
    // For UI bindings, expose as @Published properties
    @Published var autoCheckEnabled = false {
        didSet {
            generalSettings.autoCheckEnabled = autoCheckEnabled
            saveGeneralSettings()
        }
    }
    @Published var checkInterval = 300 {
        didSet {
            generalSettings.checkInterval = checkInterval
            saveGeneralSettings()
        }
    }
    @Published var soundAlertsEnabled = true {
        didSet {
            generalSettings.soundAlertsEnabled = soundAlertsEnabled
            saveGeneralSettings()
        }
    }
    @Published var notificationsEnabled = true {
        didSet {
            generalSettings.notificationsEnabled = notificationsEnabled
            saveGeneralSettings()
            // Request permissions when user enables notifications
            if notificationsEnabled && oldValue != notificationsEnabled {
                requestNotificationPermissions()
            }
        }
    }
    @Published var openBrowserEnabled = true {
        didSet {
            generalSettings.openBrowserEnabled = openBrowserEnabled
            saveGeneralSettings()
        }
    }
    @Published var selectedSoundName = "Glass" {
        didSet {
            generalSettings.selectedSoundName = selectedSoundName
            saveGeneralSettings()
        }
    }
    private var isLoadingSettings = false
    @Published var maxConcurrentChecks = 1 { // DEFAULT TO 1!
        didSet {
            if !isLoadingSettings {
                generalSettings.maxConcurrentChecks = maxConcurrentChecks
                saveGeneralSettings()
                print("💾 Saved maxConcurrentChecks: \(maxConcurrentChecks)")
            }
        }
    }
    @Published var nextCheckCountdown = 0
    @Published var isCheckingAll = false
    
    private var autoCheckTimer: Timer?
    private var countdownTimer: Timer?
    // Don't use a shared scraper for concurrent checking
    private let saveURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("product_scout_data.json")
    private let alertHistoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("product_scout_alert_history.json")
    private let notificationSettingsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("product_scout_notification_settings.json")
    private let generalSettingsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("product_scout_general_settings.json")
    
    init() {
        loadProducts()
        loadAlertHistory()
        loadNotificationSettings()
        loadGeneralSettings()
        // Request notification permissions later, not in init
        // requestNotificationPermissions()
        
        // Migrate old app title if needed
        if generalSettings.appTitle == "BestBuy Tracker" || generalSettings.appTitle == "Best Buy Tracker" {
            print("🔄 Migrating app title to Product Scout")
            generalSettings.appTitle = "Product Scout"
            saveGeneralSettings()
        }
        
        // Restore auto-check state from saved settings
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            // Only start auto-check if it was previously enabled
            if self.autoCheckEnabled && !self.products.isEmpty {
                print("🔄 Restoring auto-check state (enabled: \(self.autoCheckEnabled))")
                self.startAutoCheck()
            } else {
                print("⏸️ Auto-check is disabled or no products to check")
            }
        }
    }
    
    func addProduct(url: String) async {
        guard !products.contains(where: { $0.url == url }) else { return }
        
        let product = Product(url: url)
        products.append(product)
        saveProducts()
        
        // Auto-check new product
        await checkProduct(product)
    }
    
    func removeProduct(_ product: Product) {
        products.removeAll { $0.id == product.id }
        saveProducts()
    }
    
    func checkProduct(_ product: Product) async {
        guard let index = products.firstIndex(where: { $0.id == product.id }) else { return }
        
        products[index].isChecking = true
        
        // Get the appropriate scraper for this product's website
        let scraper = ScraperFactory.getScraper(for: product.url)
        await scraper.initialize()
        let result = await scraper.checkProduct(url: product.url)
        
        products[index].isChecking = false
        products[index].status = result.status
        products[index].price = result.price
        products[index].lastCheckTime = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        
        // Check if status changed from unavailable to available
        let previousStatus = product.status.lowercased()
        let wasUnavailable = previousStatus.contains("not checked") || 
                            previousStatus.contains("unavailable") || 
                            previousStatus.contains("sold out") ||
                            previousStatus.contains("timeout") ||
                            !previousStatus.contains("available")
        let isNowAvailable = result.isAvailable
        
        print("📊 Status check for \(product.name):")
        print("   Previous: \(product.status)")
        print("   Current: \(result.status)")
        print("   Was Unavailable: \(wasUnavailable)")
        print("   Is Available Now: \(isNowAvailable)")
        print("   Alert Enabled: \(products[index].alertEnabled)")
        
        // Trigger alert if product became available AND price is within limit
        if products[index].alertEnabled && isNowAvailable {
            // Check price limit condition
            let priceWithinLimit = products[index].isPriceWithinLimit
            
            print("💰 Price check for \(products[index].name):")
            print("   Current price: \(products[index].price)")
            print("   Price limit: \(products[index].formattedPriceLimit)")
            print("   Within limit: \(priceWithinLimit)")
            
            if priceWithinLimit {
                if wasUnavailable {
                    print("🎯 ALERT! Product became available within price limit: \(products[index].name)")
                    // Add to alert history
                    let alertItem = AlertHistoryItem(
                        timestamp: Date(),
                        productName: products[index].name,
                        productURL: products[index].url,
                        price: products[index].price,
                        previousStatus: product.status,
                        newStatus: result.status,
                        acknowledged: false
                    )
                    alertHistory.insert(alertItem, at: 0) // Add at beginning for newest first
                    saveAlertHistory()
                    triggerAlert(for: products[index])
                } else {
                    print("📌 Product still available within price limit: \(products[index].name)")
                    // For testing: Always trigger alert if available and within price limit
                    print("🔔 TEST MODE: Triggering alert anyway for testing")
                    // Still add to history for testing
                    let alertItem = AlertHistoryItem(
                        timestamp: Date(),
                        productName: products[index].name,
                        productURL: products[index].url,
                        price: products[index].price,
                        previousStatus: product.status,
                        newStatus: result.status,
                        acknowledged: false
                    )
                    alertHistory.insert(alertItem, at: 0)
                    saveAlertHistory()
                    triggerAlert(for: products[index])
                }
            } else {
                print("⚠️ Product available but price above limit: \(products[index].name)")
                print("   Current: \(products[index].price), Limit: \(products[index].formattedPriceLimit)")
            }
        } else if !products[index].alertEnabled && isNowAvailable {
            print("⚠️ Product available but alerts disabled: \(products[index].name)")
        }
        
        saveProducts()
    }
    
    func checkAllProducts() {
        guard !isCheckingAll else { 
            print("⚠️ Already checking all products")
            return 
        }
        
        isCheckingAll = true
        
        Task {
            print("🔄 Starting check of \(products.count) products...")
            
            // FORCE SEQUENTIAL for now - WebKit doesn't work well in parallel
            print("🔄 Using sequential checks (WebKit limitation)")
            await checkAllProductsSequential()
            
            // Parallel checking disabled due to WebKit conflicts
            // if maxConcurrentChecks > 1 {
            //     print("⚡ Using parallel checks (max \(maxConcurrentChecks) concurrent)")
            //     await checkAllProductsParallel()
            // } else {
            //     print("🔄 Using sequential checks")
            //     await checkAllProductsSequential()
            // }
            
            print("✅ Check completed for all products")
            isCheckingAll = false
        }
    }
    
    private func checkAllProductsSequential() async {
        for (index, product) in products.enumerated() {
            print("📦 Checking product \(index + 1)/\(products.count): \(product.name)")
            
            // Update UI to show which product is being checked
            if let productIndex = products.firstIndex(where: { $0.id == product.id }) {
                products[productIndex].isChecking = true
            }
            
            await checkProduct(product)
            
            // Mark as not checking
            if let productIndex = products.firstIndex(where: { $0.id == product.id }) {
                products[productIndex].isChecking = false
            }
            
            // Add delay between checks to ensure WebKit cleanup
            if index < products.count - 1 {
                print("⏳ Waiting 2 seconds before next check...")
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
    }
    
    private func checkAllProductsParallel() async {
        // Use limited concurrency to avoid WebKit conflicts
        await withTaskGroup(of: Void.self) { group in
            let semaphore = AsyncSemaphore(limit: maxConcurrentChecks)
            
            let productCount = products.count
            for (index, product) in products.enumerated() {
                group.addTask { [weak self] in
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }
                    
                    print("🚀 Starting check \(index + 1)/\(productCount): \(product.name)")
                    await self?.checkProduct(product)
                    
                    // Add small delay between parallel checks to avoid conflicts
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            }
        }
    }
    
    func clearAll() {
        products.removeAll()
        saveProducts()
    }
    
    func toggleAlert(for product: Product, enabled: Bool) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index].alertEnabled = enabled
            saveProducts()
        }
    }
    
    func updateProductCustomName(_ productId: UUID, _ customName: String) {
        if let index = products.firstIndex(where: { $0.id == productId }) {
            products[index].customName = customName
            saveProducts()
        }
    }
    
    func updateProductPriceLimit(_ productId: UUID, _ priceLimit: Double?) {
        if let index = products.firstIndex(where: { $0.id == productId }) {
            products[index].priceLimit = priceLimit
            saveProducts()
        }
    }
    
    func duplicateProduct(_ product: Product) {
        var newProduct = Product(url: product.url)
        newProduct.customName = "\(product.customName) (Copy)"
        newProduct.alertEnabled = product.alertEnabled
        newProduct.priceLimit = product.priceLimit
        products.append(newProduct)
        saveProducts()
    }
    
    func toggleProductAlert(_ productId: UUID) {
        if let index = products.firstIndex(where: { $0.id == productId }) {
            products[index].alertEnabled.toggle()
            saveProducts()
        }
    }
    
    func toggleAutoCheck() {
        if autoCheckEnabled {
            startAutoCheck()
        } else {
            stopAutoCheck()
        }
    }
    
    func startAutoCheck() {
        // Reset countdown
        nextCheckCountdown = checkInterval
        
        // Start countdown timer (updates every second)
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.nextCheckCountdown -= 1
                if self.nextCheckCountdown <= 0 {
                    self.nextCheckCountdown = self.checkInterval
                }
            }
        }
        
        // Perform initial check
        checkAllProducts()
        
        // Start auto-check timer
        autoCheckTimer?.invalidate()
        autoCheckTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(checkInterval), repeats: true) { _ in
            Task { @MainActor in
                self.checkAllProducts()
            }
        }
    }
    
    func stopAutoCheck() {
        autoCheckTimer?.invalidate()
        autoCheckTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        nextCheckCountdown = 0
    }
    
    func restartAutoCheckTimer() {
        if autoCheckEnabled {
            stopAutoCheck()
            // Update the check interval to the new value
            checkInterval = generalSettings.checkInterval
            startAutoCheck()
        }
    }
    
    // Continue ProductStore methods below...
}

// Simple async semaphore for limiting concurrency  
actor AsyncSemaphore {
    private var count: Int
    private let limit: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(limit: Int) {
        self.limit = limit
        self.count = limit
    }
    
    func wait() async {
        if count > 0 {
            count -= 1
        } else {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }
    
    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            count = min(count + 1, limit)
        }
    }
}

// Extension of ProductStore - additional methods
extension ProductStore {
    
    private func triggerAlert(for product: Product) {
        print("🔔 Triggering alert for: \(product.name)")
        
        // Traditional alerts
        if soundAlertsEnabled {
            playNotificationSound()
        }
        
        if notificationsEnabled {
            sendNotification(for: product)
        }
        
        if openBrowserEnabled {
            if let url = URL(string: product.url) {
                NSWorkspace.shared.open(url)
            }
        }
        
        // New notification methods
        Task {
            // Save settings after every alert to persist them
            saveNotificationSettings()
            
            await sendEmailNotification(for: product)
            await sendPushoverNotification(for: product)
            await sendWebhookNotification(for: product)
            await sendMessageNotification(for: product)
            if notificationSettings.phoneCallEnabled {
                initiatePhoneCall()
            }
        }
    }
    
    private func sendNotification(for product: Product, retryCount: Int = 0) {
        let content = UNMutableNotificationContent()
        content.title = "🎉 Product Scout Alert!"
        content.body = "\(product.name) is now available for \(product.price)"
        content.subtitle = "Click to open in browser"
        
        // Enhanced notification settings
        if notificationSettings.criticalAlerts {
            content.sound = .defaultCritical
            content.interruptionLevel = .critical
        } else {
            content.sound = .default
            content.interruptionLevel = .active
        }
        
        content.userInfo = ["url": product.url]
        content.categoryIdentifier = "PRODUCT_AVAILABLE"
        
        // Add thread identifier for grouping
        content.threadIdentifier = "product-scout-alerts"
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                print("❌ Failed to send notification: \(error)")
                
                // Retry logic
                if let self = self,
                   self.notificationSettings.retryFailedNotifications,
                   retryCount < self.notificationSettings.maxRetryAttempts {
                    print("🔄 Retrying notification (attempt \(retryCount + 1)/\(self.notificationSettings.maxRetryAttempts))")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.sendNotification(for: product, retryCount: retryCount + 1)
                    }
                }
            } else {
                print("✅ Notification sent for: \(product.name)")
            }
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if granted {
                print("✅ Notification permissions granted")
                self.setupNotificationCategories()
            } else if let error = error {
                print("❌ Notification permission error: \(error)")
            } else {
                print("⚠️ Notification permissions denied")
            }
        }
    }
    
    private func setupNotificationCategories() {
        let openAction = UNNotificationAction(
            identifier: "OPEN_PRODUCT",
            title: "Open in Browser",
            options: .foreground
        )
        
        let category = UNNotificationCategory(
            identifier: "PRODUCT_AVAILABLE",
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    func playNotificationSound() {
        // Play system sound
        if let sound = NSSound(named: selectedSoundName) {
            sound.play()
        } else {
            // Fallback to system beep
            NSSound.beep()
        }
    }
    
    var availableSounds: [String] {
        return [
            "Glass",
            "Blow", 
            "Bottle",
            "Frog",
            "Funk",
            "Hero",
            "Morse",
            "Ping",
            "Pop",
            "Purr",
            "Sosumi",
            "Submarine",
            "Tink"
        ]
    }
    
    func getAvailableSounds() -> [String] {
        return availableSounds
    }
    
    func testAlert() {
        var testProduct = Product(url: "https://test.com")
        testProduct.name = "Test Product"
        testProduct.price = "$999.99"
        testProduct.alertEnabled = true
        
        print("🧪 Testing notifications...")
        triggerAlert(for: testProduct)
    }
    
    func saveProducts() {
        if let encoded = try? JSONEncoder().encode(products) {
            try? encoded.write(to: saveURL)
        }
    }
    
    private func loadProducts() {
        if let data = try? Data(contentsOf: saveURL),
           let decoded = try? JSONDecoder().decode([Product].self, from: data) {
            products = decoded
            
            // Update website detection for existing products
            for index in products.indices {
                let detectionResult = WebsiteDetector.detectWebsite(from: products[index].url)
                products[index].website = detectionResult.website
                products[index].detectionConfidence = detectionResult.confidence
            }
            
            // Save if any products were updated
            if !products.isEmpty {
                saveProducts()
            }
        }
    }
    
    // MARK: - Alert History Management
    
    func saveAlertHistory() {
        if let encoded = try? JSONEncoder().encode(alertHistory) {
            try? encoded.write(to: alertHistoryURL)
        }
    }
    
    func loadAlertHistory() {
        if let data = try? Data(contentsOf: alertHistoryURL),
           let decoded = try? JSONDecoder().decode([AlertHistoryItem].self, from: data) {
            alertHistory = decoded
        }
    }
    
    func acknowledgeAlert(_ alertId: UUID) {
        if let index = alertHistory.firstIndex(where: { $0.id == alertId }) {
            alertHistory[index].acknowledged = true
            saveAlertHistory()
        }
    }
    
    func clearAlertHistory() {
        alertHistory.removeAll()
        saveAlertHistory()
        // Force UI update for badge
        objectWillChange.send()
    }
    
    // MARK: - Test Notification Methods
    
    func testSMSNotification() async {
        guard notificationSettings.smsEnabled,
              !notificationSettings.phoneNumber.isEmpty else {
            print("❌ SMS not enabled or phone number missing")
            return
        }
        
        var testProduct = Product(url: "https://test.com")
        testProduct.name = "Test Product"
        testProduct.price = "$999.99"
        
        print("🧪 Testing SMS notification...")
        await sendMessageNotification(for: testProduct)
    }
    
    func testPhoneCallNotification() async {
        guard notificationSettings.phoneCallEnabled,
              !notificationSettings.phoneNumber.isEmpty else {
            print("❌ Phone calls not enabled or phone number missing")
            return
        }
        
        print("🧪 Testing phone call notification...")
        initiatePhoneCall()
    }
    
    // MARK: - Notification Settings Management
    
    func saveNotificationSettings() {
        if let encoded = try? JSONEncoder().encode(notificationSettings) {
            try? encoded.write(to: notificationSettingsURL)
        }
    }
    
    func loadNotificationSettings() {
        if let data = try? Data(contentsOf: notificationSettingsURL),
           let decoded = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            notificationSettings = decoded
        }
    }
    
    // MARK: - General Settings Management
    
    func saveGeneralSettings() {
        if let encoded = try? JSONEncoder().encode(generalSettings) {
            try? encoded.write(to: generalSettingsURL)
            print("💾 Saved general settings (including maxConcurrentChecks: \(generalSettings.maxConcurrentChecks))")
        }
    }
    
    func loadGeneralSettings() {
        if let data = try? Data(contentsOf: generalSettingsURL),
           let decoded = try? JSONDecoder().decode(GeneralSettings.self, from: data) {
            generalSettings = decoded
            // Sync the @Published properties with loaded settings
            autoCheckEnabled = generalSettings.autoCheckEnabled
            checkInterval = generalSettings.checkInterval
            soundAlertsEnabled = generalSettings.soundAlertsEnabled
            notificationsEnabled = generalSettings.notificationsEnabled
            openBrowserEnabled = generalSettings.openBrowserEnabled
            selectedSoundName = generalSettings.selectedSoundName
            maxConcurrentChecks = generalSettings.maxConcurrentChecks
            print("📦 Loaded general settings (maxConcurrentChecks: \(generalSettings.maxConcurrentChecks))")
        } else {
            print("🆕 No saved general settings, using defaults")
        }
    }
    
    // MARK: - Enhanced Notification Methods
    
    func sendEmailNotification(for product: Product) async {
        guard notificationSettings.emailEnabled,
              !notificationSettings.recipientEmails.isEmpty else { return }
        
        switch notificationSettings.emailMethod {
        case "sendgrid":
            await sendEmailViaSendGrid(for: product)
        case "emailjs":
            await sendEmailViaEmailJS(for: product)
        case "smtp":
            // Manual method - should not be used for automatic alerts!
            print("⚠️ Email set to manual mode - switching to automatic SendGrid")
            // Force use SendGrid for automatic sending
            await sendEmailViaSendGrid(for: product)
        default:
            await sendEmailViaSendGrid(for: product)
        }
    }
    
    func sendEmailViaSendGrid(for product: Product) async {
        guard !notificationSettings.emailAPIKey.isEmpty else {
            print("❌ SendGrid API key not configured")
            return
        }
        
        let url = URL(string: "https://api.sendgrid.com/v3/mail/send")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(notificationSettings.emailAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let emailData: [String: Any] = [
            "personalizations": [
                [
                    "to": notificationSettings.recipientEmails.map { ["email": $0] }
                ]
            ],
            "from": [
                "email": notificationSettings.fromEmail.isEmpty ? "alerts@productscout.app" : notificationSettings.fromEmail
            ],
            "subject": "🎉 Product Alert: \(product.name) Available!",
            "content": [
                [
                    "type": "text/html",
                    "value": """
                    <h2>🎉 Product Available!</h2>
                    <p><strong>\(product.name)</strong> is now available!</p>
                    <p>Price: <strong>\(product.price)</strong></p>
                    <p>Status: \(product.status)</p>
                    <br>
                    <a href="\(product.url)" style="background-color: #4CAF50; color: white; padding: 14px 20px; text-decoration: none; border-radius: 4px;">Buy Now</a>
                    <br><br>
                    <p style="color: #666; font-size: 12px;">Alert sent at \(Date().formatted())</p>
                    """
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: emailData)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 202 {
                    print("✅ Email sent automatically via SendGrid!")
                } else {
                    print("❌ SendGrid error: HTTP \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("❌ Failed to send email: \(error)")
        }
    }
    
    func sendEmailViaEmailJS(for product: Product) async {
        // EmailJS - Free tier available, works from client-side
        guard !notificationSettings.emailServiceID.isEmpty,
              !notificationSettings.emailTemplateID.isEmpty,
              !notificationSettings.emailAPIKey.isEmpty else {
            print("❌ EmailJS not configured")
            return
        }
        
        let url = URL(string: "https://api.emailjs.com/api/v1.0/email/send")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let templateParams: [String: Any] = [
            "to_email": notificationSettings.recipientEmails.joined(separator: ", "),
            "from_email": notificationSettings.fromEmail.isEmpty ? "Product Scout" : notificationSettings.fromEmail,
            "product_name": product.name,
            "product_price": product.price,
            "product_status": product.status,
            "product_url": product.url,
            "alert_time": Date().formatted()
        ]
        
        let emailData: [String: Any] = [
            "service_id": notificationSettings.emailServiceID,
            "template_id": notificationSettings.emailTemplateID,
            "user_id": notificationSettings.emailAPIKey,
            "template_params": templateParams
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: emailData)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Email sent automatically via EmailJS!")
                } else {
                    print("❌ EmailJS error: HTTP \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("❌ Failed to send email: \(error)")
        }
    }
    
    @MainActor
    func sendEmailViaMail(for product: Product) {
        // Use NSSharingService to compose email in Mail.app
        let subject = "🎉 Product Alert: \(product.name) Available!"
        let body = """
        Great news! The product you've been tracking is now available.
        
        Product: \(product.name)
        Price: \(product.price)
        Status: \(product.status)
        
        Click here to buy: \(product.url)
        
        Time: \(Date().formatted())
        
        ---
        Sent by Product Scout
        """
        
        // Create sharing service for email
        guard let service = NSSharingService(named: .composeEmail) else {
            print("❌ Email service not available")
            return
        }
        
        service.recipients = notificationSettings.recipientEmails
        service.subject = subject
        
        // Share the text content
        if service.canPerform(withItems: [body]) {
            service.perform(withItems: [body])
            print("✅ Email composed in Mail.app")
        } else {
            // Fallback: Use mailto URL
            sendEmailViaMailto(for: product)
        }
    }
    
    func sendEmailViaMailto(for product: Product) {
        // Fallback method using mailto: URL scheme
        let recipients = notificationSettings.recipientEmails.joined(separator: ",")
        let subject = "Product Alert: \(product.name) Available!"
        let body = "Product: \(product.name)\nPrice: \(product.price)\nStatus: \(product.status)\n\nBuy now: \(product.url)"
        
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipients
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        
        if let url = components.url {
            NSWorkspace.shared.open(url)
            print("📧 Opened Mail app with mailto: URL")
        }
    }
    
    func sendPushoverNotification(for product: Product) async {
        guard notificationSettings.pushoverEnabled,
              !notificationSettings.pushoverUserKey.isEmpty,
              !notificationSettings.pushoverApiToken.isEmpty else { return }
        
        let urlString = "https://api.pushover.net/1/messages.json"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let message = "🎉 \(product.name) is available for \(product.price)!"
        let params = [
            "token": notificationSettings.pushoverApiToken,
            "user": notificationSettings.pushoverUserKey,
            "message": message,
            "title": "Product Available!",
            "url": product.url,
            "url_title": "View Product",
            "priority": "2", // Emergency priority - bypasses quiet hours
            "retry": "30", // Retry every 30 seconds
            "expire": "3600", // Expire after 1 hour
            "sound": "persistent" // Most urgent sound
        ]
        
        let paramString = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = paramString.data(using: .utf8)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Pushover notification sent successfully")
                } else {
                    print("❌ Pushover notification failed: \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("❌ Pushover notification error: \(error)")
        }
    }
    
    func sendWebhookNotification(for product: Product) async {
        guard notificationSettings.webhookEnabled,
              !notificationSettings.webhookURLs.isEmpty else { return }
        
        for webhookURL in notificationSettings.webhookURLs {
            guard let url = URL(string: webhookURL) else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let payload: [String: Any] = [
                "product_name": product.name,
                "price": product.price,
                "url": product.url,
                "status": product.status,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: payload) {
                request.httpBody = jsonData
                
                do {
                    let (_, response) = try await URLSession.shared.data(for: request)
                    if let httpResponse = response as? HTTPURLResponse {
                        print("🌐 Webhook notification sent to \(webhookURL): \(httpResponse.statusCode)")
                    }
                } catch {
                    print("❌ Webhook error for \(webhookURL): \(error)")
                }
            }
        }
    }
    
    // MARK: - Messages and Phone Notifications
    
    func sendMessageNotification(for product: Product) async {
        // Send SMS based on selected method
        if notificationSettings.smsEnabled {
            switch notificationSettings.smsMethod {
            case "shortcuts":
                await sendSMSViaShortcuts(for: product)
            case "default", "messages":
                await sendSMSViaMessagesApp(for: product)
            default:
                // Fallback to Twilio if configured
                if !notificationSettings.twilioAccountSID.isEmpty {
                    await sendTwilioSMS(for: product)
                } else {
                    await sendSMSViaMessagesApp(for: product)
                }
            }
        }
        
        // Send Telegram message
        if notificationSettings.telegramEnabled {
            await sendTelegramMessage(for: product)
        }
        
        // Send Discord message
        if notificationSettings.discordEnabled {
            await sendDiscordMessage(for: product)
        }
    }
    
    func sendSMSViaMessagesApp(for product: Product) async {
        guard notificationSettings.smsEnabled,
              !notificationSettings.phoneNumber.isEmpty else { return }
        
        let message = "🎉 Product Alert! \(product.displayName) is available for \(product.price)! \(product.url)"
        
        // Clean phone number
        let cleanPhone = notificationSettings.phoneNumber
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        
        // Create SMS URL
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let smsURLString = "sms:\(cleanPhone)&body=\(encodedMessage)"
        
        if let smsURL = URL(string: smsURLString) {
            await MainActor.run {
                NSWorkspace.shared.open(smsURL)
                print("✅ Opened Messages app with pre-filled SMS")
            }
        } else {
            print("❌ Failed to create SMS URL")
        }
    }
    
    func sendTwilioSMS(for product: Product) async {
        guard notificationSettings.smsEnabled,
              !notificationSettings.twilioAccountSID.isEmpty,
              !notificationSettings.twilioAuthToken.isEmpty,
              !notificationSettings.twilioFromNumber.isEmpty,
              !notificationSettings.phoneNumber.isEmpty else { return }
        
        let message = "🎉 Product Alert! \(product.name) is available for \(product.price)! \(product.url)"
        
        let url = URL(string: "https://api.twilio.com/2010-04-01/Accounts/\(notificationSettings.twilioAccountSID)/Messages.json")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Basic auth
        let credentials = "\(notificationSettings.twilioAccountSID):\(notificationSettings.twilioAuthToken)"
        let credentialData = credentials.data(using: .utf8)!
        let base64Credentials = credentialData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let params = [
            "From": notificationSettings.twilioFromNumber,
            "To": notificationSettings.phoneNumber,
            "Body": message
        ]
        
        let paramString = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = paramString.data(using: .utf8)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 {
                    print("✅ SMS sent automatically via Twilio!")
                } else {
                    print("❌ Twilio SMS error: \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("❌ Failed to send SMS: \(error)")
        }
    }
    
    func sendTelegramMessage(for product: Product) async {
        guard notificationSettings.telegramEnabled,
              !notificationSettings.telegramBotToken.isEmpty,
              !notificationSettings.telegramChatID.isEmpty else { return }
        
        let message = """
        🎉 *Product Alert!*
        
        *Product:* \(product.name)
        *Price:* \(product.price)
        *Status:* \(product.status)
        
        [🛍️ Buy Now](\(product.url))
        """
        
        let urlString = "https://api.telegram.org/bot\(notificationSettings.telegramBotToken)/sendMessage"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let params: [String: Any] = [
            "chat_id": notificationSettings.telegramChatID,
            "text": message,
            "parse_mode": "Markdown",
            "disable_web_page_preview": false
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: params)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Telegram message sent automatically!")
                } else {
                    print("❌ Telegram error: \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("❌ Failed to send Telegram message: \(error)")
        }
    }
    
    func sendDiscordMessage(for product: Product) async {
        guard notificationSettings.discordEnabled,
              !notificationSettings.discordWebhookURL.isEmpty else { return }
        
        guard let url = URL(string: notificationSettings.discordWebhookURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let embed: [String: Any] = [
            "title": "🎉 Product Available!",
            "description": "**\(product.name)**",
            "color": 5814783, // Green
            "fields": [
                ["name": "Price", "value": product.price, "inline": true],
                ["name": "Status", "value": product.status, "inline": true]
            ],
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "url": product.url
        ]
        
        let payload: [String: Any] = [
            "content": "@everyone Product Alert!",
            "embeds": [embed]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 204 {
                    print("✅ Discord notification sent!")
                } else {
                    print("❌ Discord error: \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("❌ Failed to send Discord message: \(error)")
        }
    }
    
    func initiatePhoneCall() {
        guard notificationSettings.phoneCallEnabled,
              !notificationSettings.phoneNumber.isEmpty else { return }
        
        Task {
            switch notificationSettings.callMethod {
            case "shortcuts":
                await initiateCallViaShortcuts()
            case "twilio":
                if !notificationSettings.twilioAccountSID.isEmpty {
                    await sendTwilioCall()
                } else {
                    print("⚠️ Twilio not configured, falling back to auto-dial attempt")
                    await attemptAutoDial()
                }
            default:
                // Try multiple methods to auto-dial
                await attemptAutoDial()
            }
        }
    }
    
    func attemptAutoDial() async {
        let phoneNumber = notificationSettings.phoneNumber
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        
        print("📞 Attempting auto-dial to \(phoneNumber)...")
        
        // Method 1: Try using AppleScript to dial
        let appleScript = """
        tell application "FaceTime"
            activate
            delay 0.5
        end tell
        
        tell application "System Events"
            tell process "FaceTime"
                keystroke "\(phoneNumber)"
                delay 0.5
                key code 36 -- Press Enter to call
            end tell
        end tell
        """
        
        await MainActor.run {
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: appleScript) {
                _ = scriptObject.executeAndReturnError(&error)
                if let error = error {
                    print("⚠️ AppleScript auto-dial failed: \(error)")
                    // Fallback to URL scheme
                    fallbackDial(phoneNumber: phoneNumber)
                } else {
                    print("✅ Auto-dial initiated via AppleScript!")
                }
            }
        }
    }
    
    func fallbackDial(phoneNumber: String) {
        // Try multiple URL schemes
        let schemes = [
            "facetime-audio://\(phoneNumber)",  // FaceTime Audio
            "tel://\(phoneNumber)",              // Phone app
            "facetime://\(phoneNumber)"          // FaceTime video
        ]
        
        for scheme in schemes {
            if let url = URL(string: scheme) {
                if NSWorkspace.shared.open(url) {
                    print("📞 Opened with scheme: \(scheme)")
                    print("⚠️ May require manual confirmation")
                    break
                }
            }
        }
    }
    
    func sendTwilioCall() async {
        // Twilio can make automated voice calls
        let url = URL(string: "https://api.twilio.com/2010-04-01/Accounts/\(notificationSettings.twilioAccountSID)/Calls.json")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Basic auth
        let credentials = "\(notificationSettings.twilioAccountSID):\(notificationSettings.twilioAuthToken)"
        let credentialData = credentials.data(using: .utf8)!
        let base64Credentials = credentialData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // TwiML for voice message
        let twiml = "<Response><Say voice='alice'>Alert! A product you are tracking is now available. Check your app immediately.</Say><Pause length='2'/><Say>This is an automated alert from Product Scout.</Say></Response>"
        
        let params = [
            "From": notificationSettings.twilioFromNumber,
            "To": notificationSettings.phoneNumber,
            "Twiml": twiml
        ]
        
        let paramString = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = paramString.data(using: .utf8)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 {
                    print("✅ Phone call initiated via Twilio!")
                } else {
                    print("❌ Twilio call error: \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("❌ Failed to initiate call: \(error)")
        }
    }
    
    // MARK: - Shortcuts Integration
    
    func sendSMSViaShortcuts(for product: Product) async {
        let message = "🎉 Product Alert! \(product.name) is available for \(product.price)! \(product.url)"
        
        // Build the Shortcuts URL with parameters
        var components = URLComponents(string: "shortcuts://run-shortcut")
        components?.queryItems = [
            URLQueryItem(name: "name", value: notificationSettings.smsShortcutName),
            URLQueryItem(name: "input", value: "text"),
            URLQueryItem(name: "text", value: message)
        ]
        
        if let url = components?.url {
            await MainActor.run {
                NSWorkspace.shared.open(url)
                print("📲 Triggered SMS Shortcut: \(notificationSettings.smsShortcutName)")
                print("✅ SMS will be sent automatically without confirmation!")
            }
        }
    }
    
    func initiateCallViaShortcuts() async {
        // Pass product info to shortcut for custom actions
        let info = "Product is available! Check your app immediately."
        
        // Build the Shortcuts URL for phone call
        var components = URLComponents(string: "shortcuts://run-shortcut")
        components?.queryItems = [
            URLQueryItem(name: "name", value: notificationSettings.callShortcutName),
            URLQueryItem(name: "input", value: "text"),
            URLQueryItem(name: "text", value: info)
        ]
        
        if let url = components?.url {
            await MainActor.run {
                NSWorkspace.shared.open(url)
                print("📞 Triggered Call Shortcut: \(notificationSettings.callShortcutName)")
                print("✅ Call will be initiated automatically without confirmation!")
            }
        }
    }
    
    func sendMessageViaAppleScript(for product: Product) {
        // Alternative method using AppleScript for more control
        guard notificationSettings.smsEnabled,
              !notificationSettings.phoneNumber.isEmpty else { return }
        
        let message = "🎉 Product Alert! \(product.name) is available for \(product.price)! Check it out: \(product.url)"
        let phoneNumber = notificationSettings.phoneNumber
        
        let appleScript = """
        tell application "Messages"
            set targetService to 1st account whose service type = iMessage
            set targetBuddy to participant \"\(phoneNumber)\" of targetService
            send \"\(message)\" to targetBuddy
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: appleScript) {
            _ = scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("❌ AppleScript error: \(error)")
            } else {
                print("✅ Message sent via AppleScript")
            }
        }
    }
}