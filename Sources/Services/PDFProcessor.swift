import AppKit
import PDFKit
import Foundation

/// Service for converting PDF pages to high-resolution PNG images
enum PDFProcessor {
    
    enum PDFProcessorError: LocalizedError {
        case cannotOpenDocument
        case noPages
        case renderFailed
        case saveFailed
        
        var errorDescription: String? {
            switch self {
            case .cannotOpenDocument: return "Cannot open PDF document"
            case .noPages: return "PDF has no pages"
            case .renderFailed: return "Failed to render PDF page"
            case .saveFailed: return "Failed to save PNG image"
            }
        }
    }
    
    /// Renders all pages of a PDF to high-resolution PNGs
    /// - Parameters:
    ///   - pdfURL: URL to the PDF file
    ///   - dpi: Resolution for rendering (default 300 DPI)
    /// - Returns: Array of URLs to the generated PNGs in the temporary directory
    static func renderAllPages(of pdfURL: URL, dpi: CGFloat = 300) throws -> [URL] {
        guard let document = PDFDocument(url: pdfURL) else {
            throw PDFProcessorError.cannotOpenDocument
        }
        
        var outputURLs: [URL] = []
        let pageCount = document.pageCount
        
        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }
            
            // Get page bounds (in points, 72 points = 1 inch)
            let pageBounds = page.bounds(for: .mediaBox)
            
            // Calculate scale for desired DPI
            let scale = dpi / 72.0
            
            let width = Int(pageBounds.width * scale)
            let height = Int(pageBounds.height * scale)
            
            // Create bitmap context
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ) else {
                continue
            }
            
            // Fill with white background
            context.setFillColor(CGColor.white)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            
            // Scale and draw PDF page
            context.saveGState()
            context.scaleBy(x: scale, y: scale)
            if let pageRef = page.pageRef {
                context.drawPDFPage(pageRef)
            }
            context.restoreGState()
            
            guard let cgImage = context.makeImage() else { continue }
            
            // Create NSImage from CGImage
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
            
            // Save to temporary directory
            let tempDir = FileManager.default.temporaryDirectory
            let filename = pdfURL.deletingPathExtension().lastPathComponent + "_page\(i+1).png"
            let outputURL = tempDir.appendingPathComponent(filename)
            
            guard let tiffData = nsImage.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                continue
            }
            
            try pngData.write(to: outputURL)
            outputURLs.append(outputURL)
        }
        
        if outputURLs.isEmpty {
            throw PDFProcessorError.noPages
        }
        
        return outputURLs
    }
    
    /// Renders the first page of a PDF to a high-resolution PNG
    static func renderFirstPage(of pdfURL: URL, dpi: CGFloat = 300) throws -> URL {
        let urls = try renderAllPages(of: pdfURL, dpi: dpi)
        return urls[0]
    }
    
    /// Creates a thumbnail from an image file
    static func createThumbnail(from url: URL, maxSize: CGFloat = 200) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        
        let originalSize = image.size
        let scale = min(maxSize / originalSize.width, maxSize / originalSize.height, 1.0)
        let newSize = NSSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )
        
        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        thumbnail.unlockFocus()
        
        return thumbnail
    }
    
    /// Gets the creation date of a file
    static func getCreationDate(of url: URL) -> Date {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.creationDate] as? Date ?? Date()
    }
}
