// RootGate.swift
import SwiftUI

struct RootGate: View {
    @EnvironmentObject var auth: AuthVM
    @State private var showLogin = false   // toggle when you want to force login sheet

    var body: some View {
        RootView()
            .sheet(isPresented: $showLogin) {
                LoginSheet()
                    .environmentObject(auth)
                    .applySheetStyle()
            }
    }
}

// MARK: - Sheet styling helpers
private extension View {
    func applySheetStyle() -> some View {
        if #available(iOS 16.0, *) {
            return AnyView(
                self
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            )
        } else {
            return AnyView(self)
        }
    }
}
