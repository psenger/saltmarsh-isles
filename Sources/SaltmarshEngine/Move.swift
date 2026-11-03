public enum Move: Codable, Hashable, Sendable {
    case rollForFirst
    case placeSettlement(corner: Int)
    case placeRoad(edge: Int)
    case upgradeCity(corner: Int)
    case roll
    case discard(ResourceCounts)
    case moveRobber(tile: Int)
    case steal(from: Int)
    case bankTrade(give: Resource, get: Resource)
    case harbourTrade(harbour: Int, give: Resource, get: Resource)
    case proposeTrade(TradeOffer)
    case respondToTrade(seat: Int, TradeResponse)
    case executeTrade(with: Int)
    case withdrawTrade
    case buyDevCard
    case playKnight
    case playRoadCrew
    case playBumperHarvest(Resource, Resource)
    case playCornerMarket(Resource)
    case endTurn
}
