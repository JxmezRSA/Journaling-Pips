import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = AuthViewModel()
    @Binding var isComplete: Bool
    @State private var showAuth = false

    private let features = [
        ("Journal every trade", "Capture execution, psychology, screenshots, and lessons.", "book.pages.fill"),
        ("Learn from AI reviews", "Turn every setup into a clear coaching moment.", "sparkles"),
        ("Track your progress", "See performance, discipline, streaks, and growth.", "chart.line.uptrend.xyaxis")
    ]

    var body: some View {
        ZStack {
            JPColors.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                logo

                VStack(spacing: 12) {
                    Text("Welcome to Journaling Pips")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Your AI trading journal and performance coach.")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 34)
                }

                featureCards

                VStack(spacing: 12) {
                    Button {
                        JPHaptics.impact(.medium)
                        viewModel.isLogin = false
                        showAuth = true
                    } label: {
                        Label("Create Account", systemImage: "person.crop.circle.badge.plus")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(JPColors.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(ScalingButtonStyle())

                    Button {
                        JPHaptics.selection()
                        viewModel.isLogin = true
                        showAuth = true
                    } label: {
                        Label("Sign In", systemImage: "person.crop.circle")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(JPColors.border, lineWidth: 1))
                    }
                    .buttonStyle(ScalingButtonStyle())

                    Button {
                        JPHaptics.notify(.success)
                        viewModel.continueOffline()
                        isComplete = true
                    } label: {
                        Text("Continue Offline")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(JPColors.graphite, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(ScalingButtonStyle())
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .sheet(isPresented: $showAuth) {
            AuthSheet(viewModel: viewModel) {
                isComplete = true
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            viewModel.configure(context: modelContext)
        }
        .onChange(of: viewModel.cloudUser?.id) { _, userID in
            if userID != nil {
                isComplete = true
            }
        }
    }

    private var featureCards: some View {
        VStack(spacing: 10) {
            ForEach(features, id: \.0) { feature in
                HStack(spacing: 14) {
                    Image(systemName: feature.2)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(JPColors.background)
                        .frame(width: 44, height: 44)
                        .background(JPColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(feature.0)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)

                        Text(feature.1)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(JPColors.border, lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 24)
    }

    private var logo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(LinearGradient(colors: [JPColors.accent, JPColors.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 112, height: 112)
                .shadow(color: JPColors.accent.opacity(0.34), radius: 28, x: 0, y: 16)

            Text("JP")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(JPColors.background)
        }
    }
}

private struct AuthSheet: View {
    @ObservedObject var viewModel: AuthViewModel
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            JPColors.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(viewModel.isLogin ? "Welcome Back" : "Create Account")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(JPColors.primaryText)

                    Text(viewModel.isConfigured ? "Cloud sync is ready." : "Supabase keys are not configured, so this will create an offline profile.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(JPColors.secondaryText)

                    if !viewModel.isLogin {
                        authField("Display Name", text: $viewModel.displayName)
                    }
                    authField("Email", text: $viewModel.email)
                    authField("Password", text: $viewModel.password, isSecure: true)

                    Button {
                        viewModel.submit()
                    } label: {
                        Text(viewModel.isLoading ? "Loading..." : (viewModel.isLogin ? "Login" : "Register"))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(JPColors.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(ScalingButtonStyle())

                    Button {
                        viewModel.signInWithApple()
                    } label: {
                        Label("Sign in with Apple", systemImage: "apple.logo")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(JPColors.graphite, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(ScalingButtonStyle())

                    Button {
                        viewModel.signInWithGoogle()
                    } label: {
                        Label("Google Sign-In", systemImage: "g.circle.fill")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(JPColors.primaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(JPColors.graphite, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(ScalingButtonStyle())

                    HStack {
                        Button(viewModel.isLogin ? "Create an account" : "I already have an account") {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                viewModel.isLogin.toggle()
                            }
                        }

                        Spacer()

                        Button("Forgot Password") {
                            viewModel.resetPassword()
                        }
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(JPColors.accent)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.warning)
                    }

                    if let success = viewModel.successMessage {
                        Text(success)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(JPColors.profit)
                    }
                }
                .padding(24)
            }
        }
        .onChange(of: viewModel.cloudUser?.id) { _, userID in
            if userID != nil { onComplete() }
        }
    }

    @ViewBuilder
    private func authField(_ title: String, text: Binding<String>, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(JPColors.secondaryText)

            if isSecure {
                SecureField(title, text: text)
                    .textContentType(.password)
                    .fieldStyle()
            } else {
                TextField(title, text: text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .fieldStyle()
            }
        }
    }
}

private extension View {
    func fieldStyle() -> some View {
        self
            .foregroundStyle(JPColors.primaryText)
            .tint(JPColors.accent)
            .padding(.horizontal, 14)
            .frame(height: 54)
            .background(JPColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(JPColors.border, lineWidth: 1)
            )
    }
}
