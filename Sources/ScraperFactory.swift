//
//  ScraperFactory.swift
//  Product Scout
//
//  Product scraper protocol and factory for multi-website support
//

import Foundation
import WebKit
import AppKit

// MARK: - Scraper Result
struct ScraperResult {
    let status: String
    let price: String
    let isAvailable: Bool
    let details: String
    let website: SupportedWebsite
}

// MARK: - Product Scraper Protocol
@MainActor
protocol ProductScraper {
    var supportedWebsite: SupportedWebsite { get }
    var isInitialized: Bool { get }
    
    func initialize() async
    func checkProduct(url: String) async -> ScraperResult
    func cleanup()
}

// MARK: - Base Scraper
@MainActor
class BaseScraper: NSObject {
    var webView: WKWebView!
    var continuation: CheckedContinuation<ScraperResult, Never>?
    let supportedWebsite: SupportedWebsite
    var isInitialized: Bool = false
    
    init(website: SupportedWebsite) {
        self.supportedWebsite = website
        super.init()
    }
    
    func initialize() async {
        guard !isInitialized else { return }
        setupWebView()
        isInitialized = true
    }
    
    func setupWebView() {
        let config = WKWebViewConfiguration()
        
        // Basic JavaScript helpers (can be overridden by subclasses)
        let jsScript = """
        window.getAllPrices = function() {
            let prices = [];
            document.querySelectorAll('[class*="price"], [data-testid*="price"], span').forEach(el => {
                let text = el.textContent || '';
                let match = text.match(/\\$([0-9,]+\\.?[0-9]{0,2})/);
                if (match && el.offsetHeight > 0) {
                    let rect = el.getBoundingClientRect();
                    prices.push({
                        price: match[1].replace(',', ''),
                        text: text.trim(),
                        size: window.getComputedStyle(el).fontSize,
                        visible: rect.top >= 0 && rect.top <= window.innerHeight
                    });
                }
            });
            return prices;
        };
        
        window.getPageText = function() {
            return document.body.innerText || document.body.textContent || '';
        };
        """
        
        let userScript = WKUserScript(
            source: jsScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        
        config.userContentController.addUserScript(userScript)
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
    }
    
    func cleanup() {
        webView = nil
        continuation = nil
        isInitialized = false
    }
}

// MARK: - WKNavigationDelegate
extension BaseScraper: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Subclasses should override this method
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if let continuation = self.continuation {
                self.continuation = nil
                continuation.resume(returning: ScraperResult(
                    status: "❌ Not Implemented",
                    price: "—",
                    isAvailable: false,
                    details: "Scraper not implemented for \(self.supportedWebsite.displayName)",
                    website: self.supportedWebsite
                ))
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ Navigation failed: \(error.localizedDescription)")
        if let continuation = self.continuation {
            self.continuation = nil
            continuation.resume(returning: ScraperResult(
                status: "❌ Error",
                price: "—",
                isAvailable: false,
                details: "Failed to load page: \(error.localizedDescription)",
                website: supportedWebsite
            ))
        }
    }
}

// MARK: - Scraper Factory
class ScraperFactory {
    private static var scraperInstances: [SupportedWebsite: ProductScraper] = [:]
    
    @MainActor
    static func createScraper(for website: SupportedWebsite) -> ProductScraper {
        // Reuse existing instance if available
        if let existingScraper = scraperInstances[website] {
            return existingScraper
        }
        
        let scraper: ProductScraper
        
        switch website {
        case .bestBuy:
            scraper = BestBuyScraper()
        case .target:
            scraper = TargetScraper()
        case .canon:
            scraper = CanonScraper()
        case .ricoh:
            scraper = RicohScraper()
        case .unsupported:
            scraper = GenericScraper()
        }
        
        // Cache the instance
        scraperInstances[website] = scraper
        return scraper
    }
    
    @MainActor
    static func getScraper(for url: String) -> ProductScraper {
        let detectionResult = WebsiteDetector.detectWebsite(from: url)
        return createScraper(for: detectionResult.website)
    }
    
    static func clearCache() {
        scraperInstances.removeAll()
    }
}

// MARK: - Placeholder Scrapers (To be implemented)

// BestBuy Scraper - Implemented in BestBuyScraper.swift

// Target Scraper - Full implementation
@MainActor
class TargetScraper: BaseScraper, ProductScraper {
    init() {
        super.init(website: .target)
    }
    
