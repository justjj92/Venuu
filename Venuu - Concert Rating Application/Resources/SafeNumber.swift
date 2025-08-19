import SwiftUI

extension CGFloat {
    var safeNonNegative: CGFloat {
        guard !self.isNaN, self.isFinite, self >= 0 else { return 0 }
        return self
    }
}
extension Double {
    var safeNonNegative: Double {
        guard !self.isNaN, self.isFinite, self >= 0 else { return 0 }
        return self
    }
}

extension View {
    /// Use instead of `.frame(width:height:)` when width/height are computed.
    func safeFrame(width: CGFloat?, height: CGFloat?, default defaultSize: CGFloat = 1) -> some View {
        let w = (width ?? defaultSize).safeNonNegative
        let h = (height ?? defaultSize).safeNonNegative
        return frame(width: w, height: h)
    }
    func safeBlur(radius: CGFloat) -> some View { blur(radius: radius.safeNonNegative) }
    func safeCornerRadius(_ r: CGFloat) -> some View { cornerRadius(r.safeNonNegative) }
    func safeScale(_ s: CGFloat) -> some View { scaleEffect(s.isNaN || !s.isFinite ? 1 : s) }
}

/// Safe division: returns 0 if denominator is 0/NaN/inf
@inlinable func safeDivide(_ numerator: Double, _ denominator: Double) -> Double {
    guard denominator != 0, denominator.isFinite, !denominator.isNaN else { return 0 }
    let v = numerator / denominator
    return v.isNaN || !v.isFinite ? 0 : v
}
