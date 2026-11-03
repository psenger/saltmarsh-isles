public enum Seat: Int, CaseIterable, Codable, Hashable, Sendable {
    case crimson, cobalt, amber, ivory

    public var name: String {
        switch self {
        case .crimson: "Crimson"
        case .cobalt: "Cobalt"
        case .amber: "Amber"
        case .ivory: "Ivory"
        }
    }

    public var colorHex: String {
        switch self {
        case .crimson: "#c0392b"
        case .cobalt: "#2a5db0"
        case .amber: "#d68910"
        case .ivory: "#ece6d6"
        }
    }
}

public enum EffortLevel: Int, CaseIterable, Codable, Hashable, Sendable {
    case deckhand = 1, sailor, mate, captain, admiral

    public var name: String {
        switch self {
        case .deckhand: "Deckhand"
        case .sailor: "Sailor"
        case .mate: "Mate"
        case .captain: "Captain"
        case .admiral: "Admiral"
        }
    }
}

public enum Controller: Codable, Hashable, Sendable {
    case human, ai(EffortLevel)

    public var isAI: Bool {
        if case .ai = self { return true }
        return false
    }
}
