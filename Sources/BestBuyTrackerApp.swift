//
//  main.swift
//  Product Scout
//
//  Native Swift macOS App - No Python!
//

import SwiftUI
import AppKit
import UserNotifications

// MARK: - Adaptive Color System
extension Color {
    // Theme Colors - now uses custom theme from settings
    @MainActor
    static func adaptiveTheme(_ scheme: ColorScheme, store: ProductStore) -> Color {
        let baseColor = Color(hex: store.generalSettings.themeColorHex) ?? Color(hex: "#81D4E3")!
        return scheme == .dark ? baseColor.opacity(0.9) : baseColor
    }
    
    // Theme color wrapper for easy migration (uses custom theme from settings)
    @MainActor
    static func adaptiveTiffany(_ scheme: ColorScheme, store: ProductStore? = nil) -> Color {
        if let store = store {
            return adaptiveTheme(scheme, store: store)
        }
        // Fallback to default Tiffany Blue if store not provided
        return scheme == .dark ? Color(red: 0.36, green: 0.63, blue: 0.66) : Color(red: 0.51, green: 0.83, blue: 0.89)
    }
    
    static func adaptiveBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.1, green: 0.11, blue: 0.14) : Color(red: 0.97, green: 0.98, blue: 0.98)
    }
    
    static func adaptiveCard(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.14, green: 0.16, blue: 0.19) : Color.white
    }
    
    static func adaptiveText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.94, green: 0.95, blue: 0.96) : Color(red: 0.17, green: 0.24, blue: 0.31)
    }
    
    static func adaptiveSecondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.6, green: 0.65, blue: 0.7) : Color(red: 0.4, green: 0.45, blue: 0.5)
    }
    
    static func adaptiveSuccess(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.31, green: 0.78, blue: 0.47) : Color(red: 0.72, green: 0.9, blue: 0.72)
    }
    
    static func adaptiveError(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 1.0, green: 0.42, blue: 0.42) : Color(red: 1.0, green: 0.71, blue: 0.71)
    }
    
    static func adaptiveWarning(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 1.0, green: 0.84, blue: 0.0) : Color(red: 1.0, green: 0.85, blue: 0.24)
    }
    
    static func adaptiveBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.23, green: 0.25, blue: 0.29) : Color(red: 0.88, green: 0.91, blue: 0.93)
    }
    
    // Hex conversion utilities
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        let components = NSColor(self).cgColor.components ?? [0, 0, 0, 1]
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Main App
@main
struct ProductScoutApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = ProductStore()
    
    var body: some Scene {
        WindowGroup(store.generalSettings.appTitle) {
            ContentView(store: store)
                .frame(minWidth: 1100, idealWidth: 1200, minHeight: 700, idealHeight: 750)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About \(store.generalSettings.appTitle)") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: store.generalSettings.appTitle,
                        .applicationVersion: "1.0"
                    ])
                }
            }
        }
        
        Settings {
            SettingsView(store: store)
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification click
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == "OPEN_PRODUCT" || response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            if let urlString = response.notification.request.content.userInfo["url"] as? String,
               let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
        completionHandler()
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @ObservedObject var store: ProductStore
    @State private var urlInput = ""
    @State private var isAddingProduct = false
    @State private var selectedTab = "tracker"
    @State private var showingAddAnimation = false
    @State private var hoveringOnAdd = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Adaptive background
            Color.adaptiveBackground(colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Modern Header with adaptive theme
                ModernHeaderView(store: store)
                    .background(
                        colorScheme == .dark ? 
                            AnyView(Color.adaptiveCard(colorScheme).opacity(0.8)) :
                            AnyView(Color.white.shadow(color: .black.opacity(0.05), radius: 5, y: 2))
                    )
                
                // Beautiful Tab Bar
                HStack(spacing: 20) {
                    TabButton(
                        title: "Tracker",
                        icon: "cart.fill",
                        isSelected: selectedTab == "tracker",
                        badge: store.products.count,
                        action: {
                            withAnimation(.spring()) {
                                selectedTab = "tracker"
                            }
                        },
                        store: store
                    )
                    
                    TabButton(
                        title: "Alerts",
                        icon: "bell.fill",
                        isSelected: selectedTab == "history",
                        badge: store.alertHistory.filter { !$0.acknowledged }.count,
                        action: {
                            withAnimation(.spring()) {
                                selectedTab = "history"
                            }
                        },
                        store: store
                    )
                }
                .padding(.horizontal, 25)
                .padding(.vertical, 15)
                
                // Main Content Area
                if selectedTab == "tracker" {
                    VStack(spacing: 20) {
                        // Stunning Input Section
                        VStack(spacing: 15) {
                            HStack(spacing: 15) {
                                // Animated input field
                                HStack {
                                    Image(systemName: "link.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(Color.adaptiveTheme(colorScheme, store: store))
                                        .rotationEffect(.degrees(showingAddAnimation ? 360 : 0))
                                    
                                    TextField("Paste product URL here...", text: $urlInput)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                }
                                .padding(15)
                                .background(Color.adaptiveCard(colorScheme))
                                .cornerRadius(15)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(
                                            Color.adaptiveTheme(colorScheme, store: store).opacity(urlInput.isEmpty ? 0.3 : 0.6),
                                            lineWidth: urlInput.isEmpty ? 1 : 2
                                        )
                                )
                                .shadow(color: Color.adaptiveTheme(colorScheme, store: store).opacity(0.1), radius: 5)
                                
                                // Beautiful Add Button
                                Button(action: {
                                    withAnimation(.spring()) {
                                        showingAddAnimation = true
                                        addProduct()
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        showingAddAnimation = false
                                    }
                                }) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 15)
                                            .fill(Color.adaptiveTheme(colorScheme, store: store))
                                            .frame(width: 120, height: 50)
                                            .shadow(color: Color.adaptiveTheme(colorScheme, store: store).opacity(0.3), radius: 5)
                                        
                                        HStack(spacing: 8) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.title3)
                                            Text("Add")
                                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        }
                                        .foregroundColor(.white)
                                    }
                                }
                                .buttonStyle(.plain)
                                .scaleEffect(hoveringOnAdd ? 1.05 : 1.0)
                                .onHover { hovering in
                                    withAnimation(.spring(response: 0.3)) {
                                        hoveringOnAdd = hovering
                                    }
                                }
                                .disabled(urlInput.isEmpty || isAddingProduct)
                                .opacity(urlInput.isEmpty ? 0.6 : 1.0)
                            }
                            .padding(.horizontal, 25)
                        }
                        .padding(.top, 10)
                        
                        // Modern Product Grid
                        ModernProductListView(store: store)
                            .padding(.horizontal, 20)
                        
                        Spacer(minLength: 0)
                        
                        // Floating Footer Controls
                        ModernFooterControls(store: store)
                            .padding(.horizontal, 25)
                            .padding(.bottom, 20)
                    }
                } else {
                    ModernAlertHistoryView(store: store)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                }
            }
        }
    }
    
    private func addProduct() {
        guard !urlInput.isEmpty else { return }
        isAddingProduct = true
        
        Task {
            await store.addProduct(url: urlInput)
            await MainActor.run {
                urlInput = ""
                isAddingProduct = false
            }
        }
    }
}