    func checkProduct(url: String) async -> ScraperResult {
        guard let url = URL(string: url) else {
            return ScraperResult(
                status: "❌ Invalid URL",
                price: "—",
                isAvailable: false,
                details: "Invalid URL format",
                website: .target
            )
        }
        
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            let request = URLRequest(url: url)
            self.webView.load(request)
            
            // Timeout handling
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
                guard let self = self, let continuation = self.continuation else { return }
                self.continuation = nil
                continuation.resume(returning: ScraperResult(
                    status: "❌ Timeout",
                    price: "—",
                    isAvailable: false,
                    details: "Request timed out",
                    website: .target
                ))
            }
        }
    }
    
    override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait for dynamic content
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.extractTargetProductInfo()
        }
    }
    
    private func extractTargetProductInfo() {
        let js = """
        (function() {
            var result = {};
            
            // First, check if there are ANY visible buttons at all
            var allButtons = document.querySelectorAll('button');
            var visibleButtons = [];
            for (let btn of allButtons) {
                if (btn.offsetHeight > 0 && btn.offsetWidth > 0) {
                    visibleButtons.push(btn);
                }
            }
            
            // Look for add to cart type buttons with various methods
            var addToCartFound = false;
            var shipItButton = null;
            var pickupButton = null;
            
            // Method 1: Check by data-test attributes
            var testSelectors = [
                'button[data-test="shipItButton"]',
                'button[data-test="shippingButton"]', 
                'button[data-test="chooseOptionsButton"]',
                'button[data-test="addToCartButton"]',
                '[data-test="fulfillment-add-to-cart-button"]',
                '[data-test*="AddToCart"]',
                '[data-test*="add-to-cart"]'
            ];
            
            for (let selector of testSelectors) {
                var btn = document.querySelector(selector);
                if (btn && btn.offsetHeight > 0) {
                    shipItButton = btn;
                    addToCartFound = true;
                    break;
                }
            }
            
            // Method 2: Check button text content
            if (!addToCartFound) {
                for (let btn of visibleButtons) {
                    var text = (btn.textContent || '').toLowerCase();
                    var ariaLabel = (btn.getAttribute('aria-label') || '').toLowerCase();
                    
                    // Check for shipping/delivery buttons
                    if (text.includes('ship') || text.includes('deliver') || 
                        text.includes('add to cart') || text.includes('add for') ||
                        ariaLabel.includes('add') || ariaLabel.includes('ship')) {
                        shipItButton = btn;
                        addToCartFound = true;
                        break;
                    }
                    
                    // Check for pickup buttons
                    if (text.includes('pick') || text.includes('pickup')) {
                        pickupButton = btn;
                    }
                }
            }
            
            // Method 3: Look for any button inside fulfillment sections
            if (!addToCartFound) {
                var fulfillmentSections = document.querySelectorAll('[data-test*="fulfillment"], [class*="fulfillment"], [id*="fulfillment"]');
                for (let section of fulfillmentSections) {
                    var buttons = section.querySelectorAll('button');
                    for (let btn of buttons) {
                        if (btn.offsetHeight > 0) {
                            shipItButton = btn;
                            addToCartFound = true;
                            break;
                        }
                    }
                    if (addToCartFound) break;
                }
            }
            
            // Pickup button already found above in Method 2
            
            // Look for all fulfillment methods
            var shippingButton = document.querySelector('button[data-test="shippingButton"]');
            var pickupButton = document.querySelector('button[data-test="orderPickupButton"]');
            var deliveryButton = document.querySelector('button[data-test="scheduledDeliveryButton"]');
            var showInStockStores = document.querySelector('button[data-test="showInStockPrimaryButton"]');
            
            // Check ALL fulfillment cells for availability
            var availableMethods = [];
            
            // Check shipping
            var shippingCell = document.querySelector('[data-test="fulfillment-cell-shipping"]');
            var shippingAvailable = false;
            if (shippingCell) {
                var shippingText = shippingCell.textContent || '';
                if (shippingText.includes('Arrives') || shippingText.includes('Get it by')) {
                    shippingAvailable = true;
                    availableMethods.push('Shipping');
                }
            }
            
            // Check pickup
            var pickupCell = document.querySelector('[data-test="fulfillment-cell-pickup"]');
            var pickupAvailable = false;
            if (pickupCell) {
                var pickupText = pickupCell.textContent || '';
                if (!pickupText.includes('Not available') && (pickupText.includes('Ready') || pickupText.includes('Available'))) {
                    pickupAvailable = true;
                    availableMethods.push('Pickup');
                }
            }
            
            // Check delivery
            var deliveryCell = document.querySelector('[data-test="fulfillment-cell-delivery"]');
            var deliveryAvailable = false;
            if (deliveryCell) {
                var deliveryText = deliveryCell.textContent || '';
                if (deliveryText.includes('Available') || deliveryText.includes('Get it')) {
                    deliveryAvailable = true;
                    availableMethods.push('Delivery');
                }
            }
            
            // Check if ANY method is available
            var anyMethodAvailable = shippingAvailable || pickupAvailable || deliveryAvailable;
            
            // Check for explicit out of stock indicators
            var outOfStockMessage = false;
            var notAvailableOnline = document.querySelector('[data-test="outOfStockMessage"]');
            
            // Only trust the out of stock message if shipping is also not available
            if (notAvailableOnline && !shippingAvailable) {
                outOfStockMessage = true;
            }
            
            // Get price - Target uses various selectors
            var priceElement = document.querySelector('[data-test="product-price"]');
            if (!priceElement) {
                priceElement = document.querySelector('span[data-test="product-price"]');
            }
            if (!priceElement) {
                // Try to find price by pattern
                var spans = document.querySelectorAll('span');
                for (let span of spans) {
                    if (span.textContent && span.textContent.match(/^\\$[0-9,]+\\.?[0-9]*$/)) {
                        priceElement = span;
                        break;
                    }
                }
            }
            
            // Get product title
            var titleElement = document.querySelector('h1[data-test="product-title"]');
            if (!titleElement) {
                titleElement = document.querySelector('h1[itemprop="name"]');
            }
            if (!titleElement) {
                titleElement = document.querySelector('h1');
            }
            
            // Determine availability based on what we found
            var isAvailable = false;
            var status = "Checking...";
            
            // Determine availability based on ALL fulfillment methods
            if (anyMethodAvailable) {
                // Product is available through at least one method
                isAvailable = true;
                
                // Create status based on available methods
                if (availableMethods.length > 0) {
                    status = "Available: " + availableMethods.join(", ");
                } else {
                    status = "Available";
                }
            } else if (shippingButton && shippingButton.offsetHeight > 0) {
                // Has explicit shipping button
                isAvailable = true;
                status = "Available for Shipping";
            } else if (pickupButton && pickupButton.offsetHeight > 0) {
                // Has explicit pickup button
                isAvailable = true;
                status = "Available for Pickup";
            } else if (deliveryButton && deliveryButton.offsetHeight > 0) {
                // Has explicit delivery button
                isAvailable = true;
                status = "Available for Delivery";
            } else if (showInStockStores && !outOfStockMessage) {
                // Has in-store availability
                isAvailable = true;
                status = "Available in Stores";
            } else if (outOfStockMessage) {
                // Confirmed out of stock
                isAvailable = false;
                status = "Out of Stock";
            } else {
                // Check if ALL methods explicitly say not available
                var allNotAvailable = false;
                if (shippingCell && shippingCell.textContent.includes('Not available') &&
                    pickupCell && pickupCell.textContent.includes('Not available')) {
                    allNotAvailable = true;
                }
                
                if (allNotAvailable) {
                    isAvailable = false;
                    status = "Not Available";
                } else {
                    // Check for notify button
                    var notifyButton = document.querySelector('button[data-test="notifyMeButton"]');
                    if (notifyButton) {
                        isAvailable = false;
                        status = "Out of Stock";
                    } else {
                        // Can't determine
                        isAvailable = false;
                        status = "Check Website";
                    }
                }
            }
            
            result.available = isAvailable;
            result.price = priceElement ? priceElement.textContent.trim() : "Price not found";
            result.status = status;
            result.title = titleElement ? titleElement.textContent.trim() : null;
            
            return JSON.stringify(result);
        })()
        """
        
        webView.evaluateJavaScript(js) { [weak self] (result, error) in
            guard let self = self,
                  let continuation = self.continuation else { return }
            
            self.continuation = nil
            
            if let jsonString = result as? String,
               let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                let isAvailable = json["available"] as? Bool ?? false
                let price = json["price"] as? String ?? "—"
                let status = json["status"] as? String ?? "Unknown"
                
                let statusEmoji = isAvailable ? "✅" : "❌"
                let finalStatus = "\(statusEmoji) \(status)"
                
                continuation.resume(returning: ScraperResult(
                    status: finalStatus,
                    price: price,
                    isAvailable: isAvailable,
                    details: status,
                    website: .target
                ))
            } else {
                continuation.resume(returning: ScraperResult(
                    status: "❌ Error",
                    price: "—",
                    isAvailable: false,
                    details: "Failed to parse page",
                    website: .target
                ))
            }
        }
    }
}

