//
//  BestBuyScraper.swift  
//  Product Scout
//
//  Best Buy specific product scraper with intelligent price and availability detection
//

import Foundation
import WebKit
import AppKit

@MainActor
class BestBuyScraper: BaseScraper, ProductScraper {
    
    init() {
        super.init(website: .bestBuy)
        print("🚀 Best Buy scraper initialized")
    }
    
    override func setupWebView() {
        let config = WKWebViewConfiguration()
        
        // Inject JavaScript to help extract data
        let jsScript = """
        // Helper to extract all visible prices
        window.getAllPrices = function() {
            let prices = [];
            // Look for price elements
            document.querySelectorAll('[class*="price"], [data-testid*="price"], span').forEach(el => {
                let text = el.textContent || '';
                let match = text.match(/\\$([0-9,]+\\.?[0-9]{0,2})/);
                if (match && el.offsetHeight > 0) { // Only visible elements
                    let rect = el.getBoundingClientRect();
                    prices.push({
                        price: match[1].replace(',', ''),
                        text: text.trim(),
                        size: window.getComputedStyle(el).fontSize,
                        top: rect.top,
                        left: rect.left,
                        visible: rect.top >= 0 && rect.top <= window.innerHeight
                    });
                }
            });
            return prices;
        };
        
        // Helper to check button states - FIND ANY ADD TO CART BUTTON
        window.checkButtons = function() {
            // Look for ANY button with "Add to cart" text
            let hasRealAddToCart = false;
            let hasSoldOut = false;
            let buttonText = '';
            
            document.querySelectorAll('button').forEach(btn => {
                let text = btn.textContent?.trim().toLowerCase() || '';
                
                // Check for Add to Cart (but not "Buy New")
                if (text === 'add to cart') {
                    hasRealAddToCart = true;
                    buttonText = btn.textContent?.trim() || '';
                }
                
                // Check for Sold Out or Unavailable - BE VERY SPECIFIC!
                // Only match exact button text, not partial matches
                if (text === 'sold out' || text === 'unavailable' || 
                    text === 'currently unavailable' || text === 'out of stock' ||
                    text === 'coming soon') {
                    // But NOT "pickupunavailable" or prices like "good$1,333.99"
                    if (!text.includes('pickup') && !text.includes('$')) {
                        hasSoldOut = true;
                        buttonText = btn.textContent?.trim() || '';
                    }
                }
            });
            
            return {
                hasAddToCart: hasRealAddToCart,
                hasSoldOut: hasSoldOut,
                buttonText: buttonText
            };
        };
        
        // READ THE ACTUAL PAGE TEXT LIKE A HUMAN
        window.readAvailabilityText = function() {
            let texts = [];
            
            // Look for the ACTUAL button text
            let buttons = document.querySelectorAll('button');
            buttons.forEach(btn => {
                let text = btn.textContent?.trim() || '';
                if (text) texts.push('Button: ' + text);
            });
            
            // Look for availability messages
            let availMessages = document.querySelectorAll('[class*="availability"], [class*="fulfillment"], [class*="message"], [class*="status"]');
            availMessages.forEach(el => {
                let text = el.textContent?.trim() || '';
                if (text && text.length > 2) texts.push('Status: ' + text);
            });
            
            // Look for Open Box specific text
            let openBoxSections = document.querySelectorAll('[class*="condition"], [class*="open-box"]');
            openBoxSections.forEach(el => {
                let text = el.textContent?.trim() || '';
                if (text && text.length > 2) texts.push('OpenBox: ' + text);
            });
            
            // Get any error or unavailable messages
            let errorMessages = document.querySelectorAll('[class*="error"], [class*="unavailable"], [class*="sold-out"]');
            errorMessages.forEach(el => {
                let text = el.textContent?.trim() || '';
                if (text && text.length > 2) texts.push('Error: ' + text);
            });
            
            return texts;
        };
        """
        
        let userScript = WKUserScript(source: jsScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(userScript)
        
        // Create full-size webview for accurate rendering
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), configuration: config)
        webView.navigationDelegate = self
    }
    
    func checkProduct(url: String) async -> ScraperResult {
        print("🔍 Checking URL: \(url)")
        
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            
            guard let requestURL = URL(string: url) else {
                continuation.resume(returning: ScraperResult(
                    status: "❌ Invalid URL",
                    price: "—",
                    isAvailable: false,
                    details: "Invalid URL format",
                    website: .bestBuy
                ))
                return
            }
            
            // Use varied user agents
            let userAgents = [
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15",
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            ]
            webView.customUserAgent = userAgents.randomElement()!
            
            let request = URLRequest(url: requestURL)
            webView.load(request)
            
            // Timeout after 60 seconds for more reliable scraping
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
                if let cont = self?.continuation {
                    self?.continuation = nil
                    cont.resume(returning: ScraperResult(
                        status: "⏰ Timeout",
                        price: "—",
                        isAvailable: false,
                        details: "Page took too long to load",
                        website: .bestBuy
                    ))
                }
            }
        }
    }
}

