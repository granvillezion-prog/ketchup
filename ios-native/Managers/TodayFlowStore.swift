import Combine
import Foundation

@MainActor
public final class TodayFlowStore: ObservableObject {
	@Published public private(set) var currentPair: MockPair?
	@Published public private(set) var availability: DailyPairAvailability

	@Published public private(set) var effectiveDateKey: String
	@Published public private(set) var resolvedQuestionId: String
	@Published public private(set) var resolvedQuestionText: String
	@Published public private(set) var isFallbackQuestion: Bool

	@Published public private(set) var incomingAnswerText: String
	@Published public private(set) var submittedAnswerText: String
	@Published public private(set) var hasSubmittedAnswer: Bool
	@Published public private(set) var canSubmitAnswer: Bool

	@Published public private(set) var missedYesterday: Bool

	@Published public private(set) var isBootstrapping: Bool
	@Published public private(set) var isRefreshing: Bool
	@Published public private(set) var isSubmitting: Bool
	@Published public private(set) var isPolling: Bool

	@Published public private(set) var errorMessage: String?

	private let dailyPairService: DailyPairService

	public init(dailyPairService: DailyPairService) {
		self.dailyPairService = dailyPairService
		self.currentPair = nil
		self.availability = .setupRequired
		self.effectiveDateKey = ""
		self.resolvedQuestionId = ""
		self.resolvedQuestionText = ""
		self.isFallbackQuestion = true
		self.incomingAnswerText = ""
		self.submittedAnswerText = ""
		self.hasSubmittedAnswer = false
		self.canSubmitAnswer = false
		self.missedYesterday = false
		self.isBootstrapping = false
		self.isRefreshing = false
		self.isSubmitting = false
		self.isPolling = false
		self.errorMessage = nil
	}

	public func bootstrap() async {
		guard !isBootstrapping else {
			return
		}

		isBootstrapping = true
		clearError()

		do {
			let snapshot = try await dailyPairService.loadTodayPair()
			applySnapshot(snapshot)
		} catch {
			errorMessage = userFacingMessage(for: error)
		}

		isBootstrapping = false
	}

	public func refresh() async {
		guard !isRefreshing else {
			return
		}

		isRefreshing = true
		clearError()

		do {
			let snapshot = try await dailyPairService.refresh()
			applySnapshot(snapshot)
		} catch {
			errorMessage = userFacingMessage(for: error)
		}

		isRefreshing = false
	}

	public func submitAnswer(_ rawText: String) async {
		guard !isSubmitting else {
			return
		}

		isSubmitting = true
		clearError()

		do {
			let result = try await dailyPairService.submitAnswer(rawText)
			applySnapshot(result.snapshot)
		} catch {
			errorMessage = userFacingMessage(for: error)
		}

		isSubmitting = false
	}

	public func pollIncomingAnswer() async {
		guard !isPolling else {
			return
		}

		isPolling = true

		do {
			let result = try await dailyPairService.handlePolling()
			applySnapshot(result.snapshot)
		} catch {
			errorMessage = userFacingMessage(for: error)
		}

		isPolling = false
	}

	public func applySnapshot(_ snapshot: DailyPairSnapshot) {
		currentPair = snapshot.pair
		availability = snapshot.availability
		effectiveDateKey = snapshot.effectiveDateKey

		resolvedQuestionId = snapshot.resolvedQuestion.questionId
		resolvedQuestionText = snapshot.resolvedQuestion.questionText
		isFallbackQuestion = snapshot.resolvedQuestion.isFallback

		incomingAnswerText = snapshot.answerState.incomingAnswerText
		submittedAnswerText = snapshot.answerState.myAnswerText
		hasSubmittedAnswer = snapshot.answerState.hasSubmittedAnswer
		canSubmitAnswer = snapshot.answerState.canSubmitAnswer
			&& snapshot.availability == .ready
			&& !(snapshot.pair?.callCompleted ?? false)

		missedYesterday = snapshot.missedYesterday
	}

	public func clearError() {
		errorMessage = nil
	}

	private func userFacingMessage(for error: Error) -> String {
		if let localizedError = error as? LocalizedError,
		   let description = localizedError.errorDescription,
		   !description.isEmpty {
			return description
		}

		return "Something went wrong. Please try again."
	}
}
