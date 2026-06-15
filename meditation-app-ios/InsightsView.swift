import SwiftUI

struct InsightsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = InsightStore.shared

    var body: some View {
        Group {
            if store.isLoading && store.current == nil {
                // Fetching with nothing cached yet — show spinner
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(AppTheme.bodyMuted)
                    Text("Loading insight\u{2026}")
                        .font(.body)
                        .foregroundStyle(AppTheme.bodyMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let insight = store.current {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(insight.title)
                            .font(.title.weight(.semibold))
                            .foregroundStyle(AppTheme.heroTitle)

                        Text(insight.insight)
                            .font(.title3)
                            .foregroundStyle(AppTheme.rowValue)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .padding(.top, 60)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                // No cache and fetch failed (or not yet started)
                VStack(spacing: 16) {
                    Image(systemName: "lightbulb.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.bodyMuted)
                    Text(store.fetchError ?? "No insight available.")
                        .font(.body)
                        .foregroundStyle(AppTheme.bodyMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appThemedScreen()
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.bodyMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 24)
            .padding(.trailing, 24)
        }
        // Fallback: start loading if not already underway (e.g. deep-linked directly to this sheet)
        .task {
            await store.loadInsight()
        }
    }
}

#Preview {
    InsightsView()
}