// MARK: - WKNavigationDelegate Override
extension BestBuyScraper {
    override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ Page loaded, analyzing...")
        
        // Wait for dynamic content to load
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.analyzePageIntelligently(webView)
        }
    }
    
    override func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ Navigation failed: \(error)")
        if let cont = continuation {
            continuation = nil
            cont.resume(returning: ScraperResult(
                status: "❌ Load Failed",
                price: "—",
                isAvailable: false,
                details: error.localizedDescription,
                website: .bestBuy
            ))
        }
    }
    
    private func analyzePageIntelligently(_ webView: WKWebView) {
        print("🧠 Starting intelligent analysis...")
        
        let url = webView.url?.absoluteString ?? ""
        let isOpenBox = url.contains("/openbox") || url.contains("condition=")
        
        // Step 1: Get all prices from the page
        webView.evaluateJavaScript("window.getAllPrices()") { [weak self] pricesResult, error in
            guard let self = self else { return }
            
            let prices = (pricesResult as? [[String: Any]]) ?? []
            print("💰 Found \(prices.count) prices on page")
            
            // Step 2: READ THE ACTUAL PAGE TEXT
            webView.evaluateJavaScript("window.readAvailabilityText()") { [weak self] pageTexts, error in
                guard let self = self else { return }
                
                let texts = (pageTexts as? [String]) ?? []
                print("📖 Reading page text like a human:")
                for text in texts {
                    print("   - \(text)")
                }
                
                // Step 3: Get button states
                webView.evaluateJavaScript("window.checkButtons()") { [weak self] buttonResult, error in
                    guard let self = self else { return }
                    
                    let buttons = (buttonResult as? [String: Any]) ?? [:]
                    let hasAddToCart = buttons["hasAddToCart"] as? Bool ?? false
                    let hasSoldOut = buttons["hasSoldOut"] as? Bool ?? false
                    
                    print("🔘 Button analysis: AddToCart=\(hasAddToCart), SoldOut=\(hasSoldOut)")
                    
                    // Step 4: Get full HTML for additional analysis
                    webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] htmlResult, error in
                        guard let self = self else { return }
                    
                    let html = (htmlResult as? String) ?? ""
                    
                    // Intelligent price selection
                    let selectedPrice = self.selectBestPrice(
                        prices: prices,
                        html: html,
                        isOpenBox: isOpenBox
                    )
                    
                    // Intelligent availability detection using ACTUAL PAGE TEXT
                    let isAvailable = self.determineAvailability(
                        html: html,
                        pageTexts: texts,
                        hasAddToCart: hasAddToCart,
                        hasSoldOut: hasSoldOut,
                        isOpenBox: isOpenBox,
                        hasPrice: selectedPrice != "—"
                    )
                    
                    if let cont = self.continuation {
                        self.continuation = nil
                        cont.resume(returning: ScraperResult(
                            status: isAvailable ? "✅ Available" : "❌ Unavailable",
                            price: selectedPrice,
                            isAvailable: isAvailable,
                            details: isAvailable ? "Item can be purchased" : "Item cannot be purchased",
                            website: .bestBuy
                        ))
                    }
                    }
                }
            }
        }
    }
    
    private func selectBestPrice(prices: [[String: Any]], html: String, isOpenBox: Bool) -> String {
        print("🎯 Selecting best price from \(prices.count) options...")
        
        // Extract numeric prices
        var priceOptions: [(value: Double, text: String, size: String, visible: Bool)] = []
        
        for priceData in prices {
            if let priceStr = priceData["price"] as? String,
               let priceValue = Double(priceStr),
               let text = priceData["text"] as? String,
               let size = priceData["size"] as? String,
               let visible = priceData["visible"] as? Bool {
                
                // Skip savings amounts (text contains "Save" or is just a small number)
                let textLower = text.lowercased()
                if textLower.contains("save") || textLower.contains("was") {
                    continue
                }
                
                priceOptions.append((value: priceValue, text: text, size: size, visible: visible))
            }
        }
        
        // Filter realistic prices (must be > $200 for cameras)
        priceOptions = priceOptions.filter { $0.value > 200 && $0.value < 50000 }
        
        if priceOptions.isEmpty {
            // Fallback: extract from JSON in HTML
            return extractPriceFromJSON(html: html, isOpenBox: isOpenBox)
        }
        
        // Sort by visibility and size (larger, visible prices are usually the main price)
        priceOptions.sort { a, b in
            if a.visible != b.visible { return a.visible }
            return a.size > b.size
        }
        
        // For Open Box: Look for the first visible price (usually the Open Box price)
        if isOpenBox {
            // Check HTML for condition (since we don't have URL here)
            let htmlLower = html.lowercased()
            let urlCondition = htmlLower.contains("condition=excellent") ? "excellent" : 
                              htmlLower.contains("condition=good") ? "good" : 
                              htmlLower.contains("condition=fair") ? "fair" : ""
            
            // First, try to find price with matching condition text
            for option in priceOptions where option.visible {
                let textLower = option.text.lowercased()
                if !urlCondition.isEmpty && textLower.contains(urlCondition) {
                    print("✅ Found Open Box \(urlCondition) price: $\(option.value)")
                    return String(format: "$%.2f", option.value)
                }
            }
            
            // For Open Box, the first visible price is usually the Open Box price
            // (NOT the "Buy New" price which comes later)
            if let firstVisible = priceOptions.first(where: { $0.visible }) {
                // Skip if it's clearly marked as "Buy New"
                if !firstVisible.text.lowercased().contains("buy new") {
                    print("✅ Using first visible price for Open Box: $\(firstVisible.value)")
                    return String(format: "$%.2f", firstVisible.value)
                }
            }
            
            // Fallback to lowest visible price
            if let lowestReasonable = priceOptions.filter({ $0.visible && !$0.text.lowercased().contains("buy new") }).min(by: { $0.value < $1.value }) {
                print("✅ Using lowest visible price for Open Box: $\(lowestReasonable.value)")
                return String(format: "$%.2f", lowestReasonable.value)
            }
        }
        
        // Default: use the most prominent (visible, large) price
        if let bestPrice = priceOptions.first {
            print("✅ Selected price: $\(bestPrice.value)")
            return String(format: "$%.2f", bestPrice.value)
        }
        
        return "—"
    }
    
    private func extractPriceFromJSON(html: String, isOpenBox: Bool) -> String {
        // Look for customerPrice in JSON (most reliable)
        let patterns = [
            "\"customerPrice\"\\s*:\\s*([0-9.]+)",
            "\"currentPrice\"\\s*:\\s*([0-9.]+)",
            "\"openBoxPrice\"\\s*:\\s*([0-9.]+)"
        ]
        
        var foundPrices: [Double] = []
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: html, range: NSRange(location: 0, length: html.count))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: html),
                       let price = Double(html[range]) {
                        foundPrices.append(price)
                    }
                }
            }
        }
        
        // Remove duplicates and sort
        foundPrices = Array(Set(foundPrices)).sorted()
        
        // For Open Box, prefer lower reasonable prices
        if isOpenBox && !foundPrices.isEmpty {
            if let price = foundPrices.first(where: { $0 > 100 }) {
                return String(format: "$%.2f", price)
            }
        }
        
        // Return first reasonable price
        if let price = foundPrices.first(where: { $0 > 50 && $0 < 50000 }) {
            return String(format: "$%.2f", price)
        }
        
        return "—"
    }
    
    private func determineAvailability(html: String, pageTexts: [String], hasAddToCart: Bool, hasSoldOut: Bool, 
                                      isOpenBox: Bool, hasPrice: Bool) -> Bool {
        let htmlLower = html.lowercased()
        
        print("🔍 Determining availability...")
        print("   Has Add to Cart: \(hasAddToCart)")
        print("   Has Sold Out: \(hasSoldOut)")
        print("   Is Open Box: \(isOpenBox)")
        print("   Has Price: \(hasPrice)")
        
        // Check for explicit unavailable signals
        if htmlLower.contains("currently unavailable") {
            print("❌ Found 'currently unavailable'")
            return false
        }
        
        // Check for 404/error pages
        if htmlLower.contains("page not found") || htmlLower.contains("404") {
            if !htmlLower.contains("add to cart") {
                print("❌ 404 error page")
                return false
            }
        }
        
        // READ THE PAGE LIKE A HUMAN WOULD
        print("👁️ Reading page text to determine availability...")
        
        // Join all page texts for analysis
        let allPageText = pageTexts.joined(separator: " ").lowercased()
        
        // DEALBREAKERS - If ANY of these appear, it's UNAVAILABLE
        let dealbreakers = [
            "sold out",
            "currently unavailable",
            "not available",
            "out of stock",
            "coming soon",
            "no longer available",
            "unavailable online",
            "unavailable for delivery",
            "this item is currently unavailable"
        ]
        
        for dealbreaker in dealbreakers {
            if allPageText.contains(dealbreaker) {
                print("🚫 DEALBREAKER FOUND: '\(dealbreaker)' - Item is UNAVAILABLE")
                return false
            }
        }
        
        // For Open Box items - SIMPLE AND CLEAR
        if isOpenBox {
            print("📦 Checking Open Box availability...")
            
            // MOST IMPORTANT: Do we have a real Add to Cart button?
            if !hasAddToCart {
                print("❌ NO Add to Cart button for Open Box - UNAVAILABLE")
                return false
            }
            
            // If there IS an Add to Cart button, check it's not disabled/sold out
            if hasSoldOut {
                print("❌ Add to Cart button is disabled/sold out - UNAVAILABLE")
                return false
            }
            
            // Has active Add to Cart button - it's available!
            print("✅ Has active Add to Cart button for Open Box - AVAILABLE")
            return true
        }
        
        // Regular items: More nuanced logic
        
        // Strong positive signal - if JSON says add_to_cart, it's available
        if htmlLower.contains("\"buttonstate\":\"add_to_cart\"") {
            print("✅ JSON indicates ADD_TO_CART")
            return true
        }
        
        // Check for shipping/pickup availability
        if htmlLower.contains("\"shippingeligible\":true") || 
           htmlLower.contains("\"pickupeligible\":true") {
            print("✅ Shipping or pickup available")
            return true
        }
        
        // If we have a valid price and Add to Cart button, likely available
        if hasPrice && hasAddToCart && !hasSoldOut {
            print("✅ Has price and active Add to Cart button")
            return true
        }
        
        // For regular items with a price > $200, lean towards available
        // (Best Buy sometimes shows misleading JSON)
        if hasPrice && !hasSoldOut {
            print("✅ Has valid price without explicit sold out button")
            return true
        }
        
        // Strong negative signal
        if htmlLower.contains("\"buttonstate\":\"sold_out\"") {
            print("❌ JSON indicates SOLD_OUT")
            return false
        }
        
        print("❌ No clear availability signals")
        return false
    }
}