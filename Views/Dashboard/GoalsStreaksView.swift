import SwiftData
import SwiftUI

struct GoalsStreaksView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = DisciplineViewModel()
    @State private var didAppear = false

    private let achievementColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack {
            JPColors.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    hero
                    ringsSection
                    streaksSection
                    xpSection
                    achievementsSection
                    historySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 96)
            }
        }
        .navigationTitle("Goals & Streaks")
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            viewModel.configure(context: modelContext)
            withAnimation(.easeOut(duration: 0.45)) {
                didAppear = true
            }
        }
    }

    private var hero: some View {
        GlassCard {
            HStack(spacing: 22) {
                ZStack {
                    Circle()
                        .stroke(JPColors.graphite, lineWidth: 16)

                    Circle()
                        .trim(from: 0, to: Double(viewModel.score) / 100.0)
                        .stroke(
                            AngularGradient(
                                colors: [JPColors.accent, JPColors.blue, JPColors.warning, JPColors.accent],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .shadow(color: JPColors.accent.opacity(0.35), radius: 18, x: 0, y: 8)
                        .animation(.spring(response: 0.7, dampingFraction: 0.86), value: viewModel.score)

                    VStack(spacing: 2) {
                        Text("\(viewModel.score)")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(JPColors.primaryText)

                        Text("/ 100")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(JPColors.secondaryText)
                    }
                }
                .frame(width: 132, height: 132)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Discipline Score")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)

                    Text(viewModel.scoreRating)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(JPColors.accent)

                    Text("Built from planning, risk control, journaling, review quality, and major mistake avoidance.")
                        .font(.subheadline)
                        .foregroundStyle(JPColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 16)
    }

    private var ringsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Discipline Rings", subtitle: "Consistency over profit")

            GlassCard {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(viewModel.ringItems) { item in
                        RingProgressView(item: item, size: 94, lineWidth: 11)
                    }
                }
            }
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 18)
        .animation(.spring(response: 0.44, dampingFraction: 0.86).delay(0.04), value: didAppear)
    }

    private var streaksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Streaks", subtitle: "Show up clean, then repeat")

            LazyVGrid(columns: achievementColumns, spacing: 14) {
                streakCard(title: "Discipline", value: "\(viewModel.currentDisciplineStreak)", subtitle: "Current streak", icon: "flame.fill", tint: JPColors.accent)
                streakCard(title: "Longest", value: "\(viewModel.longestDisciplineStreak)", subtitle: "Best discipline run", icon: "crown.fill", tint: JPColors.warning)
                streakCard(title: "Green Days", value: "\(viewModel.greenDayStreak)", subtitle: "Profit streak", icon: "arrow.up.circle.fill", tint: JPColors.profit)
                streakCard(title: "Journal", value: "\(viewModel.journalStreak)", subtitle: "Review streak", icon: "book.pages.fill", tint: JPColors.blue)
                streakCard(title: "Plan", value: "\(viewModel.planStreak)", subtitle: "Preparation streak", icon: "checklist.checked", tint: JPColors.warning)
            }
        }
    }

    private func streakCard(title: String, value: String, subtitle: String, icon: String, tint: Color) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)

                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(JPColors.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 146, alignment: .leading)
        }
    }

    private var xpSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("XP Level")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)

                        Text("Level \(viewModel.level)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(JPColors.warning)
                    }

                    Spacer()

                    Text("\(viewModel.totalXP) XP")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(JPColors.warning.opacity(0.14), in: Capsule())
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(JPColors.graphite)
                            .frame(height: 12)

                        Capsule()
                            .fill(LinearGradient(colors: [JPColors.warning, JPColors.accent], startPoint: .leading, endPoint: .trailing))
                            .frame(width: proxy.size.width * viewModel.progressToNextLevel, height: 12)
                            .animation(.spring(response: 0.5, dampingFraction: 0.86), value: viewModel.progressToNextLevel)
                    }
                }
                .frame(height: 12)

                Text("Earn XP by completing the morning plan, logging trades, finishing reviews, following the plan, and building perfect discipline days.")
                    .font(.subheadline)
                    .foregroundStyle(JPColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Achievements", subtitle: "\(viewModel.unlockedCount) unlocked")

            LazyVGrid(columns: achievementColumns, spacing: 14) {
                ForEach(Array(viewModel.achievements.enumerated()), id: \.element.id) { index, achievement in
                    AchievementBadgeView(achievement: achievement)
                        .premiumEntrance(active: didAppear, delay: 0.02 * Double(index))
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Recent Discipline", subtitle: "Daily behavior history")

            if viewModel.history.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(JPColors.accent)
                            .frame(width: 58, height: 58)
                            .background(JPColors.accentSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                        Text("Your discipline history starts today.")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)

                        Text("Complete the plan, respect risk, and review trades to build your streak.")
                            .font(.subheadline)
                            .foregroundStyle(JPColors.secondaryText)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.history) { item in
                        historyRow(item)
                    }
                }
            }
        }
    }

    private func historyRow(_ item: DisciplineHistoryItem) -> some View {
        GlassCard {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.primaryText)

                    Text("Plan \(percent(item.planProgress)) • Risk \(percent(item.riskProgress)) • Journal \(percent(item.journalProgress))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(JPColors.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(item.score)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(item.score >= 80 ? JPColors.accent : JPColors.warning)

                    Text("+\(item.xp) XP")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(JPColors.warning)
                }
            }
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
