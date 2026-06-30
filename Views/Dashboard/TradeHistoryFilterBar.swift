import SwiftUI

struct TradeHistoryFilterBar: View {
    @ObservedObject var viewModel: TradeHistoryViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(JPColors.secondaryText)

                    TextField("Search trades, notes, mistakes...", text: $viewModel.searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JPColors.primaryText)

                    if !viewModel.searchText.isEmpty {
                        Button {
                            JPHaptics.selection()
                            viewModel.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(JPColors.secondaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(JPColors.border, lineWidth: 1))

                Menu {
                    Picker("Sort", selection: $viewModel.sort) {
                        ForEach(TradeHistorySort.allCases) { sort in
                            Text(sort.rawValue).tag(sort)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(JPColors.border, lineWidth: 1))
                }
                .buttonStyle(ScalingButtonStyle())
                .accessibilityLabel("Sort trade history")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(TradeHistoryFilter.allCases) { filter in
                        Button {
                            JPHaptics.selection()
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                viewModel.toggleFilter(filter)
                            }
                        } label: {
                            filterChip(filter)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func filterChip(_ filter: TradeHistoryFilter) -> some View {
        let isSelected = viewModel.selectedFilters.contains(filter)
        return HStack(spacing: 7) {
            Image(systemName: filter.icon)
            Text(filter.rawValue)
        }
        .font(.caption.weight(.black))
        .foregroundStyle(isSelected ? JPColors.background : JPColors.secondaryText)
        .padding(.horizontal, 13)
        .frame(height: 38)
        .background(isSelected ? JPColors.accent : JPColors.graphite, in: Capsule())
        .overlay(Capsule().stroke(isSelected ? JPColors.accent.opacity(0.4) : JPColors.border, lineWidth: 1))
        .scaleEffect(isSelected ? 1.04 : 1)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isSelected)
        .accessibilityLabel(filter.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
