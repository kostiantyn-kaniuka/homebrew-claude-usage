import SwiftUI

/// The orange pixel mascot, drawn from a tiny grid so it stays crisp at any size.
struct MascotView: View {
    private static let grid = [
        "  ########  ",
        "  #.####.#  ",
        "###.####.###",
        "  ########  ",
        "  ########  ",
        "  # #  # #  ",
        "  # #  # #  ",
    ]
    static let orange = Color(red: 0.85, green: 0.47, blue: 0.34)

    var body: some View {
        let cols = Self.grid[0].count
        let rows = Self.grid.count
        Canvas { ctx, size in
            let px = min(size.width / CGFloat(cols), size.height / CGFloat(rows))
            let ox = (size.width - px * CGFloat(cols)) / 2
            let oy = (size.height - px * CGFloat(rows)) / 2
            for (y, row) in Self.grid.enumerated() {
                for (x, ch) in row.enumerated() where ch == "#" {
                    let r = CGRect(x: ox + CGFloat(x) * px, y: oy + CGFloat(y) * px, width: px + 0.3, height: px + 0.3)
                    ctx.fill(Path(r), with: .color(Self.orange))
                }
            }
        }
        .aspectRatio(CGFloat(cols) / CGFloat(rows), contentMode: .fit)
    }
}
