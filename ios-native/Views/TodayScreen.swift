import SwiftUI

public struct TodayScreen: View {
    @ObservedObject private var store: TodayFlowStore

    @State private var answerDraft = ""
    @State private var hasBootstrapped = false

    public init(store: TodayFlowStore) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    statusSection
                    questionSection
                    answerSection
                    if let errorMessage = store.errorMessage {
                        errorSection(message: errorMessage)
                    }
                }
                .padding(20)
            }
            .background(backgroundGradient)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await store.refresh()
            }
            .task {
                guard !hasBootstrapped else {
                    return
                }

                hasBootstrapped = true
                await store.bootstrap()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today’s Call")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(headerSubtitle)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)

                Text(statusTitle)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }

            if store.missedYesterday {
                Text("You missed yesterday’s call. Today resets the flow.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.orange.opacity(0.95))
            }

            if store.isBootstrapping || store.isRefreshing {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)

                    Text(store.isBootstrapping ? "Loading today’s call…" : "Refreshing…")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.82))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today’s Question")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))
                .textCase(.uppercase)

            Text(store.resolvedQuestionText.isEmpty ? "No question available yet." : store.resolvedQuestionText)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            if store.isFallbackQuestion && !store.resolvedQuestionText.isEmpty {
                Text("Showing fallback question text.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.62))
            }

            if let pair = store.currentPair {
                Divider()
                    .overlay(Color.white.opacity(0.12))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Matched With")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.68))
                        .textCase(.uppercase)

                    Text(pair.hiddenName)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    if !pair.circleName.isEmpty {
                        Text(pair.circleName)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.74))
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var answerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Answers")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 8) {
                Text("Their Answer")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.66))

                Text(store.incomingAnswerText.isEmpty ? "No answer yet." : store.incomingAnswerText)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
            }

            Divider()
                .overlay(Color.white.opacity(0.12))

            VStack(alignment: .leading, spacing: 12) {
                Text("Your Answer")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.66))

                TextField(
                    "Type your answer…",
                    text: $answerDraft,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .foregroundStyle(.white)
                .disabled(!store.canSubmitAnswer || store.isSubmitting)

                if store.hasSubmittedAnswer {
                    Text(store.submittedAnswerText.isEmpty ? "Answer sent." : "Sent: \(store.submittedAnswerText)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.green.opacity(0.95))
                }

                Button {
                    Task {
                        await store.submitAnswer(answerDraft)
                        if store.errorMessage == nil {
                            answerDraft = ""
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        if store.isSubmitting {
                            ProgressView()
                                .tint(.black)
                        }
                        Text(store.isSubmitting ? "Sending…" : "Send Answer")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .disabled(!canSendCurrentDraft)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private func errorSection(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white)

            Button("Dismiss") {
                store.clearError()
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .foregroundStyle(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.red.opacity(0.24))
        )
    }

    private var canSendCurrentDraft: Bool {
        store.canSubmitAnswer
            && !store.isSubmitting
            && !answerDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var headerSubtitle: String {
        if let pair = store.currentPair, !pair.hiddenName.isEmpty {
            return "Your daily conversation is with \(pair.hiddenName)."
        }

        switch store.availability {
        case .setupRequired:
            return "Finish setup to unlock your daily call flow."
        case .unmatched:
            return "Add more people to improve your daily pool."
        case .ready:
            return "Your daily conversation is ready."
        case .completed:
            return "Today’s conversation is complete."
        }
    }

    private var statusTitle: String {
        switch store.availability {
        case .setupRequired:
            return "Setup required"
        case .unmatched:
            return "Add more friends"
        case .ready:
            return "Ready to connect"
        case .completed:
            return "Call completed"
        }
    }

    private var statusColor: Color {
        switch store.availability {
        case .setupRequired:
            return .yellow
        case .unmatched:
            return .orange
        case .ready:
            return .green
        case .completed:
            return .white
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.09, green: 0.07, blue: 0.15),
                Color(red: 0.11, green: 0.18, blue: 0.25),
                Color.black,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}