//
//  CreateOApp.swift
//  CreateO
//
//  Created by GU on 12/06/26.
//

import SwiftUI

@main
struct CreateOApp: App {
    @State private var authManager = AuthManager()
    @State private var dataStore = DataStore()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
                .environment(dataStore)
                .task {
                    authManager.startAuthStateListener()
                    await authManager.restoreSession()
                    await dataStore.bootstrap(authManager: authManager)
                }
                .onChange(of: authManager.state) { _, _ in
                    Task {
                        await dataStore.bootstrap(authManager: authManager)
                    }
                }
        }
    }
}
