import SwiftUI

/// Two lazy columns; each item goes to the shorter one, so appending a page never moves a tile on screen.
struct MasonryGridView<Item: Identifiable, Cell: View>: View {
    private enum Constants {
        static var gutter: CGFloat { 8 }
        /// Guards against a zero or absurd ratio producing an endless cell.
        static var minimumAspectRatio: Double { 0.1 }
    }

    let items: [Item]
    let aspectRatio: KeyPath<Item, Double>
    let onItemAppear: (Item) -> Void
    let cell: (Item, CGFloat) -> Cell

    @State private var width: CGFloat = 0

    init(items: [Item],
         aspectRatio: KeyPath<Item, Double>,
         onItemAppear: @escaping (Item) -> Void = { _ in },
         @ViewBuilder cell: @escaping (_ item: Item, _ columnWidth: CGFloat) -> Cell) {
        self.items = items
        self.aspectRatio = aspectRatio
        self.onItemAppear = onItemAppear
        self.cell = cell
    }

    var body: some View {
        Group {
            // Until the width is known every cell would be zero high and the lazy stacks would build them all.
            if width > 0 {
                let columns = Self.columns(for: items, aspectRatio: aspectRatio)
                let columnWidth = (width - Spacing.screenMargin * 2 - Constants.gutter) / 2
                HStack(alignment: .top, spacing: Constants.gutter) {
                    column(columns.leading, width: columnWidth)
                    column(columns.trailing, width: columnWidth)
                }
                .padding(.horizontal, Spacing.screenMargin)
            } else {
                Color.clear.frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            // Read directly rather than through a preference, which iOS 16 never delivered here.
            GeometryReader { proxy in
                Color.clear
                    .onAppear { width = proxy.size.width }
                    .onChange(of: proxy.size.width) { width = $0 }
            }
        }
    }

    private static func columns(for items: [Item],
                                aspectRatio: KeyPath<Item, Double>) -> (leading: [Item], trailing: [Item]) {
        var leading: [Item] = []
        var trailing: [Item] = []
        var leadingHeight = 0.0
        var trailingHeight = 0.0
        for item in items {
            let height = 1 / max(item[keyPath: aspectRatio], Constants.minimumAspectRatio)
            if leadingHeight <= trailingHeight {
                leading.append(item)
                leadingHeight += height
            } else {
                trailing.append(item)
                trailingHeight += height
            }
        }
        return (leading, trailing)
    }

    private func column(_ items: [Item], width: CGFloat) -> some View {
        LazyVStack(spacing: Constants.gutter) {
            ForEach(items) { item in
                cell(item, width)
                    .onAppear { onItemAppear(item) }
            }
        }
        .frame(width: width)
    }
}