// Canon Scraper - Full implementation
@MainActor
class CanonScraper: BaseScraper, ProductScraper {
    init() {
        super.init(website: .canon)
    }
    
    func checkProduct(url: String) async -> ScraperResult {
        guard let url = URL(string: url) else {
            return ScraperResult(
                status: "❌ Invalid URL",
                price: "N/A",
                isAvailable: false,
                details: "Invalid URL format",
                website: .canon
            )
        }
        
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            let request = URLRequest(url: url)
            self.webView.load(request)
            
            // Timeout handling
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
                guard let self = self, let continuation = self.continuation else { return }
                self.continuation = nil
                continuation.resume(returning: ScraperResult(
                    status: "❌ Timeout",
                    price: "N/A",
                    isAvailable: false,
                    details: "Request timed out",
                    website: .canon
                ))
            }
        }
    }
    
    override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait for dynamic content to load
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.extractCanonProductInfo()
        }
    }
    
    private func extractCanonProductInfo() {
        let js = """
        (function() {
            var result = {};
            
            // Look for "Add to Cart" button - Canon uses this for available products
            var addToCartButton = null;
            
            // Method 1: Look for button with specific text
            var buttons = document.querySelectorAll('button');
            for (let btn of buttons) {
                let text = (btn.textContent || '').toLowerCase();
                let ariaLabel = (btn.getAttribute('aria-label') || '').toLowerCase();
                
                if ((text.includes('add to cart') || text.includes('add to bag') || 
                     ariaLabel.includes('add to cart') || ariaLabel.includes('add to bag')) &&
                    btn.offsetHeight > 0) {
                    addToCartButton = btn;
                    break;
                }
            }
            
            // Method 2: Look for button by class or data attributes
            if (!addToCartButton) {
                var selectors = [
                    'button[data-qa="add-to-cart"]',
                    'button[class*="add-to-cart"]',
                    'button[class*="AddToCart"]',
                    '[data-qa="pdp-add-to-cart-button"]',
                    '[class*="ProductActions"] button'
                ];
                
                for (let selector of selectors) {
                    var btn = document.querySelector(selector);
                    if (btn && btn.offsetHeight > 0) {
                        addToCartButton = btn;
                        break;
                    }
                }
            }
            
            // Check for out of stock indicators
            var outOfStockFound = false;
            var outOfStockIndicators = [
                'out of stock',
                'sold out',
                'unavailable',
                'notify me',
                'coming soon',
                'temporarily unavailable'
            ];
            
            // Check page text for out of stock
            var pageText = document.body.innerText.toLowerCase();
            for (let indicator of outOfStockIndicators) {
                if (pageText.includes(indicator)) {
                    // But make sure it's not just in the footer or unrelated section
                    // Look specifically in the product area
                    var productSection = document.querySelector('[class*="product"], [id*="product"], main');
                    if (productSection && productSection.innerText.toLowerCase().includes(indicator)) {
                        outOfStockFound = true;
                        break;
                    }
                }
            }
            
            // Look for specific out of stock elements
            var outOfStockElements = document.querySelectorAll('[class*="out-of-stock"], [class*="OutOfStock"], [class*="unavailable"], [data-qa*="out-of-stock"]');
            if (outOfStockElements.length > 0) {
                for (let elem of outOfStockElements) {
                    if (elem.offsetHeight > 0) {
                        outOfStockFound = true;
                        break;
                    }
                }
            }
            
            // Check for "Notify Me" button which indicates out of stock
            var notifyButton = null;
            for (let btn of buttons) {
                let text = (btn.textContent || '').toLowerCase();
                if (text.includes('notify') && btn.offsetHeight > 0) {
                    notifyButton = btn;
                    outOfStockFound = true;
                    break;
                }
            }
            
            // Get price - Extract ONLY the numeric value
            var priceText = null;
            var priceSelectors = [
                '[class*="price"][class*="current"]',
                '[class*="Price"][class*="Current"]',
                '[data-qa="product-price"]',
                '[class*="product-price"]',
                '[class*="ProductPrice"]',
                'span[class*="price"]',
                '[aria-label*="price"]'
            ];
            
            for (let selector of priceSelectors) {
                var elem = document.querySelector(selector);
                if (elem && elem.textContent) {
                    // Extract just the price number from the text
                    let matches = elem.textContent.match(/\\$([0-9,]+\\.?[0-9]{0,2})/);
                    if (matches && matches[0]) {
                        // Validate it's a reasonable price
                        let priceNum = parseFloat(matches[1].replace(',', ''));
                        if (priceNum > 0 && priceNum < 100000) {
                            priceText = matches[0];
                            break;
                        }
                    }
                }
            }
            
            // If no price found, search for any element with dollar sign
            if (!priceText) {
                var allElements = document.querySelectorAll('span, div, p');
                for (let elem of allElements) {
                    let text = elem.textContent || '';
                    // Look for price pattern and extract ONLY the price
                    let matches = text.match(/\\$([0-9,]+\\.?[0-9]{0,2})/);
                    if (matches && matches[0] && elem.offsetHeight > 0) {
                        // Validate it's a reasonable price
                        let priceNum = parseFloat(matches[1].replace(',', ''));
                        if (priceNum > 0 && priceNum < 100000) {
                            priceText = matches[0];
                            break;
                        }
                    }
                }
            }
            
            // Get product title
            var titleElement = document.querySelector('h1[class*="product"], h1[class*="Product"], [data-qa="product-title"], h1');
            
            // Determine availability
            var isAvailable = false;
            var status = "Checking...";
            
            if (addToCartButton && !outOfStockFound) {
                // Has Add to Cart and no out of stock indicators
                isAvailable = true;
                status = "In Stock";
            } else if (outOfStockFound || notifyButton) {
                // Explicitly out of stock
                isAvailable = false;
                status = "Out of Stock";
            } else if (!addToCartButton && !outOfStockFound) {
                // No add to cart but also no out of stock - might be a loading issue
                // Check if there's any product content at all
                if (titleElement || priceText) {
                    // Product page loaded but no add to cart
                    isAvailable = false;
                    status = "Unavailable";
                } else {
                    // Page might not have loaded properly
                    isAvailable = false;
                    status = "Check Website";
                }
            } else {
                isAvailable = false;
                status = "Unavailable";
            }
            
            result.available = isAvailable;
            result.price = priceText || "N/A";
            result.status = status;
            result.title = titleElement ? titleElement.textContent.trim() : null;
            result.hasAddToCart = !!addToCartButton;
            result.hasOutOfStock = outOfStockFound;
            
            return JSON.stringify(result);
        })()
        """
        
        webView.evaluateJavaScript(js) { [weak self] (result, error) in
            guard let self = self,
                  let continuation = self.continuation else { return }
            
            self.continuation = nil
            
            if let jsonString = result as? String,
               let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                let isAvailable = json["available"] as? Bool ?? false
                var price = json["price"] as? String ?? "N/A"
                
                // Additional validation in Swift to ensure price is clean
                if price != "N/A" && !price.starts(with: "$") {
                    price = "N/A"
                }
                if price.count > 15 { // Price shouldn't be longer than $99,999.99
                    price = "N/A"
                }
                
                let status = json["status"] as? String ?? "Unknown"
                
                let statusEmoji = isAvailable ? "✅" : "❌"
                let finalStatus = "\(statusEmoji) \(status)"
                
                continuation.resume(returning: ScraperResult(
                    status: finalStatus,
                    price: price,
                    isAvailable: isAvailable,
                    details: status,
                    website: .canon
                ))
            } else {
                continuation.resume(returning: ScraperResult(
                    status: "❌ Error",
                    price: "N/A",
                    isAvailable: false,
                    details: "Failed to parse page",
                    website: .canon
                ))
            }
        }
    }
}

