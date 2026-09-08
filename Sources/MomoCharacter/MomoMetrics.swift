import CoreGraphics

/// Layout metric tokens — the spacing scale and corner radii every view uses
/// (project.md §18: generous whitespace, rounded components; "avoid visual
/// clutter" — five steps are enough). No other numeric paddings/gaps/radii in
/// product views.
public enum MomoSpacing {

    /// Hairline breathing room (between a card's edge and its hairline border).
    public static let extraSmall: CGFloat = 4

    /// Tight grouping inside one component.
    public static let small: CGFloat = 8

    /// Default component padding / related-element gap.
    public static let medium: CGFloat = 16

    /// Section separation.
    public static let large: CGFloat = 24

    /// Screen-edge and hero-surface breathing room (generous whitespace).
    public static let extraLarge: CGFloat = 32
}

/// Corner radii (project.md §18: rounded components). Pills/capsules use
/// `Capsule`, not a radius token.
public enum MomoRadius {

    /// Small controls, chips.
    public static let small: CGFloat = 8

    /// Cards, watch-surface containers.
    public static let medium: CGFloat = 16

    /// Hero surfaces — the pet canvas.
    public static let large: CGFloat = 24
}
