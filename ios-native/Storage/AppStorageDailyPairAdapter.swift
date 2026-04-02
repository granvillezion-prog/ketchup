import Foundation

public final class AppStorageDailyPairAdapter: DailyPairStorage {
	private enum Keys {
		static let storedTodayKey = "dailyPair.storedTodayKey"
		static let todayPairData = "dailyPair.todayPair.json"
		static let callStartedAtMs = "dailyPair.callStartedAtMs"
		static let callTotalSeconds = "dailyPair.callTotalSeconds"
		static let hasExtendedOnce = "dailyPair.hasExtendedOnce"
		static let profileUsername = "dailyPair.profileUsername"
	}

	private let defaults: UserDefaults
	private let encoder: JSONEncoder
	private let decoder: JSONDecoder

	public init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
		self.encoder = JSONEncoder()
		self.decoder = JSONDecoder()
	}

	public func getStoredTodayKey() -> String? {
		defaults.string(forKey: Keys.storedTodayKey)
	}

	public func setStoredTodayKey(_ key: String) async throws {
		defaults.set(key, forKey: Keys.storedTodayKey)
	}

	public func getTodayPair() -> MockPair? {
		guard let data = defaults.data(forKey: Keys.todayPairData) else {
			return nil
		}

		return try? decoder.decode(MockPair.self, from: data)
	}

	public func setTodayPair(_ pair: MockPair) async throws {
		let data = try encoder.encode(pair)
		defaults.set(data, forKey: Keys.todayPairData)
	}

	public func clearTodayPair() async throws {
		defaults.removeObject(forKey: Keys.todayPairData)
	}

	public func getCallStartedAt() -> Int? {
		integerIfPresent(forKey: Keys.callStartedAtMs)
	}

	public func setCallStartedAt(_ ms: Int) async throws {
		defaults.set(ms, forKey: Keys.callStartedAtMs)
	}

	public func getCallTotalSeconds() -> Int? {
		integerIfPresent(forKey: Keys.callTotalSeconds)
	}

	public func setCallTotalSeconds(_ seconds: Int) async throws {
		defaults.set(seconds, forKey: Keys.callTotalSeconds)
	}

	public func getHasExtendedOnce() -> Bool {
		defaults.bool(forKey: Keys.hasExtendedOnce)
	}

	public func setHasExtendedOnce(_ value: Bool) async throws {
		defaults.set(value, forKey: Keys.hasExtendedOnce)
	}

	public func clearCallTimer() async throws {
		defaults.removeObject(forKey: Keys.callStartedAtMs)
		defaults.removeObject(forKey: Keys.callTotalSeconds)
	}

	public func clearDailyCallState() async throws {
		defaults.removeObject(forKey: Keys.hasExtendedOnce)
	}

	public func getProfileUsername() -> String {
		// Temporary bridge for first-pass wiring until a dedicated native
		// profile/session storage source is introduced.
		defaults.string(forKey: Keys.profileUsername) ?? ""
	}

	private func integerIfPresent(forKey key: String) -> Int? {
		guard defaults.object(forKey: key) != nil else {
			return nil
		}

		return defaults.integer(forKey: key)
	}
}
