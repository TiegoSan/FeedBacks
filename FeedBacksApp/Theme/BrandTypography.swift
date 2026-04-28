import AppKit

enum BrandTypography {
    static var lobsterFontName: String {
        if NSFont(name: "Lobster", size: 12) != nil {
            return "Lobster"
        }
        if NSFont(name: "Lobster-Regular", size: 12) != nil {
            return "Lobster-Regular"
        }
        return "Helvetica Neue"
    }
}
