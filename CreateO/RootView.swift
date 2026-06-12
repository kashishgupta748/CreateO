//
//  RootView.swift
//  creato
//
//  Created by GU on 25/04/26.
//

import SwiftUI

/// Decides what to show based on auth state.
/// - `.loading`: session restore in progress -> spinner
/// - first launch / `.loading` after no session: LoginView (with Skip)
/// - `.guest` (has seen auth screen): ContentView with dummy data
/// - `.authenticated`: ContentView with cloud-synced data
struct RootView: View {

    @Environment(AuthManager.self) private var authManager
    @AppStorage("profile.theme") private var themeRawValue = CreatoTheme.system.rawValue

    private var selectedTheme: CreatoTheme {
        CreatoTheme.from(themeRawValue)
    }

    var body: some View {
        Group {
            switch authManager.state {
            case .loading:
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    ProgressView()
                }

            case .guest where !authManager.hasSeenAuthScreen:
                LoginView()

            case .guest:
                ContentView()

            case .pendingEmailConfirmation:
                ContentView()

            case .authenticated:
                ContentView()
            }
        }
        .preferredColorScheme(selectedTheme.colorScheme)
        .animation(.easeInOut(duration: 0.25), value: authManager.state)
    }
}

#Preview {
    RootView()
        .environment(AuthManager())
        .environment(DataStore())
}
