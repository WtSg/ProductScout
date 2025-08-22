//
//  WebsiteDetector.swift
//  Product Scout
//
//  Automatic website detection for multi-retailer product tracking
//

import Foundation

// MARK: - Supported Websites
enum SupportedWebsite: String, CaseIterable, Codable {
    case bestBuy = "bestbuy"
    case target = "target"
    case canon = "canon"
    case ricoh = "ricoh"
    case unsupported = "unsupported"
    
    var displayName: String {
        switch self {
        case .bestBuy:
            return "Best Buy"
        case .target:
            return "Target"
        case .canon:
            return "Canon"
        case .ricoh:
            return "Ricoh"
        case .unsupported:
            return "Not Supported"
        }
    }
    
    var logoIcon: String {
        switch self {
        case .bestBuy:
            return "b.square.fill"
        case .target:
            return "target"
        case .canon:
            return "camera.fill"
        case .ricoh:
            return "camera.aperture"
        case .unsupported:
            return "questionmark.square.dashed"
        }
    }
    
    var primaryColor: String {
        switch self {
        case .bestBuy:
            return "#5C9FFF" // Lighter, softer Best Buy Blue
        case .target:
            return "#CC0000" // Target Red
        case .canon:
            return "#E60012" // Canon Red
        case .ricoh:
            return "#00539B" // Ricoh Blue
        case .unsupported:
            return "#8E8E93" // Gray
        }
    }
    
    var isSupported: Bool {
        return self != .unsupported
    }
}

// MARK: - Website Detection Result
struct WebsiteDetectionResult {
    let website: SupportedWebsite
    let confidence: Double // 0.0 to 1.0
    let reason: String
}

// MARK: - Website Detector
class WebsiteDetector {
    
    // MARK: - Main Detection Method
    static func detectWebsite(from url: String) -> WebsiteDetectionResult {
        let normalizedURL = url.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Best Buy Detection
        if let bestBuyResult = detectBestBuy(normalizedURL) {
            return bestBuyResult
        }
        
        // Target Detection
        if let targetResult = detectTarget(normalizedURL) {
            return targetResult
        }
        
        // Canon Detection
        if let canonResult = detectCanon(normalizedURL) {
            return canonResult
        }
        
        // Ricoh Detection
        if let ricohResult = detectRicoh(normalizedURL) {
            return ricohResult
        }
        
        // Unsupported website
        return WebsiteDetectionResult(
            website: .unsupported,
            confidence: 1.0,
            reason: "Website not recognized or supported"
        )
    }
    
    // MARK: - Best Buy Detection
    private static func detectBestBuy(_ url: String) -> WebsiteDetectionResult? {
        let bestBuyPatterns = [
            "bestbuy.com",
            "www.bestbuy.com",
            "bestbuy.ca",
            "www.bestbuy.ca"
        ]
        
        for pattern in bestBuyPatterns {
            if url.contains(pattern) {
                let confidence: Double = url.contains("bestbuy.com") ? 1.0 : 0.9
                return WebsiteDetectionResult(
                    website: .bestBuy,
                    confidence: confidence,
                    reason: "Detected Best Buy domain: \(pattern)"
                )
            }
        }
        return nil
    }
    
    // MARK: - Target Detection
    private static func detectTarget(_ url: String) -> WebsiteDetectionResult? {
        let targetPatterns = [
            "target.com",
            "www.target.com",
            "target.ca",
            "www.target.ca"
        ]
        
        for pattern in targetPatterns {
            if url.contains(pattern) {
                let confidence: Double = url.contains("target.com") ? 1.0 : 0.9
                return WebsiteDetectionResult(
                    website: .target,
                    confidence: confidence,
                    reason: "Detected Target domain: \(pattern)"
                )
            }
        }
        return nil
    }
    
    // MARK: - Canon Detection
    private static func detectCanon(_ url: String) -> WebsiteDetectionResult? {
        let canonPatterns = [
            "canon.com",
            "www.canon.com",
            "usa.canon.com",
            "canon.ca",
            "www.canon.ca",
            "canon.co.uk",
            "www.canon.co.uk"
        ]
        
        for pattern in canonPatterns {
            if url.contains(pattern) {
                let confidence: Double = url.contains("canon.com") || url.contains("usa.canon.com") ? 1.0 : 0.95
                return WebsiteDetectionResult(
                    website: .canon,
                    confidence: confidence,
                    reason: "Detected Canon domain: \(pattern)"
                )
            }
        }
        return nil
    }
    
    // MARK: - Ricoh Detection
    private static func detectRicoh(_ url: String) -> WebsiteDetectionResult? {
        let ricohPatterns = [
            "ricoh-imaging.com",
            "us.ricoh-imaging.com",
            "www.ricoh-imaging.com",
            "ricoh-imaging.co.jp",
            "ricoh-imaging.co.uk"
        ]
        
        for pattern in ricohPatterns {
            if url.contains(pattern) {
                let confidence: Double = url.contains("ricoh-imaging.com") ? 1.0 : 0.95
                return WebsiteDetectionResult(
                    website: .ricoh,
                    confidence: confidence,
                    reason: "Detected Ricoh domain: \(pattern)"
                )
            }
        }
        return nil
    }
    
    // MARK: - Utility Methods
    static func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme != nil && url.host != nil
    }
    
    static func normalizeURL(_ urlString: String) -> String {
        var normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add https:// if no scheme is present
        if !normalized.hasPrefix("http://") && !normalized.hasPrefix("https://") {
            normalized = "https://" + normalized
        }
        
        return normalized
    }
    
    static func getSupportedWebsites() -> [SupportedWebsite] {
        return SupportedWebsite.allCases.filter { $0.isSupported }
    }
}