// MARK: - Custom Tab Button
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let badge: Int
    let action: () -> Void
    let store: ProductStore
    @State private var isHovering = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isSelected ? .white : Color.adaptiveSecondaryText(colorScheme))
                    
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(
                                Circle()
                                    .fill(Color.adaptiveError(colorScheme))
                            )
                            .offset(x: 12, y: -8)
                    }
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : Color.adaptiveSecondaryText(colorScheme))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? 
                        Color.adaptiveTheme(colorScheme, store: store) : 
                        Color.adaptiveCard(colorScheme)
                    )
                    .shadow(color: isSelected ? 
                        Color.adaptiveTheme(colorScheme, store: store).opacity(0.3) : 
                        Color.black.opacity(0.05), radius: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.adaptiveBorder(colorScheme), lineWidth: 1)
            )
            .scaleEffect(isHovering ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Modern Header View
struct ModernHeaderView: View {
    @ObservedObject var store: ProductStore
    @State private var timeString = ""
    @Environment(\.colorScheme) var colorScheme
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            // Logo and Title
            HStack(spacing: 15) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.adaptiveTheme(colorScheme, store: store),
                                    Color.adaptiveTheme(colorScheme, store: store).opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 45, height: 45)
                    
                    Image(systemName: "cart.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.generalSettings.appTitle)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Color.adaptiveText(colorScheme))
                    Text("Real-time product monitoring")
                        .font(.system(size: 12))
                        .foregroundColor(Color.adaptiveSecondaryText(colorScheme))
                }
            }
            
            Spacer()
            
            // Live Status Indicators
            HStack(spacing: 20) {
                // Auto-check status
                HStack(spacing: 8) {
                    Circle()
                        .fill(store.autoCheckEnabled ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(store.autoCheckEnabled ? Color.green.opacity(0.5) : Color.clear, lineWidth: 8)
                                .scaleEffect(store.autoCheckEnabled ? 1.5 : 1.0)
                                .opacity(store.autoCheckEnabled ? 0.0 : 1.0)
                                .animation(
                                    store.autoCheckEnabled ? 
                                        Animation.easeOut(duration: 1.5).repeatForever(autoreverses: false) : 
                                        .default,
                                    value: store.autoCheckEnabled
                                )
                        )
                    
                    Text(store.autoCheckEnabled ? "Auto-Check ON" : "Auto-Check OFF")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(store.autoCheckEnabled ? .green : .gray)
                }
                
                // Next check countdown
                if store.autoCheckEnabled && store.nextCheckCountdown > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                        Text(formatTime(store.nextCheckCountdown))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                
                // Current Time
                Text(timeString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 15)
        .onReceive(timer) { _ in
            timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Header View (Legacy)
struct HeaderView: View {
    var body: some View {
        HStack {
            Image(systemName: "cart.fill")
                .font(.system(size: 30))
                .foregroundColor(.blue)
            
            Text("Product Scout")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            Text("Swift Native App")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Alert History View
struct AlertHistoryView: View {
    @ObservedObject var store: ProductStore
    @State private var searchText = ""
    
    var filteredAlerts: [AlertHistoryItem] {
        if searchText.isEmpty {
            return store.alertHistory
        } else {
            return store.alertHistory.filter { 
                $0.productName.localizedCaseInsensitiveContains(searchText) ||
                $0.price.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search alerts...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                
                Spacer()
                
                Text("\(filteredAlerts.count) alerts")
                    .foregroundColor(.secondary)
                
                Button("Clear History") {
                    let localStore = store
                    DispatchQueue.main.async {
                        localStore.clearAlertHistory()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(store.alertHistory.isEmpty)
            }
            .padding()
            
            // Alert List Header
            HStack {
                Text("Time").frame(width: 150, alignment: .leading)
                Text("Product").frame(width: 300, alignment: .leading)
                Text("Price").frame(width: 100, alignment: .leading)
                Text("Status Change").frame(width: 200, alignment: .leading)
                Text("Actions").frame(width: 150, alignment: .center)
            }
            .font(.headline)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Alert List
            ScrollView {
                VStack(spacing: 0) {
                    if filteredAlerts.isEmpty {
                        Text("No alerts yet")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 300)
                            .padding()
                    } else {
                        ForEach(filteredAlerts) { alert in
                            AlertRowView(alert: alert, store: store)
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Alert Row View
struct AlertRowView: View {
    let alert: AlertHistoryItem
    @ObservedObject var store: ProductStore
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            // Time
            VStack(alignment: .leading) {
                Text(alert.formattedTime)
                    .font(.caption)
                    .lineLimit(2)
            }
            .frame(width: 150, alignment: .leading)
            
            // Product Name
            Text(alert.productName)
                .frame(width: 300, alignment: .leading)
                .lineLimit(2)
            
            // Price
            Text(alert.price)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.green)
                .frame(width: 100, alignment: .leading)
            
            // Status Change
            HStack(spacing: 4) {
                Text(alert.previousStatus)
                    .foregroundColor(.red)
                    .font(.caption)
                Image(systemName: "arrow.right")
                    .font(.caption)
                Text(alert.newStatus)
                    .foregroundColor(.green)
                    .font(.caption)
            }
            .frame(width: 200, alignment: .leading)
            
            // Actions
            HStack {
                Button(action: {
                    if let url = URL(string: alert.productURL) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(systemName: "cart.fill")
                }
                .buttonStyle(.borderless)
                .help("Open in Browser")
                
                if !alert.acknowledged {
                    Button(action: {
                        let localStore = store
                        let alertId = alert.id
                        DispatchQueue.main.async {
                            localStore.acknowledgeAlert(alertId)
                        }
                    }) {
                        Image(systemName: "checkmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Mark as Acknowledged")
                }
            }
            .frame(width: 150, alignment: .center)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isHovering ? Color(NSColor.selectedControlColor).opacity(0.1) : Color.clear)
        .background(!alert.acknowledged ? Color.green.opacity(0.05) : Color.clear)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Modern Product List View
struct ModernProductListView: View {
    @ObservedObject var store: ProductStore
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            if store.products.isEmpty {
                ModernEmptyStateView(store: store)
                    .frame(maxWidth: .infinity, minHeight: 400)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 380, maximum: 400))], alignment: .leading, spacing: 12) {
                    ForEach(store.products) { product in
                        ModernProductCard(product: product, store: store)
                            .frame(maxWidth: 400)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Modern Product Card
struct ModernProductCard: View {
    let product: Product
    @ObservedObject var store: ProductStore
    @State private var isHovering = false
    @State private var showingDetails = false
    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var isEditingPriceLimit = false
    @State private var priceLimitInput = ""
    @Environment(\.colorScheme) var colorScheme
    
    var statusColor: Color {
        switch product.status {
        case let status where status.contains("Available"):
            return Color.adaptiveSuccess(colorScheme)
        case let status where status.contains("Sold Out") || status.contains("Not Available"):
            return Color.adaptiveError(colorScheme)
        case let status where status.contains("Coming Soon"):
            return Color.adaptiveWarning(colorScheme)
        default:
            return Color.adaptiveSecondaryText(colorScheme)
        }
    }
    
    var cardBackgroundColor: Color {
        switch product.status {
        case let status where status.contains("Available"):
            return Color.adaptiveSuccess(colorScheme).opacity(0.05)
        case let status where status.contains("Sold Out") || status.contains("Not Available"):
            return Color.adaptiveError(colorScheme).opacity(0.05)
        case let status where status.contains("Coming Soon"):
            return Color.adaptiveWarning(colorScheme).opacity(0.05)
        default:
            return Color.adaptiveCard(colorScheme)
        }
    }
    
    // Website Support Styling
    var websiteIcon: String {
        return product.website.logoIcon
    }
    
    var websiteColor: Color {
        return Color(hex: product.website.primaryColor) ?? Color.adaptiveSecondaryText(colorScheme)
    }
    
    var websiteSupportBadgeColor: Color {
        return product.website.isSupported ? Color.green : Color.orange
    }
    
    var websiteSupportText: String {
        return product.website.displayName
    }
    
    // Beautiful Price Limit Badge Styling
    var priceLimitIcon: String {
        if !product.hasPriceLimit {
            return "plus.circle.fill"
        } else if product.isPriceWithinLimit {
            return "checkmark.circle.fill"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }
    
    var priceLimitText: String {
        if !product.hasPriceLimit {
            return "Limit"
        } else {
            // Show full price, no 'k' format
            guard let limit = product.priceLimit else { return "Limit" }
            return String(format: "$%.0f", limit)
        }
    }
    
    var priceLimitIconColor: Color {
        if !product.hasPriceLimit {
            return Color.adaptiveSecondaryText(colorScheme)
        } else if product.isPriceWithinLimit {
            return .white
        } else {
            return .white
        }
    }
    
    var priceLimitTextColor: Color {
        if !product.hasPriceLimit {
            return Color.adaptiveSecondaryText(colorScheme)
        } else if product.isPriceWithinLimit {
            return .white
        } else {
            return .white
        }
    }
    
    var priceLimitBackground: LinearGradient {
        if !product.hasPriceLimit {
            return LinearGradient(
                colors: [Color.adaptiveCard(colorScheme), Color.adaptiveCard(colorScheme).opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if product.isPriceWithinLimit {
            return LinearGradient(
                colors: [Color.green, Color.green.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.orange, Color.orange.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var priceLimitBorderColor: Color {
        if !product.hasPriceLimit {
            return Color.adaptiveBorder(colorScheme)
        } else if product.isPriceWithinLimit {
            return Color.green.opacity(0.3)
        } else {
            return Color.orange.opacity(0.3)
        }
    }
    
    var priceLimitShadowColor: Color {
        if !product.hasPriceLimit {
            return Color.black.opacity(0.05)
        } else if product.isPriceWithinLimit {
            return Color.green.opacity(0.2)
        } else {
            return Color.orange.opacity(0.2)
        }
    }
    
    @ViewBuilder
    private var productHeader: some View {
        HStack(alignment: .center) {
            Text(product.displayName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color.adaptiveText(colorScheme))
                .lineLimit(1)
            
            Spacer()
            
            Button(action: {
                editedName = product.customName.isEmpty ? product.name : product.customName
                isEditingName = true
            }) {
                Image(systemName: "pencil.circle")
                    .font(.system(size: 16))
                    .foregroundColor(Color.adaptiveSecondaryText(colorScheme).opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var bottomActionRow: some View {
        HStack(spacing: 8) {
            // Check status or button
            if product.isChecking {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text("Checking...")
                        .font(.system(size: 11))
                        .foregroundColor(Color.blue.opacity(0.8))
                }
                .fixedSize()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.08))
                )
            } else {
                checkButton
            }
            
            viewButton
            limitButton
            
            Spacer()
            
            // Last check and remove button
            HStack(spacing: 6) {
                if let lastCheck = product.lastCheckTime {
                    Text(lastCheck)
                        .font(.system(size: 10))
                        .foregroundColor(Color.adaptiveSecondaryText(colorScheme).opacity(0.7))
                }
                
                Button(action: {
                    store.removeProduct(product)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.adaptiveSecondaryText(colorScheme).opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var checkButton: some View {
        Button(action: {
            Task { await store.checkProduct(product) }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                Text("Check")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(Color.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var viewButton: some View {
        Button(action: {
            if let url = URL(string: product.url) {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "safari")
                    .font(.system(size: 11))
                Text("View")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(Color(red: 0.92, green: 0.37, blue: 0.20))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.92, green: 0.37, blue: 0.20).opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var limitButton: some View {
        Button(action: {
            if product.hasPriceLimit {
                priceLimitInput = String(format: "%.2f", product.priceLimit ?? 0)
            } else {
                priceLimitInput = ""
            }
            withAnimation(.spring(response: 0.3)) {
                isEditingPriceLimit = true
            }
        }) {
            HStack(spacing: 3) {
                Image(systemName: priceLimitIcon)
                    .font(.system(size: 9))
                Text(priceLimitText)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(product.hasPriceLimit ? .white : Color.green)
            .padding(.horizontal, product.hasPriceLimit ? 10 : 8)
            .padding(.vertical, 8)
            .fixedSize()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(limitButtonBackground)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isEditingPriceLimit, arrowEdge: .top) {
            priceLimitEditor
        }
    }
    
    @ViewBuilder
    private var priceLimitEditor: some View {
        VStack(spacing: 16) {
            // Beautiful text field with $ symbol
            HStack(spacing: 12) {
                Text("$")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.adaptiveTheme(colorScheme, store: store))
                
                TextField("0.00", text: $priceLimitInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .frame(width: 120)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.adaptiveTheme(colorScheme, store: store), lineWidth: 2)
                    )
                    .onSubmit {
                        savePriceLimit()
                    }
            }
            
            // Beautiful buttons
            HStack(spacing: 16) {
                Button(action: {
                    priceLimitInput = ""
                    store.updateProductPriceLimit(product.id, nil)
                    isEditingPriceLimit = false
                }) {
                    Text("Clear")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.red)
                        .frame(width: 80, height: 36)
                }
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.red.opacity(0.12))
                )
                .buttonStyle(.plain)
                
                Button(action: {
                    savePriceLimit()
                }) {
                    Text("Set")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 36)
                }
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.adaptiveTheme(colorScheme, store: store))
                )
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 280)
    }
    
    private var limitButtonBackground: some ShapeStyle {
        if product.hasPriceLimit && product.isPriceWithinLimit {
            return AnyShapeStyle(LinearGradient(colors: [Color.green, Color.green.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
        } else if product.hasPriceLimit {
            return AnyShapeStyle(LinearGradient(colors: [Color.orange, Color.orange.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
        } else {
            return AnyShapeStyle(LinearGradient(colors: [Color.green.opacity(0.08), Color.green.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        HStack(alignment: .center, spacing: 0) {
            // Provider badge
            HStack(spacing: 4) {
                Image(systemName: websiteIcon)
                    .font(.system(size: 10))
                Text(websiteSupportText)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(websiteColor)
            )
            
            // Clean status text only
            Text(product.status)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(statusColor)
                .padding(.leading, 16)
            
            Spacer()
            
            // Price section with toggle
            HStack(spacing: 10) {
                Text(product.price)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Color.adaptiveTheme(colorScheme, store: store))
                
                Toggle("", isOn: Binding(
                    get: { product.alertEnabled },
                    set: { store.toggleAlert(for: product, enabled: $0) }
                ))
                .toggleStyle(SwitchToggleStyle(tint: Color.adaptiveTheme(colorScheme, store: store)))
                .scaleEffect(0.75)
                .frame(width: 40)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
    
    var body: some View {
        // Clean single-line card design matching idea.png
        VStack(alignment: .leading, spacing: 0) {
            productHeader
            
            mainContent
            
            // Divider
            Divider()
                .background(Color.adaptiveBorder(colorScheme).opacity(0.1))
            
            bottomActionRow
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.adaptiveCard(colorScheme))
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.05),
                    radius: isHovering ? 10 : 5,
                    y: isHovering ? 4 : 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    Color.adaptiveBorder(colorScheme).opacity(isHovering ? 0.15 : 0.05),
                    lineWidth: 1
                )
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .sheet(isPresented: $isEditingName) {
            VStack {
                Text("Edit Product Name")
                    .font(.headline)
                TextField("Product name", text: $editedName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        store.updateProductCustomName(product.id, editedName)
                        isEditingName = false
                    }
                HStack {
                    Button("Cancel") { isEditingName = false }
                    Button("Save") {
                        store.updateProductCustomName(product.id, editedName)
                        isEditingName = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(width: 300)
        }
        .contextMenu {
            // Status section
            Section {
                Label(product.status, systemImage: product.status.contains("✅") ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(product.status.contains("✅") ? .green : .red)
                
                if let lastCheck = product.lastCheckTime {
                    Label("Last checked: \(lastCheck)", systemImage: "clock")
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Actions section
            Section {
                Button(action: {
                    Task { await store.checkProduct(product) }
                }) {
                    Label("Check Now", systemImage: "arrow.clockwise")
                }
                .disabled(product.isChecking)
                
                Button(action: {
                    if let url = URL(string: product.url) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label("View on Website", systemImage: "safari")
                }
                
                Button(action: {
                    // Copy URL to clipboard
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(product.url, forType: .string)
                }) {
                    Label("Copy URL", systemImage: "doc.on.doc")
                }
            }
            
            Divider()
            
            // Edit section
            Section {
                Button(action: {
                    editedName = product.customName.isEmpty ? product.name : product.customName
                    isEditingName = true
                }) {
                    Label("Edit Name", systemImage: "pencil")
                }
                
                Button(action: {
                    if product.hasPriceLimit {
                        priceLimitInput = String(format: "%.2f", product.priceLimit ?? 0)
                    } else {
                        priceLimitInput = ""
                    }
                    isEditingPriceLimit = true
                }) {
                    Label("Set Price Limit", systemImage: "dollarsign.circle")
                }
                
                Toggle(isOn: Binding(
                    get: { product.alertEnabled },
                    set: { _ in store.toggleProductAlert(product.id) }
                )) {
                    Label("Notifications", systemImage: product.alertEnabled ? "bell.fill" : "bell.slash")
                }
                
                Button(action: {
                    // Duplicate product
                    store.duplicateProduct(product)
                }) {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
            }
            
            Divider()
            
            // Delete section
            Section {
                Button(role: .destructive, action: {
                    store.removeProduct(product)
                }) {
                    Label("Delete", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private func savePriceLimit() {
        withAnimation(.spring(response: 0.3)) {
            isEditingPriceLimit = false
        }
        
        // Clean the input text
        let cleanedText = priceLimitInput
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        if cleanedText.isEmpty {
            // Clear the price limit
            store.updateProductPriceLimit(product.id, nil)
        } else if let limit = Double(cleanedText), limit > 0 {
            // Set the new price limit
            store.updateProductPriceLimit(product.id, limit)
        } else {
            // Invalid input, reset to previous value
            if let limit = product.priceLimit {
                priceLimitInput = String(format: "%.2f", limit)
            } else {
                priceLimitInput = ""
            }
        }
    }
}

// MARK: - Modern Empty Alert State View
struct ModernEmptyAlertStateView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(Color.adaptiveSecondaryText(colorScheme).opacity(0.5))
            
            Text("No Alerts Yet")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color.adaptiveText(colorScheme))
            
            Text("Alerts will appear here when products become available")
                .font(.system(size: 14))
                .foregroundColor(Color.adaptiveSecondaryText(colorScheme))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - Modern Empty State
struct ModernEmptyStateView: View {
    let store: ProductStore
    @State private var animating = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.adaptiveTheme(colorScheme, store: store).opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(animating ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 2).repeatForever(autoreverses: true),
                        value: animating
                    )
                
                Image(systemName: "cart.badge.plus")
                    .font(.system(size: 50))
                    .foregroundColor(Color.adaptiveTheme(colorScheme, store: store))
            }
            
            Text("No Products Yet")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Color.adaptiveText(colorScheme))
            
            Text("Add a product URL above to start tracking")
                .font(.system(size: 14))
                .foregroundColor(Color.adaptiveSecondaryText(colorScheme))
                .multilineTextAlignment(.center)
        }
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Modern Footer Controls
struct ModernFooterControls: View {
    @ObservedObject var store: ProductStore
    @State private var showingSettings = false
    @State private var showingIntervalSlider = false
    @State private var intervalMinutes: Double = 5
    @Environment(\.colorScheme) var colorScheme
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    var progressPercentage: Double {
        guard store.generalSettings.checkInterval > 0 else { return 0 }
        return Double(store.nextCheckCountdown) / Double(store.generalSettings.checkInterval)
    }
    
    var body: some View {
        HStack(spacing: 15) {
            // Check All Button
            Button(action: {
                Task {
                    await store.checkAllProducts()
                }
            }) {
                HStack(spacing: 8) {
                    if store.isCheckingAll {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.7)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text(store.isCheckingAll ? "Checking All..." : "Check All")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.adaptiveTheme(colorScheme, store: store))
                )
            }
            .buttonStyle(.plain)
            .disabled(store.isCheckingAll || store.products.isEmpty)
            
            // Auto Check Toggle
            Toggle("", isOn: Binding(
                get: { store.autoCheckEnabled },
                set: { newValue in
                    store.autoCheckEnabled = newValue
                    store.generalSettings.autoCheckEnabled = newValue
                    store.saveGeneralSettings()
                    if newValue {
                        store.startAutoCheck()
                    } else {
                        store.stopAutoCheck()
                    }
                }
            ))
                .toggleStyle(ModernToggleStyle(label: "Auto", store: store))
            
            // Visual Countdown with Progress Bar
            if store.autoCheckEnabled {
                // Progress Bar - Spans available space
                HStack(spacing: 8) {
                    // Animated Icon
                    Image(systemName: store.nextCheckCountdown <= 3 ? "hourglass.bottomhalf.filled" : "hourglass")
                        .font(.system(size: 14))
                        .foregroundColor(Color.adaptiveTheme(colorScheme, store: store))
                        .rotationEffect(.degrees(store.autoCheckEnabled && store.nextCheckCountdown % 2 == 0 ? 180 : 0))
                        .animation(.easeInOut(duration: 0.5), value: store.nextCheckCountdown)
                    
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 10)
                            
                            // Progress fill
                            RoundedRectangle(cornerRadius: 5)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.adaptiveTheme(colorScheme, store: store),
                                            Color.adaptiveTheme(colorScheme, store: store).opacity(0.7)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progressPercentage, height: 10)
                                .animation(.linear(duration: 0.5), value: progressPercentage)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 10)
                    
                    // Time Display
                    Text(store.nextCheckCountdown > 0 ? formatTime(store.nextCheckCountdown) : "Ready")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.adaptiveTheme(colorScheme, store: store))
                        .frame(width: 45, alignment: .trailing)
                    
                    // Interval Setting Button
                    Button(action: {
                        intervalMinutes = Double(store.generalSettings.checkInterval / 60)
                        showingIntervalSlider.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 12))
                            Text("\(store.generalSettings.checkInterval / 60)m")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Color.adaptiveTheme(colorScheme, store: store))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.adaptiveTheme(colorScheme, store: store).opacity(0.5), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingIntervalSlider) {
                        VStack(spacing: 15) {
                            Text("Auto-Check Interval")
                                .font(.headline)
                            
                            HStack {
                                Text("1m")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Slider(value: $intervalMinutes, in: 1...60, step: 1)
                                Text("60m")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("\(Int(intervalMinutes)) minute\(Int(intervalMinutes) == 1 ? "" : "s")")
                                .font(.title2)
                                .bold()
                                .foregroundColor(Color.adaptiveTheme(colorScheme, store: store))
                            
                            Button("Set") {
                                store.generalSettings.checkInterval = Int(intervalMinutes) * 60
                                store.checkInterval = Int(intervalMinutes) * 60  // Update the local property too
                                store.saveGeneralSettings()
                                store.restartAutoCheckTimer()  // This will reset countdown to the new interval
                                showingIntervalSlider = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .frame(width: 300)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.adaptiveTheme(colorScheme, store: store).opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.adaptiveTheme(colorScheme, store: store).opacity(0.2), lineWidth: 1)
                        )
                )
                .frame(maxWidth: .infinity)
            }
            
            Spacer()
            
            // Stats
            HStack(spacing: 20) {
                HStack(spacing: 5) {
                    Image(systemName: "cube.box")
                        .font(.system(size: 12))
                    Text("\(store.products.count)")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(Color.adaptiveSecondaryText(colorScheme))
                
                HStack(spacing: 5) {
                    Image(systemName: "bell")
                        .font(.system(size: 12))
                    Text("\(store.products.filter { $0.alertEnabled }.count)")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(Color.adaptiveSecondaryText(colorScheme))
            }
            
            // Settings Button
            Button(action: {
                showingSettings = true
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color.adaptiveSecondaryText(colorScheme))
                    .padding(10)
                    .background(
                        Circle()
                            .fill(Color.adaptiveCard(colorScheme))
                    )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingSettings) {
                SettingsView(store: store)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.adaptiveCard(colorScheme))
                .shadow(color: Color.black.opacity(0.05), radius: 5)
        )
    }
}

// MARK: - Modern Toggle Style
struct ModernToggleStyle: ToggleStyle {
    let label: String
    let store: ProductStore
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.adaptiveText(colorScheme))
            
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(configuration.isOn ? 
                        Color.adaptiveTheme(colorScheme, store: store) :
                        Color.adaptiveBorder(colorScheme)
                    )
                    .frame(width: 50, height: 28)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .offset(x: configuration.isOn ? 11 : -11)
                    .animation(.spring(response: 0.3), value: configuration.isOn)
            }
            .onTapGesture {
                withAnimation(.spring()) {
                    configuration.isOn.toggle()
                }
            }
        }
    }
}

// MARK: - Modern Alert History View  
struct ModernAlertHistoryView: View {
    @ObservedObject var store: ProductStore
    @Environment(\.colorScheme) var colorScheme
    @State private var showingClearConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Clear All button
            if !store.alertHistory.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Alert History")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.adaptiveText(colorScheme))
                        Text("\(store.alertHistory.count) total alerts")
                            .font(.system(size: 12))
                            .foregroundColor(Color.adaptiveSecondaryText(colorScheme))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showingClearConfirmation = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Clear All")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.adaptiveError(colorScheme))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.adaptiveError(colorScheme).opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                    .alert("Clear All Alerts?", isPresented: $showingClearConfirmation) {
                        Button("Cancel", role: .cancel) {}
                        Button("Clear All", role: .destructive) {
                            withAnimation(.spring()) {
                                store.clearAlertHistory()
                            }
                        }
                    } message: {
                        Text("This will permanently remove all alert history. This action cannot be undone.")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
            }
            
            ScrollView {
                VStack(spacing: 15) {
                    if store.alertHistory.isEmpty {
                        ModernEmptyAlertStateView()
                            .frame(maxWidth: .infinity, minHeight: 300)
                    } else {
                        ForEach(store.alertHistory) { alert in
                            ModernAlertCard(alert: alert, store: store)
                        }
                    }
                }
                .padding(.vertical, 10)
            }
        }
    }
}

// MARK: - Modern Alert Card
struct ModernAlertCard: View {
    let alert: AlertHistoryItem
    @ObservedObject var store: ProductStore
    @State private var isHovering = false
    @Environment(\.colorScheme) var colorScheme
    
    var alertStatusColor: Color {
        alert.newStatus.contains("Available") ? Color.adaptiveSuccess(colorScheme) : Color.adaptiveWarning(colorScheme)
    }
    
    var body: some View {
        HStack {
            // Alert Icon
            ZStack {
                Circle()
                    .fill(
                        alert.acknowledged ? 
                            Color.adaptiveSecondaryText(colorScheme).opacity(0.3) :
                            alertStatusColor
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: alert.acknowledged ? "checkmark" : "bell.fill")
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(alert.productName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.adaptiveText(colorScheme))
                
                HStack {
                    Text(alert.formattedTime)
                        .font(.system(size: 12))
                        .foregroundColor(Color.adaptiveSecondaryText(colorScheme))
                    
                    Text("•")
                        .foregroundColor(Color.adaptiveSecondaryText(colorScheme))
                    
                    Text(alert.price)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.adaptiveTheme(colorScheme, store: store))
                    
                    Text("•")
                        .foregroundColor(Color.adaptiveSecondaryText(colorScheme))
                    
                    Text(alert.newStatus)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(alertStatusColor)
                }
            }
            
            Spacer()
            
            if !alert.acknowledged {
                Button(action: {
                    withAnimation(.spring()) {
                        store.acknowledgeAlert(alert.id)
                    }
                }) {
                    Text("Dismiss")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.adaptiveTheme(colorScheme, store: store))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.adaptiveTheme(colorScheme, store: store).opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    alert.acknowledged ?
                        Color.adaptiveCard(colorScheme) :
                        alertStatusColor.opacity(0.05)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.adaptiveCard(colorScheme).opacity(0.8))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Product List View (Legacy)
struct ProductListView: View {
    @ObservedObject var store: ProductStore
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header Row
                HStack {
                    Text("Product").frame(width: 300, alignment: .leading)
                    Text("Status").frame(width: 150, alignment: .leading)
                    Text("Price").frame(width: 100, alignment: .leading)
                    Text("Last Check").frame(width: 150, alignment: .leading)
                    Text("Actions").frame(width: 200, alignment: .center)
                    Text("Alert").frame(width: 100, alignment: .center)
                }
                .font(.headline)
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                
                Divider()
                
                // Product Rows
                if store.products.isEmpty {
                    EmptyStateView()
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    ForEach(store.products) { product in
                        ProductRowView(store: store, product: product)
                        Divider()
                    }
                }
            }
        }
    }
}

// MARK: - Product Row View
struct ProductRowView: View {
    @ObservedObject var store: ProductStore
    let product: Product
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            Text(product.name)
                .lineLimit(1)
                .frame(width: 300, alignment: .leading)
            
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(product.status)
            }
            .frame(width: 150, alignment: .leading)
            
            Text(product.price)
                .bold()
                .frame(width: 100, alignment: .leading)
            
            Text(product.lastCheckTime ?? "Never")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 150, alignment: .leading)
            
            HStack(spacing: 8) {
                Button(action: { checkProduct() }) {
                    if product.isChecking {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(product.isChecking)
                
                Button(action: { openInBrowser() }) {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.borderless)
                
                Button(action: { removeProduct() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
            .frame(width: 200, alignment: .center)
            
            Toggle("", isOn: .constant(product.alertEnabled))
                .onChange(of: product.alertEnabled) { newValue in
                    store.toggleAlert(for: product, enabled: newValue)
                }
            .toggleStyle(.switch)
            .frame(width: 100, alignment: .center)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private var statusColor: Color {
        switch product.status {
        case let status where status.contains("Available"):
            return .green
        case let status where status.contains("Sold Out") || status.contains("Not Available"):
            return .red
        case let status where status.contains("Coming Soon"):
            return .orange
        default:
            return .gray
        }
    }
    
    private func checkProduct() {
        Task {
            await store.checkProduct(product)
        }
    }
    
    private func openInBrowser() {
        if let url = URL(string: product.url) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func removeProduct() {
        store.removeProduct(product)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        VStack {
            Image(systemName: "cart.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No products added yet")
                .font(.title2)
                .padding(.top)
            
            Text("Add a product URL above to start tracking")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Footer Controls
struct FooterControls: View {
    @ObservedObject var store: ProductStore
    @State private var showingSettings = false
    
    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    var body: some View {
        HStack {
            Button(action: { store.checkAllProducts() }) {
                if store.isCheckingAll {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Checking...")
                    }
                } else {
                    Label("Check All", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isCheckingAll || store.autoCheckEnabled)
            
            Button(action: { store.clearAll() }) {
                Label("Clear All", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
            
            Spacer()
            
            Toggle("Auto Check", isOn: $store.autoCheckEnabled)
                .onChange(of: store.autoCheckEnabled) { _ in
                    store.toggleAutoCheck()
                }
            
            if store.autoCheckEnabled && store.nextCheckCountdown > 0 {
                Text("Next: \(formatTime(store.nextCheckCountdown))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Picker("Interval:", selection: $store.checkInterval) {
                Text("1 min").tag(60)
                Text("2 min").tag(120)
                Text("5 min").tag(300)
                Text("10 min").tag(600)
                Text("30 min").tag(1800)
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            .disabled(store.autoCheckEnabled)
            
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(store: store)
                    .environmentObject(store)
            }
        }
        .padding()
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var store: ProductStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedSettingsTab = "general"
    
    var body: some View {
        VStack(spacing: 0) {
            // Title Bar with Close Button
            HStack {
                Text("Notification Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color.adaptiveText(colorScheme))
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(Color.adaptiveSecondaryText(colorScheme))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .help("Close Settings")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Tab Selection
            Picker("", selection: $selectedSettingsTab) {
                Text("🔔 General").tag("general")
                Text("📧 Email").tag("email")
                Text("📱 Push").tag("push")
                Text("💬 Messages").tag("messages")
                Text("🌐 Webhooks").tag("webhooks")
                Text("⚙️ Advanced").tag("advanced")
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    switch selectedSettingsTab {
                    case "general":
                        GeneralSettingsView(store: store)
                    case "email":
                        EmailSettingsView(store: store)
                    case "push":
                        PushoverSettingsView(store: store)
                    case "messages":
                        MessagesSettingsView(store: store)
                    case "webhooks":
                        WebhookSettingsView(store: store)
                    case "advanced":
                        AdvancedSettingsView(store: store)
                    default:
                        EmptyView()
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer with auto-save indicator
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.adaptiveSuccess(colorScheme))
                    Text("Settings auto-save enabled")
                        .font(.caption)
                        .foregroundColor(Color.adaptiveSecondaryText(colorScheme))
                }
                
                Spacer()
                
                Button("Test All Notifications") {
                    let localStore = store
                    DispatchQueue.main.async {
                        localStore.testAlert()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.adaptiveTheme(colorScheme, store: store))
            }
            .padding()
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - General Settings
struct GeneralSettingsView: View {
    @ObservedObject var store: ProductStore
    @Environment(\.colorScheme) var colorScheme
    @State private var themeColor: Color = Color(hex: "#81D4E3") ?? .blue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("App Customization")
                .font(.headline)
                .foregroundColor(Color.adaptiveText(colorScheme))
            
            HStack {
                Text("App Title:")
                    .frame(width: 100, alignment: .leading)
                    .foregroundColor(Color.adaptiveText(colorScheme))
                TextField("Product Scout", text: $store.generalSettings.appTitle)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                    .onChange(of: store.generalSettings.appTitle) { _ in
                        store.saveGeneralSettings()
                    }
            }
            
            HStack {
                Text("Theme Color:")
                    .frame(width: 100, alignment: .leading)
                    .foregroundColor(Color.adaptiveText(colorScheme))
                
                ColorPicker("", selection: $themeColor)
                    .labelsHidden()
                    .frame(width: 50, height: 30)
                    .onChange(of: themeColor) { newColor in
                        store.generalSettings.themeColorHex = newColor.toHex()
                        store.saveGeneralSettings()
                    }
                
                Text(store.generalSettings.themeColorHex)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Color.adaptiveSecondaryText(colorScheme))
                    .padding(.horizontal, 10)
                
                Button("Reset to Default") {
                    themeColor = Color(hex: "#81D4E3") ?? .blue
                    store.generalSettings.themeColorHex = "#81D4E3"
                    store.saveGeneralSettings()
                }
                .buttonStyle(.bordered)
            }
            .onAppear {
                themeColor = Color(hex: store.generalSettings.themeColorHex) ?? Color(hex: "#81D4E3")!
            }
            
            Divider()
                .padding(.vertical, 5)
            
            Text("Basic Notifications")
                .font(.headline)
                .foregroundColor(Color.adaptiveText(colorScheme))
            
            Toggle("Sound Alerts", isOn: $store.soundAlertsEnabled)
                .onChange(of: store.soundAlertsEnabled) { _ in
                    store.generalSettings.soundAlertsEnabled = store.soundAlertsEnabled
                    store.saveGeneralSettings()
                }
            
            HStack {
                Text("Notification Sound:")
                Picker("Sound", selection: $store.selectedSoundName) {
                    ForEach(["Glass", "Blow", "Bottle", "Frog", "Funk", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"], id: \.self) { sound in
                        Text(sound).tag(sound)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                
                Button("Preview") {
                    let localStore = store
                    DispatchQueue.main.async {
                        localStore.playNotificationSound()
                    }
                }
                .buttonStyle(.bordered)
            }
            .disabled(!store.soundAlertsEnabled)
            
            Toggle("Desktop Notifications", isOn: $store.notificationsEnabled)
                .onChange(of: store.notificationsEnabled) { _ in
                    store.generalSettings.notificationsEnabled = store.notificationsEnabled
                    store.saveGeneralSettings()
                }
            Toggle("Open Browser When Available", isOn: $store.openBrowserEnabled)
                .onChange(of: store.openBrowserEnabled) { _ in
                    store.generalSettings.openBrowserEnabled = store.openBrowserEnabled
                    store.saveGeneralSettings()
                }
            
            // Parallel checking disabled due to WebKit limitations
            // WebKit views cannot properly run in parallel
            // All checks are now sequential for reliability
        }
    }
}

// MARK: - Email Settings
struct EmailSettingsView: View {
    @ObservedObject var store: ProductStore
    @State private var newEmail = ""
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Toggle("Enable Email Notifications", isOn: $store.notificationSettings.emailEnabled)
            
            if store.notificationSettings.emailEnabled {
                Group {
                    Text("Email Recipients")
                        .font(.headline)
                    
                    HStack {
                        TextField("email@example.com", text: $newEmail)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            if !newEmail.isEmpty {
                                store.notificationSettings.recipientEmails.append(newEmail)
                                newEmail = ""
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    ForEach(store.notificationSettings.recipientEmails, id: \.self) { email in
                        HStack {
                            Text(email)
                            Spacer()
                            Button(action: {
                                store.notificationSettings.recipientEmails.removeAll { $0 == email }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Divider()
                    
                    Text("Automatic Email Service")
                        .font(.headline)
                    
                    Picker("Method:", selection: $store.notificationSettings.emailMethod) {
                        Text("SendGrid (Recommended)").tag("sendgrid")
                        Text("EmailJS (Free)").tag("emailjs")
                        Text("Mail App (Manual)").tag("smtp")
                    }
                    .pickerStyle(.segmented)
                    
                    // SendGrid Configuration
                    if store.notificationSettings.emailMethod == "sendgrid" {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("📧 SendGrid - Automatic Email Sending")
                                .font(.subheadline)
                                .bold()
                            
                            Text("1. Sign up at sendgrid.com (free tier: 100 emails/day)")
                                .font(.caption)
                            Text("2. Create an API key in Settings > API Keys")
                                .font(.caption)
                            Text("3. Paste it below:")
                                .font(.caption)
                            
                            HStack {
                                Text("API Key:")
                                    .frame(width: 80, alignment: .trailing)
                                SecureField("SG.xxxxx...", text: $store.notificationSettings.emailAPIKey)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            HStack {
                                Text("From Email:")
                                    .frame(width: 80, alignment: .trailing)
                                TextField("alerts@yourdomain.com (optional)", text: $store.notificationSettings.fromEmail)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(5)
                    }
                    
                    // EmailJS Configuration
                    if store.notificationSettings.emailMethod == "emailjs" {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("🆓 EmailJS - Free Automatic Emails")
                                .font(.subheadline)
                                .bold()
                            
                            Text("1. Sign up at emailjs.com (free: 200 emails/month)")
                                .font(.caption)
                            Text("2. Add email service (Gmail, Outlook, etc.)")
                                .font(.caption)
                            Text("3. Create email template")
                                .font(.caption)
                            Text("4. Get your IDs from dashboard:")
                                .font(.caption)
                            
                            HStack {
                                Text("Public Key:")
                                    .frame(width: 100, alignment: .trailing)
                                TextField("Your Public Key", text: $store.notificationSettings.emailAPIKey)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            HStack {
                                Text("Service ID:")
                                    .frame(width: 100, alignment: .trailing)
                                TextField("service_xxxxx", text: $store.notificationSettings.emailServiceID)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            HStack {
                                Text("Template ID:")
                                    .frame(width: 100, alignment: .trailing)
                                TextField("template_xxxxx", text: $store.notificationSettings.emailTemplateID)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(5)
                    }
                    
                    // Mail App (Manual)
                    if store.notificationSettings.emailMethod == "smtp" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("⚠️ Mail App - Manual Sending")
                                .font(.subheadline)
                                .bold()
                            Text("Opens Mail app with pre-filled message")
                                .font(.caption)
                            Text("You must manually click Send")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(5)
                    
                    
                    }
                    
                    Spacer()
                    
                    // Test Section at Bottom
                    GroupBox {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "testtube.2")
                                    .foregroundColor(Color.adaptiveWarning(colorScheme))
                                Text("Test Email Notification")
                                    .font(.subheadline)
                                    .foregroundColor(Color.adaptiveText(colorScheme))
                                Spacer()
                            }
                            
                            Divider()
                            
                            Button(action: {
                                Task {
                                    var testProduct = Product(url: "https://test.com")
                                    testProduct.name = "Test Product"
                                    testProduct.price = "$999.99"
                                    testProduct.status = "Available"
                                    await store.sendEmailNotification(for: testProduct)
                                }
                            }) {
                                Label("Send Test Email", systemImage: "envelope.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.adaptiveTheme(colorScheme, store: store))
                            .controlSize(.regular)
                            .disabled(store.notificationSettings.recipientEmails.isEmpty)
                            
                            if store.notificationSettings.recipientEmails.isEmpty {
                                Text("Add recipient email addresses above to test")
                                    .font(.caption)
                                    .foregroundColor(Color.adaptiveError(colorScheme))
                            }
                        }
                        .padding(5)
                    }
                }
                .disabled(!store.notificationSettings.emailEnabled)
            }
        }
    }
}

// MARK: - Pushover Settings
struct PushoverSettingsView: View {
    @ObservedObject var store: ProductStore
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Toggle("Enable Pushover Notifications", isOn: $store.notificationSettings.pushoverEnabled)
            
            if store.notificationSettings.pushoverEnabled {
                Text("Get your keys from pushover.net")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("User Key:")
                        .frame(width: 100, alignment: .trailing)
                    SecureField("Your Pushover User Key", text: $store.notificationSettings.pushoverUserKey)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Text("API Token:")
                        .frame(width: 100, alignment: .trailing)
                    SecureField("Your App API Token", text: $store.notificationSettings.pushoverApiToken)
                        .textFieldStyle(.roundedBorder)
                }
                
                Spacer()
                
                // Test Section at Bottom
                GroupBox {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "testtube.2")
                                .foregroundColor(Color.adaptiveWarning(colorScheme))
                            Text("Test Push Notification")
                                .font(.subheadline)
                                .foregroundColor(Color.adaptiveText(colorScheme))
                            Spacer()
                        }
                        
                        Divider()
                        
                        Button(action: {
                            Task {
                                var testProduct = Product(url: "https://test.com")
                                testProduct.name = "Test Product"
                                testProduct.price = "$999.99"
                                await store.sendPushoverNotification(for: testProduct)
                            }
                        }) {
                            Label("Send Test Push", systemImage: "bell.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.adaptiveTheme(colorScheme, store: store))
                        .controlSize(.regular)
                        .disabled(store.notificationSettings.pushoverApiToken.isEmpty || store.notificationSettings.pushoverUserKey.isEmpty)
                        
                        if store.notificationSettings.pushoverApiToken.isEmpty || store.notificationSettings.pushoverUserKey.isEmpty {
                            Text("Enter API keys above to test")
                                .font(.caption)
                                .foregroundColor(Color.adaptiveError(colorScheme))
                        }
                    }
                    .padding(5)
                }
            }
        }
    }
}

// MARK: - Messages Settings
struct MessagesSettingsView: View {
    @ObservedObject var store: ProductStore
    @State private var selectedTab = "sms"
    @State private var showingShortcutHelp = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Modern Header with gradient
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.adaptiveTheme(colorScheme, store: store))
                        .frame(width: 40, height: 40)
                    Image(systemName: "message.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Messages & Calls")
                        .font(.headline)
                        .foregroundColor(Color.adaptiveText(colorScheme))
                    Text("Get instant alerts via SMS and phone calls")
                        .font(.caption)
                        .foregroundColor(Color.adaptiveSecondaryText(colorScheme))
                }
                Spacer()
            }
            .padding(.bottom, 5)
            
            // Beautiful Tab Selector
            Picker("", selection: $selectedTab) {
                Label("Phone", systemImage: "phone.fill").tag("sms")
                Label("Telegram", systemImage: "paperplane.fill").tag("telegram")
                Label("Discord", systemImage: "gamecontroller.fill").tag("discord")
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 5)
            
            if selectedTab == "sms" {
                VStack(spacing: 15) {
                    // Beautiful Toggle Cards
                    GroupBox {
                        VStack(spacing: 15) {
                            HStack {
                                Image(systemName: "message.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("SMS Notifications")
                                        .font(.subheadline)
                                        
                                    Text("Receive instant text messages")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: $store.notificationSettings.smsEnabled)
                                    .toggleStyle(.switch)
                            }
                            
                            Divider()
                            
                            HStack {
                                Image(systemName: "phone.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Phone Call Alerts")
                                        .font(.subheadline)
                                        
                                    Text("Get automated phone calls")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: $store.notificationSettings.phoneCallEnabled)
                                    .toggleStyle(.switch)
                            }
                        }
                        .padding(5)
                    }
                    
                    if store.notificationSettings.smsEnabled || store.notificationSettings.phoneCallEnabled {
                        // Phone Number Configuration
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Configuration", systemImage: "gear")
                                    .font(.subheadline)
                                    .foregroundColor(Color.adaptiveText(colorScheme))
                                
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Phone Number")
                                        .font(.caption)
                                        .foregroundColor(Color.adaptiveSecondaryText(colorScheme))
                                    TextField("+1 (555) 123-4567", text: $store.notificationSettings.phoneNumber)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))
                                        .onChange(of: store.notificationSettings.phoneNumber) { _ in
                                            store.saveNotificationSettings()
                                        }
                                }
                            }
                            .padding(5)
                        }
                        
                        // Delivery Method Selection
                        GroupBox {
                            VStack(alignment: .leading, spacing: 15) {
                                Label("Delivery Method", systemImage: "gear")
                                    .font(.subheadline)
                                    
                                
                                if store.notificationSettings.smsEnabled {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("SMS Method")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Picker("", selection: $store.notificationSettings.smsMethod) {
                                            Label("Shortcuts (Auto)", systemImage: "star.fill").tag("shortcuts")
                                            Label("Messages App", systemImage: "message").tag("default")
                                        }
                                        .pickerStyle(.segmented)
                                    }
                                }
                                
                                if store.notificationSettings.phoneCallEnabled {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Call Method")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Picker("", selection: $store.notificationSettings.callMethod) {
                                            Label("Shortcuts", systemImage: "star.fill").tag("shortcuts")
                                            Label("Phone App", systemImage: "phone").tag("default")
                                        }
                                        .pickerStyle(.segmented)
                                    }
                                }
                            }
                            .padding(5)
                        }
                    
                    if (store.notificationSettings.smsEnabled && store.notificationSettings.smsMethod == "shortcuts") ||
                       (store.notificationSettings.phoneCallEnabled && store.notificationSettings.callMethod == "shortcuts") {
                        
                        // Shortcuts Setup Card
                        GroupBox {
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Image(systemName: "star.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Shortcuts Setup")
                                            .font(.subheadline)
                                            
                                        Text("Configure Apple Shortcuts for automatic sending")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button(action: { showingShortcutHelp.toggle() }) {
                                        Image(systemName: "questionmark.circle")
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.plain)
                                }
                            
                                if store.notificationSettings.smsEnabled && store.notificationSettings.smsMethod == "shortcuts" {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label("SMS Shortcut Name", systemImage: "message")
                                            .font(.caption)
                                            
                                        TextField("SendProductAlert", text: $store.notificationSettings.smsShortcutName)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(.body, design: .monospaced))
                                    }
                                }
                            
                                if store.notificationSettings.phoneCallEnabled && store.notificationSettings.callMethod == "shortcuts" {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label("Call Shortcut Name", systemImage: "phone")
                                            .font(.caption)
                                            
                                        TextField("CallProductAlert", text: $store.notificationSettings.callShortcutName)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(.body, design: .monospaced))
                                    }
                                }
                                
                                // Success Note
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Shortcuts bypass all confirmation dialogs!")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 5)
                            }
                            .padding(5)
                        }
                        .popover(isPresented: $showingShortcutHelp) {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("How to Set Up Shortcuts")
                                    .font(.headline)
                                    .padding(.bottom, 5)
                                
                                Text("1. Open the Shortcuts app on your Mac")
                                Text("2. Create a new shortcut")
                                Text("3. Add 'Send Message' action for SMS or 'Call' action for phone")
                                Text("4. Configure with your phone number")
                                Text("5. Name it exactly as shown in the field below")
                                Text("6. The app will pass the alert message as input")
                                
                                Divider()
                                
                                Text("Benefits:")
                                    .font(.subheadline)
                                    .bold()
                                Text("• No confirmation dialogs")
                                Text("• Fully automatic alerts")
                                Text("• Works with any phone number")
                                
                                Button("Close") {
                                    showingShortcutHelp = false
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.top)
                            }
                            .padding()
                            .frame(width: 350)
                        }
                    }
                    
                    // Note about Phone calls
                    if store.notificationSettings.phoneCallEnabled && store.notificationSettings.callMethod != "shortcuts" {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(Color.adaptiveSecondaryText(colorScheme))
                            Text("Phone calls require manual confirmation due to macOS security")
                                .font(.caption)
                                .foregroundColor(Color.adaptiveSecondaryText(colorScheme))
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    // Test Section at the bottom
                    GroupBox {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "testtube.2")
                                    .foregroundColor(Color.adaptiveWarning(colorScheme))
                                Text("Test Notifications")
                                    .font(.subheadline)
                                    .foregroundColor(Color.adaptiveText(colorScheme))
                                Spacer()
                            }
                            
                            Divider()
                            
                            HStack(spacing: 12) {
                                if store.notificationSettings.smsEnabled {
                                    Button(action: {
                                        Task {
                                            await store.testSMSNotification()
                                        }
                                    }) {
                                        Label("Test SMS", systemImage: "message.fill")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color.adaptiveTheme(colorScheme, store: store))
                                    .controlSize(.regular)
                                    .disabled(store.notificationSettings.phoneNumber.isEmpty)
                                }
                                
                                if store.notificationSettings.phoneCallEnabled {
                                    Button(action: {
                                        Task {
                                            await store.testPhoneCallNotification()
                                        }
                                    }) {
                                        Label("Test Call", systemImage: "phone.fill")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color.adaptiveTheme(colorScheme, store: store))
                                    .controlSize(.regular)
                                    .disabled(store.notificationSettings.phoneNumber.isEmpty)
                                }
                            }
                            
                            if store.notificationSettings.phoneNumber.isEmpty {
                                Text("Enter phone number above to test")
                                    .font(.caption)
                                    .foregroundColor(Color.adaptiveError(colorScheme))
                            }
                        }
                        .padding(5)
                    }
                    
                    // Removed Twilio section - using Shortcuts and default apps instead
                    if false {
                        Text("📡 Twilio Configuration")
                            .font(.subheadline)
                            .bold()
                        
                        Text("Sign up at twilio.com (free trial: $15 credit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Account SID:")
                                .frame(width: 100, alignment: .trailing)
                            TextField("ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", text: $store.notificationSettings.twilioAccountSID)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        HStack {
                            Text("Auth Token:")
                                .frame(width: 100, alignment: .trailing)
                            SecureField("Your Auth Token", text: $store.notificationSettings.twilioAuthToken)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack {
                            Text("Twilio Number:")
                                .frame(width: 100, alignment: .trailing)
                            TextField("+1234567890", text: $store.notificationSettings.twilioFromNumber)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack {
                            if store.notificationSettings.smsEnabled {
                                Button("Test SMS") {
                                    Task {
                                        var testProduct = Product(url: "https://test.com")
                                        testProduct.name = "Test Product"
                                        testProduct.price = "$999.99"
                                        if store.notificationSettings.smsMethod == "shortcuts" {
                                            await store.sendSMSViaShortcuts(for: testProduct)
                                        } else {
                                            await store.sendTwilioSMS(for: testProduct)
                                        }
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            if store.notificationSettings.phoneCallEnabled {
                                Button("Test Call") {
                                    Task {
                                        if store.notificationSettings.callMethod == "shortcuts" {
                                            await store.initiateCallViaShortcuts()
                                        } else {
                                            await store.sendTwilioCall()
                                        }
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        } else if selectedTab == "telegram" {
                // Telegram Configuration
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Telegram Notifications", isOn: $store.notificationSettings.telegramEnabled)
                    
                    if store.notificationSettings.telegramEnabled {
                        Text("🤖 Telegram Bot (Instant & Free)")
                            .font(.subheadline)
                            .bold()
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Setup:")
                                .font(.caption)
                                .bold()
                            Text("1. Message @BotFather on Telegram")
                                .font(.caption)
                            Text("2. Create new bot with /newbot")
                                .font(.caption)
                            Text("3. Copy the bot token")
                                .font(.caption)
                            Text("4. Start chat with your bot")
                                .font(.caption)
                            Text("5. Get your chat ID from @userinfobot")
                                .font(.caption)
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(5)
                        
                        HStack {
                            Text("Bot Token:")
                                .frame(width: 100, alignment: .trailing)
                            TextField("123456789:ABCdef...", text: $store.notificationSettings.telegramBotToken)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack {
                            Text("Chat ID:")
                                .frame(width: 100, alignment: .trailing)
                            TextField("123456789", text: $store.notificationSettings.telegramChatID)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button("Test Telegram") {
                            Task {
                                var testProduct = Product(url: "https://test.com")
                                testProduct.name = "Test Product"
                                testProduct.price = "$999.99"
                                await store.sendTelegramMessage(for: testProduct)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                // Discord Configuration
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Discord Notifications", isOn: $store.notificationSettings.discordEnabled)
                    
                    if store.notificationSettings.discordEnabled {
                        Text("👾 Discord Webhook (Instant & Free)")
                            .font(.subheadline)
                            .bold()
                        
                        Text("Server Settings > Integrations > Webhooks > New Webhook")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Webhook URL:")
                                .frame(width: 100, alignment: .trailing)
                            TextField("https://discord.com/api/webhooks/...", text: $store.notificationSettings.discordWebhookURL)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button("Test Discord") {
                            Task {
                                var testProduct = Product(url: "https://test.com")
                                testProduct.name = "Test Product"
                                testProduct.price = "$999.99"
                                await store.sendDiscordMessage(for: testProduct)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}

// MARK: - Webhook Settings
struct WebhookSettingsView: View {
    @ObservedObject var store: ProductStore
    @State private var newWebhook = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Toggle("Enable Webhook Notifications", isOn: $store.notificationSettings.webhookEnabled)
            
            if store.notificationSettings.webhookEnabled {
                Text("Webhooks (Discord, Slack, IFTTT, etc.)")
                    .font(.headline)
                
                HStack {
                    TextField("https://discord.com/api/webhooks/...", text: $newWebhook)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        if !newWebhook.isEmpty {
                            store.notificationSettings.webhookURLs.append(newWebhook)
                            newWebhook = ""
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                ForEach(store.notificationSettings.webhookURLs, id: \.self) { webhook in
                    HStack {
                        Text(webhook)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button(action: {
                            store.notificationSettings.webhookURLs.removeAll { $0 == webhook }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Advanced Settings
struct AdvancedSettingsView: View {
    @ObservedObject var store: ProductStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Enhanced Notification Options")
                .font(.headline)
            
            Toggle("Persistent Notifications (Stay until dismissed)", isOn: $store.notificationSettings.persistentNotifications)
            
            Toggle("Critical Alerts (Bypass Do Not Disturb)", isOn: $store.notificationSettings.criticalAlerts)
            
            Toggle("Retry Failed Notifications", isOn: $store.notificationSettings.retryFailedNotifications)
            
            if store.notificationSettings.retryFailedNotifications {
                HStack {
                    Text("Max Retry Attempts:")
                    Picker("", selection: $store.notificationSettings.maxRetryAttempts) {
                        Text("1").tag(1)
                        Text("3").tag(3)
                        Text("5").tag(5)
                        Text("10").tag(10)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 80)
                }
            }
            
            Divider()
            
            Text("Alert History")
                .font(.headline)
            
            HStack {
                Text("Total Alerts: \(store.alertHistory.count)")
                Spacer()
                Text("Unacknowledged: \(store.alertHistory.filter { !$0.acknowledged }.count)")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}