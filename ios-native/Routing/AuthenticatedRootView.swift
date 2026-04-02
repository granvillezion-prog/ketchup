import FirebaseAuth
import FirebaseFirestore
import SwiftUI

public struct AuthenticatedRootView: View {
	private let auth: Auth
	private let firestore: Firestore

	public init(
		auth: Auth = Auth.auth(),
		firestore: Firestore = Firestore.firestore()
	) {
		self.auth = auth
		self.firestore = firestore
	}

	public var body: some View {
		Group {
			if let uid = auth.currentUser?.uid {
				AuthenticatedTodayContainer(
					uid: uid,
					auth: auth,
					firestore: firestore
				)
			} else {
				SignedOutBlockingView()
			}
		}
	}
}

private struct AuthenticatedTodayContainer: View {
	@StateObject private var todayFlowStore: TodayFlowStore

	init(uid: String, auth: Auth, firestore: Firestore) {
		let storage = AppStorageDailyPairAdapter()
		let firestoreService = FirestoreService(uid: uid, firestore: firestore)
		let progressService = ProgressService(firestore: firestore, auth: auth)
		let dailyPairService = DailyPairService(
			firestore: firestore,
			auth: auth,
			firestoreService: firestoreService,
			progressService: progressService,
			storage: storage
		)

		_todayFlowStore = StateObject(
			wrappedValue: TodayFlowStore(dailyPairService: dailyPairService)
		)
	}

	var body: some View {
		TodayScreen(store: todayFlowStore)
	}
}

private struct SignedOutBlockingView: View {
	var body: some View {
		ZStack {
			LinearGradient(
				colors: [
					Color(red: 0.09, green: 0.07, blue: 0.15),
					Color.black,
				],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			)
			.ignoresSafeArea()

			VStack(spacing: 14) {
				Text("Sign In Required")
					.font(.system(size: 28, weight: .bold, design: .rounded))
					.foregroundStyle(.white)

				Text("The native Today flow is only available for an authenticated user.")
					.font(.system(size: 15, weight: .medium, design: .rounded))
					.foregroundStyle(Color.white.opacity(0.76))
					.multilineTextAlignment(.center)
					.frame(maxWidth: 320)
			}
			.padding(24)
		}
	}
}