// Ricoh Scraper - Full implementation
@MainActor
class RicohScraper: BaseScraper, ProductScraper {
    init() {
        super.init(website: .ricoh)
    }
    
    func checkProduct(url: String) async -> ScraperResult {
        guard let url = URL(string: url) else {
            return ScraperResult(
                status: "❌ Invalid URL",
                price: "N/A",
                isAvailable: false,
                details: "Invalid URL format",
                website: .ricoh
            )
        }
        
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            let request = URLRequest(url: url)
            self.webView.load(request)
            
            // Timeout handling
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
                guard let self = self, let continuation = self.continuation else { return }
                self.continuation = nil
                continuation.resume(returning: ScraperResult(
                    status: "❌ Timeout",
                    price: "N/A",
                    isAvailable: false,
                    details: "Request timed out",
                    website: .ricoh
                ))
            }
        }
    }
    
    override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait for dynamic content to load
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.extractRicohProductInfo()
        }
    }
    
    private func extractRicohProductInfo() {
        let js = """
        (function() {
            var result = {};
            
            // Look for "Add to Cart" or "Buy Now" button - Ricoh uses both
            var addToCartButton = null;
            
            // Method 1: Look for button with specific text
            var buttons = document.querySelectorAll('button, a[class*="btn"], a[role="button"]');
            for (let btn of buttons) {
                let text = (btn.textContent || '').toLowerCase();
                let ariaLabel = (btn.getAttribute('aria-label') || '').toLowerCase();
                
                // Ricoh uses "Add to Cart" or "Buy Now" for available products
                if ((text.includes('add to cart') || text.includes('buy now') || 
                     text.includes('add to bag') || text.includes('purchase') ||
                     ariaLabel.includes('add to cart') || ariaLabel.includes('buy')) &&
                    btn.offsetHeight > 0) {
                    // Make sure it's not disabled
                    if (!btn.disabled && !btn.classList.contains('disabled')) {
                        addToCartButton = btn;
                        break;
                    }
                }
            }
            
            // Method 2: Look for button by class or ID patterns
            if (!addToCartButton) {
                var selectors = [
                    'button[id*="add-to-cart"]',
                    'button[class*="add-to-cart"]',
                    'button[class*="AddToCart"]',
                    'a[class*="buy-now"]',
                    'a[class*="buy-button"]',
                    '[data-action="add-to-cart"]',
                    '.product-form__buttons button[type="submit"]',
                    '.product__submit',
                    '.btn-addtocart'
                ];
                
                for (let selector of selectors) {
                    var btn = document.querySelector(selector);
                    if (btn && btn.offsetHeight > 0 && !btn.disabled) {
                        addToCartButton = btn;
                        break;
                    }
                }
            }
            
            // Check for out of stock indicators
            var outOfStockFound = false;
            var outOfStockIndicators = [
                'out of stock',
                'sold out',
                'unavailable',
                'notify me',
                'coming soon',
                'temporarily unavailable',
                'currently unavailable'
            ];
            
            // Check page text for out of stock
            var pageText = document.body.innerText.toLowerCase();
            for (let indicator of outOfStockIndicators) {
                if (pageText.includes(indicator)) {
                    // Look specifically in the product area, not footer
                    var productSection = document.querySelector('[class*="product"], [id*="product"], .product-single, main');
                    if (productSection && productSection.innerText.toLowerCase().includes(indicator)) {
                        outOfStockFound = true;
                        break;
                    }
                }
            }
            
            // Look for specific out of stock elements
            var outOfStockElements = document.querySelectorAll(
                '[class*="out-of-stock"], [class*="OutOfStock"], ' +
                '[class*="unavailable"], [class*="sold-out"], ' +
                '.product-form__buttons--sold-out'
            );
            if (outOfStockElements.length > 0) {
                for (let elem of outOfStockElements) {
                    if (elem.offsetHeight > 0) {
                        outOfStockFound = true;
                        break;
                    }
                }
            }
            
            // Get price - Extract ONLY the numeric value, not navigation text
            var priceText = null;
            var priceSelectors = [
                '.product__price',
                '.price__regular',
                '.price-item--regular',
                '[class*="product-price"]',
                '[class*="ProductPrice"]',
                '.price',
                'span[class*="price"]:not([class*="compare"])',
                '[data-product-price]',
                '.product-single__price'
            ];
            
            for (let selector of priceSelectors) {
                var elem = document.querySelector(selector);
                if (elem && elem.textContent) {
                    // Extract just the price number from the text
                    let matches = elem.textContent.match(/\\$([0-9,]+\\.?[0-9]{0,2})/);
                    if (matches && matches[0]) {
                        // Validate it's a reasonable price
                        let priceNum = parseFloat(matches[1].replace(',', ''));
                        if (priceNum > 0 && priceNum < 100000) {
                            priceText = matches[0];
                            break;
                        }
                    }
                }
            }
            
            // If no price found, search for any element with dollar sign
            if (!priceText) {
                var allElements = document.querySelectorAll('span, div, p');
                for (let elem of allElements) {
                    let text = elem.textContent || '';
                    // Skip elements that contain navigation text
                    if (text.toLowerCase().includes('products in') || 
                        text.toLowerCase().includes('online shop') ||
                        text.toLowerCase().includes('community') ||
                        text.length > 100) {
                        continue;
                    }
                    
                    // Look for price pattern and extract ONLY the price
                    let matches = text.match(/\\$([0-9,]+\\.?[0-9]{0,2})/);
                    if (matches && matches[0] && elem.offsetHeight > 0) {
                        // Make sure it's not a compared/old price
                        if (!elem.classList.contains('compare') && 
                            !elem.classList.contains('was') &&
                            !elem.classList.contains('old')) {
                            // Validate it's a reasonable price
                            let priceNum = parseFloat(matches[1].replace(',', ''));
                            if (priceNum > 0 && priceNum < 100000) {
                                priceText = matches[0];
                                break;
                            }
                        }
                    }
                }
            }
            
            // Get product title
            var titleElement = document.querySelector(
                'h1[class*="product"], h1[class*="Product"], ' +
                '.product__title, .product-single__title, ' +
                '[data-product-title], h1'
            );
            
            // Determine availability
            var isAvailable = false;
            var status = "Checking...";
            
            if (addToCartButton && !outOfStockFound) {
                // Has Add to Cart/Buy Now and no out of stock indicators
                isAvailable = true;
                status = "In Stock";
            } else if (outOfStockFound) {
                // Explicitly out of stock
                isAvailable = false;
                status = "Out of Stock";
            } else if (!addToCartButton && !outOfStockFound) {
                // No add to cart but also no explicit out of stock
                // Check if product page loaded
                if (titleElement || priceElement) {
                    // Product page loaded but no buy button
                    isAvailable = false;
                    status = "Unavailable";
                } else {
                    // Page might not have loaded properly
                    isAvailable = false;
                    status = "Check Website";
                }
            } else {
                isAvailable = false;
                status = "Unavailable";
            }
            
            result.available = isAvailable;
            result.price = priceText || "N/A";
            result.status = status;
            result.title = titleElement ? titleElement.textContent.trim() : null;
            result.hasAddToCart = !!addToCartButton;
            result.hasOutOfStock = outOfStockFound;
            
            return JSON.stringify(result);
        })()
        """
        
        webView.evaluateJavaScript(js) { [weak self] (result, error) in
            guard let self = self,
                  let continuation = self.continuation else { return }
            
            self.continuation = nil
            
            if let jsonString = result as? String,
               let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                let isAvailable = json["available"] as? Bool ?? false
                var price = json["price"] as? String ?? "N/A"
                
                // Additional validation in Swift to ensure price is clean
                if price != "N/A" && !price.starts(with: "$") {
                    price = "N/A"
                }
                if price.count > 15 { // Price shouldn't be longer than $99,999.99
                    price = "N/A"
                }
                
                let status = json["status"] as? String ?? "Unknown"
                
                let statusEmoji = isAvailable ? "✅" : "❌"
                let finalStatus = "\(statusEmoji) \(status)"
                
                continuation.resume(returning: ScraperResult(
                    status: finalStatus,
                    price: price,
                    isAvailable: isAvailable,
                    details: status,
                    website: .ricoh
                ))
            } else {
                continuation.resume(returning: ScraperResult(
                    status: "❌ Error",
                    price: "N/A",
                    isAvailable: false,
                    details: "Failed to parse page",
                    website: .ricoh
                ))
            }
        }
    }
}

// Generic Scraper - Fallback for unsupported sites
@MainActor
class GenericScraper: BaseScraper, ProductScraper {
    init() {
        super.init(website: .unsupported)
    }
    
    func checkProduct(url: String) async -> ScraperResult {
        return ScraperResult(
            status: "❌ Not Supported",
            price: "—",
            isAvailable: false,
            details: "This website is not supported for automatic tracking",
            website: .unsupported
        )
    }
}