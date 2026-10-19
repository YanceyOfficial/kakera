import CoreGraphics

/// Which way Kakera's screens may turn. Cards and short lists read best upright on a phone, so a phone-sized screen
/// stays in portrait; a tablet-sized one — an iPhone Duo unfolded — turns too, and the review screen moves its
/// buttons beside the card (`ReviewSessionView`). Decided per screen, at run time: Info.plist alone can't tell a
/// folded Duo from an unfolded one, and the unfolded screen ignored a portrait-only plist anyway.
public enum KakeraOrientation {
    /// The shorter side, in points, from which a screen may turn (phones top out near 440; the unfolded Duo is 669).
    public static let landscapeMinimumShortSide: CGFloat = 600

    public static func allowsLandscape(screen: CGSize) -> Bool {
        min(screen.width, screen.height) >= landscapeMinimumShortSide
    }
}
