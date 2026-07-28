import Foundation

/// Renders projected feature vectors as a self-contained SVG scatter plot.
///
/// Developer diagnostic. The output has no external references, so it opens in
/// any browser without network access, consistent with the project's offline
/// constraint.
public enum ScatterPlotSVG {

    /// Colours per zone, in canonical order. Distinguishable in greyscale by
    /// ordering as well as hue.
    private static let palette = ["#1f77b4", "#d62728", "#2ca02c", "#9467bd", "#8c564b"]

    /// Renders a plot.
    ///
    /// - Parameters:
    ///   - points: The points to draw, already projected to two dimensions.
    ///   - zones: Zone names in canonical order, deciding colour assignment.
    ///   - capturedVariance: Fraction of total variance the two axes carry.
    ///     Stated on the plot so a low-fidelity projection is not mistaken for
    ///     the space itself.
    ///   - width: Image width in pixels.
    ///   - height: Image height in pixels.
    /// - Returns: The SVG document.
    public static func render(
        points: [(point: InspectionPoint, x: Double, y: Double)],
        zones: [String],
        capturedVariance: Double,
        width: Int = 900,
        height: Int = 680
    ) -> String {
        let margin = 60.0
        let plotWidth = Double(width) - 2 * margin
        let plotHeight = Double(height) - 2 * margin - 60

        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 1
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 1
        let spanX = maxX - minX == 0 ? 1 : maxX - minX
        let spanY = maxY - minY == 0 ? 1 : maxY - minY

        func screen(_ x: Double, _ y: Double) -> (Double, Double) {
            (
                margin + (x - minX) / spanX * plotWidth,
                // SVG y grows downward; invert so the plot reads conventionally.
                margin + plotHeight - (y - minY) / spanY * plotHeight
            )
        }

        var svg = """
            <svg xmlns="http://www.w3.org/2000/svg" width="\(width)" height="\(height)" \
            viewBox="0 0 \(width) \(height)" font-family="-apple-system, sans-serif">
            <rect width="100%" height="100%" fill="#ffffff"/>
            <text x="\(margin)" y="30" font-size="16" fill="#111">\
            Tapper — calibration feature space (PCA)</text>
            <text x="\(margin)" y="50" font-size="12" fill="#555">\
            first two components carry \(String(format: "%.1f", capturedVariance * 100))% \
            of total variance</text>
            <rect x="\(margin)" y="\(margin)" width="\(plotWidth)" height="\(plotHeight)" \
            fill="none" stroke="#ddd"/>

            """

        for entry in points {
            let (cx, cy) = screen(entry.x, entry.y)
            let colour = colour(for: entry.point.zone, zones: zones)
            let x = String(format: "%.2f", cx)
            let y = String(format: "%.2f", cy)
            switch entry.point.kind {
            case .calibration:
                svg += """
                    <circle cx="\(x)" cy="\(y)" r="4" fill="\(colour)" fill-opacity="0.55"/>

                    """
            case .correct:
                svg += """
                    <circle cx="\(x)" cy="\(y)" r="5" fill="none" stroke="\(colour)" \
                    stroke-width="2"/>

                    """
            case .misclassified:
                // A cross: reads as an error without relying on colour.
                svg += """
                    <path d="M\(cx - 5),\(cy - 5) L\(cx + 5),\(cy + 5) \
                    M\(cx - 5),\(cy + 5) L\(cx + 5),\(cy - 5)" stroke="\(colour)" \
                    stroke-width="2.5"/>

                    """
            case .unknown:
                svg += """
                    <circle cx="\(x)" cy="\(y)" r="5" fill="none" stroke="#888" \
                    stroke-width="1.5" stroke-dasharray="2,2"/>

                    """
            }
        }

        // Legends: zones by colour, kinds by marker.
        var legendY = margin + plotHeight + 34
        for (index, zone) in zones.enumerated() {
            let x = margin + Double(index) * 150
            svg += """
                <circle cx="\(x + 6)" cy="\(legendY - 4)" r="5" fill="\(palette[index % palette.count])"/>
                <text x="\(x + 18)" y="\(legendY)" font-size="12" fill="#333">\(zone)</text>

                """
        }
        legendY += 24
        let kinds = [
            ("calibration sample", "filled circle"), ("correct tap", "open circle"),
            ("misclassified tap", "cross"), ("unknown tap", "dashed circle"),
        ]
        for (index, kind) in kinds.enumerated() {
            let x = margin + Double(index) * 190
            svg += """
                <text x="\(x)" y="\(legendY)" font-size="11" fill="#555">\
                \(kind.0) — \(kind.1)</text>

                """
        }

        svg += "</svg>\n"
        return svg
    }

    private static func colour(for zone: String, zones: [String]) -> String {
        guard let index = zones.firstIndex(of: zone) else { return "#666666" }
        return palette[index % palette.count]
    }
}
