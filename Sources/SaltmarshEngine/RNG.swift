/// SplitMix64 generator. The single source of randomness for the engine: store it in
/// game state and the game replays exactly from its seed.
public struct SeededRNG: RandomNumberGenerator, Codable, Equatable, Hashable, Sendable {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public mutating func d6() -> Int {
        Int.random(in: 1...6, using: &self)
    }
}
