import SwiftUI

struct SplashView: View {
    @ObservedObject private var colorTheme = FeedbacksColorTheme.shared

    var body: some View {
        let _ = colorTheme.refreshToken

        ZStack {
            RadialGradient(
                colors: [
                    FeedbacksTheme.accent.opacity(0.18),
                    FeedbacksTheme.backgroundTop.opacity(0.02),
                    .clear
                ],
                center: .center,
                startRadius: 10,
                endRadius: 200
            )

            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 250, height: 250)
                .shadow(color: FeedbacksTheme.accent.opacity(0.35), radius: 30, x: 0, y: 16)
        }
        .frame(width: 360, height: 360)
        .background(Color.clear)
    }
}
