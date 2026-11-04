import SaltmarshEngine

/// Safety net between an opponent and the engine: an illegal choice is replaced by the fallback's
/// choice when that is legal, else by the first legal move. A game with an always-wrong opponent still finishes.
public enum MoveResolver {
    public static func resolve(_ proposed: Move, legal: [Move], fallback: () -> Move? = { nil }) -> Move {
        precondition(!legal.isEmpty, "no legal moves to resolve against")
        if legal.contains(proposed) { return proposed }
        if let alternative = fallback(), legal.contains(alternative) { return alternative }
        return legal[0]
    }
}
