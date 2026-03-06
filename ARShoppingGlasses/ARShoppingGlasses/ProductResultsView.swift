import SwiftUI

// MARK: - Product Results View

struct ProductResultsView: View {
    let results: SearchResults
    let onDismiss: () -> Void
    
    @State private var selectedTab: ResultsTab = .all
    @State private var appeared = false
    
    enum ResultsTab: String, CaseIterable {
        case all = "All"
        case ebay = "eBay"
        case amazon = "Amazon"
    }
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: 0) {
                // Header
                resultsHeader
                
                // Tab bar
                tabBar
                
                // Results scroll
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredItems) { item in
                            ProductCardView(item: item)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .padding(.horizontal, 12)
            .padding(.top, 60)
            .padding(.bottom, 20)
            .scaleEffect(appeared ? 1.0 : 0.92)
            .opacity(appeared ? 1.0 : 0.0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    appeared = true
                }
            }
        }
    }
    
    // MARK: - Filtered Items
    
    private var filteredItems: [ProductItem] {
        let ebay = (results.ebay ?? []).map { item -> ProductItem in
            var copy = item
            copy.source = "eBay"
            return copy
        }
        let amazon = (results.amazon ?? []).map { item -> ProductItem in
            var copy = item
            copy.source = "Amazon"
            return copy
        }
        
        switch selectedTab {
        case .all: return ebay + amazon
        case .ebay: return ebay
        case .amazon: return amazon
        }
    }
    
    // MARK: - Header
    
    private var resultsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Shopping Results")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("\(filteredItems.count) items found")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.5))
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(ResultsTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedTab == tab
                                ? AnyShapeStyle(.ultraThinMaterial)
                                : AnyShapeStyle(.clear)
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Product Card View

struct ProductCardView: View {
    let item: ProductItem
    @State private var imageData: Data?
    
    var body: some View {
        HStack(spacing: 14) {
            // Product image
            productImage
            
            // Product info
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title ?? "Unknown Product")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                if let price = item.price {
                    Text(price)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.cyan)
                }
                
                HStack(spacing: 8) {
                    // Source badge
                    Text(item.source ?? "")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(sourceBadgeColor)
                        .clipShape(Capsule())
                    
                    if let condition = item.condition, !condition.isEmpty {
                        Text(condition)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                
                // Link button
                if let urlString = item.itemWebUrl, let url = URL(string: urlString) {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption2)
                            Text("View")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.cyan)
                    }
                }
            }
            
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Product Image
    
    private var productImage: some View {
        Group {
            if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Image(systemName: "bag")
                            .foregroundStyle(.white.opacity(0.3))
                    }
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            await loadImage()
        }
    }
    
    private var sourceBadgeColor: Color {
        switch item.source?.lowercased() {
        case "ebay": return .blue.opacity(0.6)
        case "amazon": return .orange.opacity(0.6)
        default: return .gray.opacity(0.6)
        }
    }
    
    // MARK: - Image Loading
    
    private func loadImage() async {
        guard let urlString = item.imageUrl,
              let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await MainActor.run {
                self.imageData = data
            }
        } catch {
            print(">>> Failed to load image: \(error.localizedDescription)")
        }
    }
}

