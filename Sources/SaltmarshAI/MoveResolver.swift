import SaltmarshEngine

/// Safety net between an opponent and the engine: an illegal choice is replaced by the fallback's
/// choice when that is legal, else by the first listed legal move. A game with an always-wrong opponent still finishes.
///
/// `isLegal` is the engine's own check. `legal` is only the enumerated sample, which leaves out
/// valid offers, counters and discards, so a move is never rejected for being absent from it.
public enum MoveResolver {
    public static func resolve(_ proposed: Move, isLegal: (Move) -> Bool, legal: [Move], fallback: () -> Move? = { nil }) -> Move {
        precondition(!legal.isEmpty, "no legal moves to resolve against")
        if isLegal(proposed) { return proposed }
        if let alternative = fallback(), isLegal(alternative) { return alternative }
        return legal[0]
    }
}
