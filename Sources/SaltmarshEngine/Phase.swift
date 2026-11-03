public indirect enum Phase: Codable, Hashable, Sendable {
    case rollingForFirst(rolls: [Int?], contenders: [Int])
    case setup(step: Int, placingRoad: Bool, lastSettlement: Int?)
    case awaitingRoll
    case discarding(queue: [Int])
    case movingRobber(returnTo: Phase)
    case choosingVictim(candidates: [Int], returnTo: Phase)
    case placingFreeRoads(remaining: Int)
    case main
    case tradeOffered(offer: TradeOffer, responses: [Int: TradeResponse])
    case gameOver(winner: Int)
}
