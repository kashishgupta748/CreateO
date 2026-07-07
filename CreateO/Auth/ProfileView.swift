//
//  ProfileView.swift
//  creato
//
//  Created by GU on 24/04/26.
//

import SwiftUI
import PhotosUI
//import UIKit

struct ProfileView: View {

    @Environment(AuthManager.self) private var authManager
    @Environment(DataStore.self) private var designStore
    @Environment(\.openURL) private var openURL

    @AppStorage("profile.theme") private var themeRawValue = CreatoTheme.system.rawValue
    @AppStorage("profile.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("profile.productUpdatesEnabled") private var productUpdatesEnabled = false
    @AppStorage("profile.biometricLockEnabled") private var biometricLockEnabled = false
    @AppStorage("profile.language") private var selectedLanguage = "English"

    @State private var showSignIn = false
    @State private var isSigningOut = false
    @State private var isSavingProfile = false
    @State private var isRefreshingSync = false
    @State private var isSendingPasswordReset = false
    @State private var isResendingConfirmation = false
    @State private var errorMessage: String?
    @State private var activeSheet: ProfileSheet?
    @State private var toastMessage: String?
    @State private var draftDisplayName = ""
    @State private var avatarImage: Image?
    @State private var selectedItem: PhotosPickerItem?
    @State private var showAvatarSourceSelector = false
    @State private var showPhotosPicker = false

    private let supportEmail = "support@creato.app"

    private var selectedTheme: CreatoTheme {
        CreatoTheme.from(themeRawValue)
    }

    private var storedDisplayName: String {
        get {
            guard let email = authManager.currentUserEmail else { return "" }
            return UserDefaults.standard.string(forKey: displayNameKey(for: email)) ?? ""
        }
        nonmutating set {
            guard let email = authManager.currentUserEmail else { return }
            UserDefaults.standard.set(newValue, forKey: displayNameKey(for: email))
        }
    }

    private var resolvedDisplayName: String {
        if !storedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return storedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let email = authManager.currentUserEmail, !email.isEmpty else {
            return "Guest User"
        }

        let localPart = email.split(separator: "@").first.map(String.init) ?? email
        let cleaned = localPart.replacingOccurrences(
            of: #"[^A-Za-z]+"#,
            with: " ",
            options: .regularExpression
        )
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Creato User" : trimmed.capitalized
    }

    private var secondaryText: String {
        authManager.currentUserEmail ?? "Using local demo data"
    }

    private var statusTitle: String {
        switch authManager.state {
        case .authenticated:
            return "Cloud Sync Active"
        case .pendingEmailConfirmation:
            return "Email Confirmation Pending"
        case .guest:
            return "Guest Workspace"
        case .loading:
            return "Loading"
        }
    }

    private var statusDetail: String {
        switch authManager.state {
        case .authenticated:
            return "Your library is connected to your account."
        case .pendingEmailConfirmation:
            return "You're in offline mode until email verification is complete."
        case .guest:
            return "You're previewing the app with local sample content."
        case .loading:
            return "Preparing your account details."
        }
    }

    private var bottomButtonTitle: String {
        authManager.hasAccountContext ? "Log Out" : "Sign In"
    }

    private var totalFavorites: Int {
        designStore.designs.filter(\.isFavorite).count
    }

    private var totalImageDesigns: Int {
        designStore.designs.filter { $0.designType == .image }.count
    }

    private var totalStoryVideos: Int {
        designStore.designs.filter { $0.designType == .video }.count
    }

    private var stats: [ProfileStat] {
        [
            ProfileStat(title: "Designs", value: "\(totalImageDesigns)", section: .designs),
            ProfileStat(title: "Albums", value: "\(designStore.albums.count)", section: .albums),
            ProfileStat(title: "Stories", value: "\(totalStoryVideos)", section: .stories),
            ProfileStat(title: "Favorites", value: "\(totalFavorites)", section: .favorites)
        ]
    }

    private var accountRows: [SettingsRowModel] {
        [
            SettingsRowModel(
                title: "Profile Details",
                subtitle: resolvedDisplayName,
                systemImage: "person.text.rectangle",
                action: { openSheet(.editProfile) }
            ),

            SettingsRowModel(
                title: "Notifications",
                subtitle: notificationsEnabled ? "Enabled" : "Disabled",
                systemImage: "bell.badge",
                action: { openSheet(.notifications) }
            ),
            SettingsRowModel(
                title: "Security",
                subtitle: authManager.hasAccountContext ? "Password, reset, and device access" : "Guest protection settings",
                systemImage: "lock.shield",
                action: { openSheet(.security) }
            ),
            SettingsRowModel(
                title: "Appearance",
                subtitle: selectedTheme.title,
                systemImage: "circle.lefthalf.filled",
                action: { openSheet(.appearance) }
            ),
            SettingsRowModel(
                title: "Language",
                subtitle: selectedLanguage,
                systemImage: "globe",
                action: { openSheet(.language) }
            )
        ]
    }

    private var supportRows: [SettingsRowModel] {
        [
            SettingsRowModel(
                title: "Help Center",
                subtitle: "Answers for sign-in, sync, and account recovery",
                systemImage: "questionmark.circle",
                action: { openSheet(.helpCenter) }
            ),
            SettingsRowModel(
                title: "Contact Support",
                subtitle: supportEmail,
                systemImage: "message.circle",
                action: { openSheet(.reportBug) }
            ),
            SettingsRowModel(
                title: "Privacy Policy",
                subtitle: "How account and design data is handled",
                systemImage: "hand.raised",
                action: { openSheet(.privacy) }
            ),
            SettingsRowModel(
                title: "Terms of Use",
                subtitle: "Usage expectations for the app",
                systemImage: "doc.text",
                action: { openSheet(.terms) }
            ),
            SettingsRowModel(
                title: "About Creato",
                subtitle: appVersionSummary,
                systemImage: "info.circle",
                action: { openSheet(.about) }
            )
        ]
    }

    private var appVersionSummary: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection

                    if authManager.needsEmailConfirmation {
                        emailConfirmationCard
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    settingsSection(title: "", rows: accountRows)
                    settingsSection(title: "Support", rows: supportRows)
                    bottomActionButton
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ProfileLibrarySection.self) { section in
                profileLibraryDestination(for: section)
            }
            .sheet(isPresented: $showSignIn) {
                LoginView()
                    .environment(authManager)
                    .environment(designStore)
            }
            .sheet(item: $activeSheet) { sheet in
                NavigationStack {
                    sheetView(for: sheet)
                }
                .presentationDetents(sheet.presentationDetents)
            }
            .overlay(alignment: .bottom) {
                if let toastMessage {
                    Label(toastMessage, systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .photosPicker(isPresented: $showPhotosPicker, selection: $selectedItem, matching: .images)
            .confirmationDialog("Profile Picture", isPresented: $showAvatarSourceSelector, titleVisibility: .visible) {
                Button("Choose from Library") {
                    showPhotosPicker = true
                }
                if avatarImage != nil {
                    Button("Remove Photo", role: .destructive) {
                        deleteAvatarImage()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: selectedItem) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            saveAvatarImage(uiImage)
                        }
                    }
                }
            }
            .onChange(of: authManager.currentUserEmail) { _ in
                loadAvatarImage()
            }
            .task {
                draftDisplayName = resolvedDisplayName
                loadAvatarImage()
            }
        }
    }

    private var emailConfirmationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Email confirmation required", systemImage: "envelope.badge")
                .font(.headline)

            Text("You can keep exploring in the app for now. Once your email is confirmed, sign in again to enable cloud sync for your designs.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    Task { await resendConfirmationEmail() }
                } label: {
                    Group {
                        if isResendingConfirmation {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Resend Email")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isResendingConfirmation)

                Button("Open Sign In") {
                    showSignIn = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var heroSection: some View {
        VStack(spacing: 20) {
            // Profile Header Group (Centered, on system grouped background)
            VStack(spacing: 8) {
                Button {
                    if avatarImage != nil {
                        showAvatarSourceSelector = true
                    } else {
                        showPhotosPicker = true
                    }
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        ProfileAvatarView(avatarImage: avatarImage, name: resolvedDisplayName, accentColor: selectedTheme.accentColor)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                            .offset(x: 4, y: 2)
                    }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 6)
                
                Text(resolvedDisplayName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            
            // Stats Grid Section
            VStack(alignment: .leading, spacing: 10) {
                Text("Library Statistics")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(stats) { stat in
                        statCard(stat)
                    }
                }
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
    }

    private func statCard(_ stat: ProfileStat) -> some View {
        NavigationLink(value: stat.section) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stat.title)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(stat.value)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Image(systemName: statIcon(for: stat.section))
                    .font(.title3)
                    .foregroundStyle(statIconColor(for: stat.section))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func statIcon(for section: ProfileLibrarySection) -> String {
        switch section {
        case .designs: return "photo.on.rectangle"
        case .albums: return "rectangle.stack"
        case .stories: return "play.rectangle"
        case .favorites: return "heart.fill"
        }
    }

    private func statIconColor(for section: ProfileLibrarySection) -> Color {
        switch section {
        case .designs: return .blue
        case .albums: return .purple
        case .stories: return .orange
        case .favorites: return .red
        }
    }

    @ViewBuilder
    private func profileLibraryDestination(for section: ProfileLibrarySection) -> some View {
        switch section {
        case .designs, .stories, .favorites:
            ProfileDesignLibraryView(section: section)
                .toolbar(.hidden, for: .tabBar)
        case .albums:
            ProfileAlbumLibraryView()
                .toolbar(.hidden, for: .tabBar)
        }
    }

    private func settingsSection(title: String, rows: [SettingsRowModel]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    SettingsRowView(row: row)

                    if index < rows.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var bottomActionButton: some View {
        Button {
            if authManager.isLoggedIn || authManager.needsEmailConfirmation {
                Task { await signOut() }
            } else {
                showSignIn = true
            }
        } label: {
            if isSigningOut {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else {
                Text(bottomButtonTitle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
        .buttonStyle(.plain)
        .background(Color(.systemBackground))
        .foregroundStyle(authManager.hasAccountContext ? .red : .primary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .disabled(isSigningOut)
    }

    @ViewBuilder
    private func sheetView(for sheet: ProfileSheet) -> some View {
        switch sheet {
        case .editProfile:
            editProfileSheet

        case .notifications:
            notificationsSheet
        case .security:
            securitySheet
        case .appearance:
            appearanceSheet
        case .language:
            languageSheet
        case .helpCenter:
            helpCenterSheet
        case .reportBug:
            reportBugSheet
        case .privacy:
            supportTopicSheet(
                title: "Privacy Policy",
                sections: [
                    ProfileSupportSection(title: "Account data", body: "Email address and authentication state are used to connect your library and restore your session."),
                    ProfileSupportSection(title: "Local settings", body: "Theme, notification preferences, language selection, and your saved profile name are kept on this device for a smoother experience."),
                    ProfileSupportSection(title: "Workspace content", body: "Signed-in libraries can be cached locally and synced to cloud storage. Guest mode uses demo content only.")
                ]
            )
        case .terms:
            supportTopicSheet(
                title: "Terms of Use",
                sections: [
                    ProfileSupportSection(title: "Responsible use", body: "Use Creato with content you have permission to edit, store, and share."),
                    ProfileSupportSection(title: "Account access", body: "Keep your credentials private and sign out on shared devices when you're done."),
                    ProfileSupportSection(title: "Service changes", body: "Features such as sync, notifications, and verification may evolve as the app is updated.")
                ]
            )
        case .about:
            aboutSheet
        }
    }

    private var editProfileSheet: some View {
        Form {
            Section("Profile") {
                TextField("Display name", text: $draftDisplayName)
                LabeledContent("Email", value: secondaryText)
                LabeledContent("Account status", value: statusTitle)
            }

            if authManager.isLoggedIn {
                Section("Cloud account") {
                    Text("Saving here also updates your account metadata so the same name can follow your signed-in profile.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("Your display name is stored locally on this device so your profile header feels more personal immediately.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Profile Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { activeSheet = nil }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await saveProfileDetails() }
                } label: {
                    if isSavingProfile {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                }
                .fontWeight(.semibold)
                .disabled(isSavingProfile)
            }
        }
    }

    private var notificationsSheet: some View {
        Form {
            Section("Alerts") {
                Toggle("Enable notifications", isOn: $notificationsEnabled)
                Toggle("Product updates", isOn: $productUpdatesEnabled)
                    .disabled(!notificationsEnabled)
            }

            Section("Preview") {
                Text(notificationsEnabled ? "You'll be ready for reminders and account updates when notification flows are connected." : "Notifications are currently turned off for this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { activeSheet = nil }
            }
        }
    }

    private var securitySheet: some View {
        Form {
            Section("Access") {
                Toggle("Biometric lock", isOn: $biometricLockEnabled)
                LabeledContent("Session", value: authManager.hasAccountContext ? "Account available" : "Guest only")
            }

            if authManager.hasAccountContext {
                Section("Recovery") {
                    Button {
                        Task { await sendPasswordReset() }
                    } label: {
                        if isSendingPasswordReset {
                            ProgressView()
                        } else {
                            Label("Send password reset email", systemImage: "envelope")
                        }
                    }

                    if authManager.needsEmailConfirmation {
                        Button {
                            Task { await resendConfirmationEmail() }
                        } label: {
                            if isResendingConfirmation {
                                ProgressView()
                            } else {
                                Label("Resend confirmation email", systemImage: "paperplane")
                            }
                        }
                    }

                }
            }

            Section("Guidance") {
                Text("Biometric lock is stored as a device preference so you can decide how protected the app should feel on this phone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { activeSheet = nil }
            }
        }
    }

    private var appearanceSheet: some View {
        List {
            Section("Theme") {
                ForEach(CreatoTheme.allCases) { theme in
                    Button {
                        themeRawValue = theme.rawValue
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: theme.icon)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(theme.title)
                                Text(theme.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if theme.rawValue == themeRawValue {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { activeSheet = nil }
            }
        }
    }

    private var languageSheet: some View {
        List {
            Section("Preferred language") {
                ForEach(["English", "Hindi", "Spanish", "French"], id: \.self) { language in
                    Button {
                        selectedLanguage = language
                    } label: {
                        HStack {
                            Text(language)
                            Spacer()
                            if selectedLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { activeSheet = nil }
            }
        }
    }

    private var reportBugSheet: some View {
        List {
            Section("Contact") {
                Label(supportEmail, systemImage: "envelope")
                Button("Send Email") {
                    openSupportEmail()
                }
                Button("Copy Email") {
                    UIPasteboard.general.string = supportEmail
                    showToast("Email copied")
                }
            }

            Section("What to include") {
                Text("Mention the screen you were on, what you expected, and what actually happened.")
                Text("Include whether you were signed in, in guest mode, or waiting for email confirmation.")
            }

            if authManager.isLoggedIn {
                Section("Helpful fixes") {
                    Button {
                        Task { await refreshSync() }
                    } label: {
                        if isRefreshingSync {
                            ProgressView()
                        } else {
                            Label("Refresh library from cloud", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .navigationTitle("Contact Support")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { activeSheet = nil }
            }
        }
    }

    private var aboutSheet: some View {
        List {
            Section("Creato") {
                LabeledContent("Version", value: appVersionSummary)
                LabeledContent("Workspace mode", value: statusTitle)
                LabeledContent("Theme", value: selectedTheme.title)
            }

            Section("Why this screen changed") {
                Text("This profile center now surfaces real workspace stats, local preferences, support guidance, and account context so it feels like part of the product instead of a placeholder.")
            }
        }
        .navigationTitle("About Creato")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { activeSheet = nil }
            }
        }
    }

    private func supportTopicSheet(title: String, sections: [ProfileSupportSection]) -> some View {
        List {
            ForEach(sections) { section in
                Section(section.title) {
                    Text(section.body)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { activeSheet = nil }
            }
        }
    }

    private func openSheet(_ sheet: ProfileSheet) {
        draftDisplayName = resolvedDisplayName
        activeSheet = sheet
    }

    private var helpCenterSheet: some View {
        List {
            Section("Popular help") {
                supportActionRow(
                    title: "I can’t sign in",
                    subtitle: "Open the sign-in screen again",
                    systemImage: "person.badge.key"
                ) {
                    activeSheet = nil
                    showSignIn = true
                }

                supportActionRow(
                    title: "Reset my password",
                    subtitle: "Send a recovery email to your account",
                    systemImage: "key.horizontal"
                ) {
                    Task { await sendPasswordReset() }
                }
                .disabled(!authManager.hasAccountContext)
                .opacity(authManager.hasAccountContext ? 1 : 0.5)

                supportActionRow(
                    title: "Refresh my synced library",
                    subtitle: "Pull the latest cloud data",
                    systemImage: "arrow.clockwise"
                ) {
                    Task { await refreshSync() }
                }
                .disabled(!authManager.isLoggedIn)
                .opacity(authManager.isLoggedIn ? 1 : 0.5)
            }

            Section("Account status") {
                Text("Authenticated accounts sync to the cloud. Pending confirmation accounts stay available in offline mode until verification is complete.")
                    .foregroundStyle(.secondary)

                if authManager.needsEmailConfirmation {
                    Button {
                        Task { await resendConfirmationEmail() }
                    } label: {
                        if isResendingConfirmation {
                            ProgressView()
                        } else {
                            Label("Resend confirmation email", systemImage: "paperplane")
                        }
                    }
                }
            }

            Section("Still need help?") {
                Button("Email Support") {
                    openSupportEmail()
                }
                Button("Copy Support Email") {
                    UIPasteboard.general.string = supportEmail
                    showToast("Email copied")
                }
            }
        }
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { activeSheet = nil }
            }
        }
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(duration: 0.3)) {
            toastMessage = message
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            await MainActor.run {
                withAnimation(.spring(duration: 0.3)) {
                    toastMessage = nil
                }
            }
        }
    }

    private func saveProfileDetails() async {
        let trimmed = draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Display name can't be empty."
            return
        }

        isSavingProfile = true
        defer { isSavingProfile = false }
        errorMessage = nil

        do {
            storedDisplayName = trimmed
            if authManager.isLoggedIn {
                try await authManager.updateDisplayName(trimmed)
                try await authManager.refreshCurrentUser()
            }
            activeSheet = nil
            showToast("Profile updated")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshSync() async {
        guard authManager.isLoggedIn else { return }
        isRefreshingSync = true
        defer { isRefreshingSync = false }
        errorMessage = nil

        await designStore.clearAndLoadFromCloud(authManager: authManager)
        showToast("Library refreshed")
    }

    private func sendPasswordReset() async {
        guard authManager.hasAccountContext else { return }
        isSendingPasswordReset = true
        defer { isSendingPasswordReset = false }
        errorMessage = nil

        do {
            try await authManager.sendPasswordReset()
            showToast("Reset email sent")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resendConfirmationEmail() async {
        guard authManager.needsEmailConfirmation else { return }
        isResendingConfirmation = true
        defer { isResendingConfirmation = false }
        errorMessage = nil

        do {
            try await authManager.resendConfirmationEmail()
            showToast("Confirmation email sent")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signOut() async {
        isSigningOut = true
        defer { isSigningOut = false }
        errorMessage = nil

        do {
            try await authManager.signOut()
            designStore.resetToGuestMode()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func displayNameKey(for email: String) -> String {
        "profile.displayName.\(email.lowercased())"
    }

    private var avatarImageURL: URL? {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let identifier = authManager.currentUserEmail?.lowercased() ?? "guest"
        let sanitizedIdentifier = identifier.replacingOccurrences(of: "@", with: "_").replacingOccurrences(of: ".", with: "_")
        let filename = "avatar_\(sanitizedIdentifier).jpg"
        return documentsDirectory.appendingPathComponent(filename)
    }

    private func loadAvatarImage() {
        guard let avatarImageURL, FileManager.default.fileExists(atPath: avatarImageURL.path) else {
            self.avatarImage = nil
            return
        }
        if let uiImage = UIImage(contentsOfFile: avatarImageURL.path) {
            self.avatarImage = Image(uiImage: uiImage)
        } else {
            self.avatarImage = nil
        }
    }

    private func saveAvatarImage(_ uiImage: UIImage) {
        guard let avatarImageURL else { return }
        if let data = uiImage.jpegData(compressionQuality: 0.8) {
            do {
                try data.write(to: avatarImageURL)
                self.avatarImage = Image(uiImage: uiImage)
                showToast("Profile image updated")
            } catch {
                errorMessage = "Failed to save profile image: \(error.localizedDescription)"
            }
        }
    }

    private func deleteAvatarImage() {
        guard let avatarImageURL else { return }
        try? FileManager.default.removeItem(at: avatarImageURL)
        self.avatarImage = nil
        showToast("Profile image removed")
    }

    private func openSupportEmail() {
        guard let url = URL(string: "mailto:\(supportEmail)?subject=Creato%20Support") else { return }
        openURL(url)
    }

    private func supportActionRow(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .frame(width: 24)
                    .font(.body.weight(.semibold))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.medium))
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsRowModel {
    let title: String
    let subtitle: String?
    let systemImage: String
    var showsChevron: Bool = true
    let action: (() -> Void)?
}

private struct SettingsRowView: View {
    let row: SettingsRowModel

    var body: some View {
        Button {
            row.action?()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: row.systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 24)
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    if let subtitle = row.subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 12)

                if row.showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(row.action == nil)
    }
}

private struct ProfileAvatarView: View {
    let avatarImage: Image?
    let name: String
    let accentColor: Color

    private var initials: String {
        let components = name.split(separator: " ")
        let letters = components.prefix(2).compactMap { $0.first }
        let value = String(letters)
        return value.isEmpty ? "CU" : value.uppercased()
    }

    var body: some View {
        Group {
            if let avatarImage {
                avatarImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.85),
                                    accentColor.opacity(0.30)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text(initials)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 88, height: 88)
    }
}

private struct ProfileStat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let section: ProfileLibrarySection
}

private enum ProfileLibrarySection: String, Hashable, Identifiable {
    case designs
    case albums
    case stories
    case favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .designs:
            return "Designs"
        case .albums:
            return "Albums"
        case .stories:
            return "Stories"
        case .favorites:
            return "Favorites"
        }
    }

    var emptyTitle: String {
        switch self {
        case .designs:
            return "No designs yet"
        case .albums:
            return "No albums yet"
        case .stories:
            return "No stories yet"
        case .favorites:
            return "No favorites yet"
        }
    }

    var emptyMessage: String {
        switch self {
        case .designs:
            return "Create your first design and it will appear here."
        case .albums:
            return "Create an album to collect related designs."
        case .stories:
            return "Saved story videos will appear here."
        case .favorites:
            return "Tap the heart on a design or story to save it here."
        }
    }

    var emptyIcon: String {
        switch self {
        case .designs:
            return "square.grid.2x2"
        case .albums:
            return "rectangle.stack"
        case .stories:
            return "play.rectangle"
        case .favorites:
            return "heart"
        }
    }
}

private struct ProfileDesignLibraryView: View {
    @Environment(DataStore.self) private var designStore
    @Environment(\.horizontalSizeClass) private var hSize

    let section: ProfileLibrarySection

    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: hSize == .regular ? 180 : 150, maximum: 280), spacing: 18)
        ]
    }

    private var designs: [Design] {
        let filtered: [Design]

        switch section {
        case .designs:
            filtered = designStore.designs.filter { $0.designType == .image }
        case .stories:
            filtered = designStore.designs.filter { $0.designType == .video }
        case .favorites:
            filtered = designStore.designs.filter(\.isFavorite)
        case .albums:
            filtered = []
        }

        return filtered.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            if designs.isEmpty {
                ProfileLibraryEmptyView(section: section)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 120)
            } else {
                DesignGridView(
                    designs: designs,
                    layoutMode: .grid,
                    masonColumn: hSize == .regular ? 4 : 2,
                    columns: columns,
                    onAddTap: {},
                    showsAddCard: false
                )
                .padding(.top, 12)
            }
        }
        .scrollIndicators(.visible)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct ProfileAlbumLibraryView: View {
    @Environment(DataStore.self) private var designStore

    private let horizontalPadding: CGFloat = 16
    private let spacing: CGFloat = 10
    private let cardAspectRatio: CGFloat = 252 / 180

    var body: some View {
        GeometryReader { proxy in
            let columnCount = columnCount(for: proxy.size.width)
            let cardWidth = cardWidth(for: proxy.size.width, columnCount: columnCount)
            let cardHeight = cardWidth * cardAspectRatio
            let columns = Array(
                repeating: GridItem(.fixed(cardWidth), spacing: spacing),
                count: columnCount
            )

            ScrollView {
                if designStore.albums.isEmpty {
                    ProfileLibraryEmptyView(section: .albums)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)
                } else {
                    LazyVGrid(columns: columns, spacing: spacing) {
                        ForEach(designStore.albums.sorted { $0.createdAt > $1.createdAt }) { album in
                            let albumDesigns = designStore.designs.filter {
                                album.albumDesignIDs.contains($0.id)
                            }
                            let thumbnail = albumDesigns.first?.thumbnailPath ?? album.thumbnailPath

                            NavigationLink {
                                AlbumPreviewView(album: album)
                                    .toolbar(.hidden, for: .tabBar)
                            } label: {
                                ZStack(alignment: .bottomLeading) {
                                    DesignImageView(path: thumbnail.isEmpty ? "photo" : thumbnail)
                                        .scaledToFill()
                                        .frame(width: cardWidth, height: cardHeight)
                                        .clipped()

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(album.albumName.isEmpty ? "Untitled Album" : album.albumName)
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)

                                        Text("\(album.albumDesignIDs.count) design\(album.albumDesignIDs.count == 1 ? "" : "s")")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.white.opacity(0.82))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(
                                        LinearGradient(
                                            colors: [.clear, .black.opacity(0.68)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                }
                                .frame(width: cardWidth, height: cardHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
                                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 12)
                }
            }
            .scrollIndicators(.visible)
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle(ProfileLibrarySection.albums.title)
        .navigationBarTitleDisplayMode(.large)
    }

    private func columnCount(for width: CGFloat) -> Int {
        if width >= 900 { return 4 }
        if width >= 680 { return 3 }
        return 2
    }

    private func cardWidth(for width: CGFloat, columnCount: Int) -> CGFloat {
        let resolvedColumns = max(CGFloat(columnCount), 1)
        let availableWidth = max(width - (horizontalPadding * 2), 1)
        let totalSpacing = spacing * (resolvedColumns - 1)
        return max((availableWidth - totalSpacing) / resolvedColumns, 1)
    }
}

private struct ProfileLibraryEmptyView: View {
    let section: ProfileLibrarySection

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: section.emptyIcon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 72, height: 72)
                .background(Color(.secondarySystemBackground), in: Circle())

            Text(section.emptyTitle)
                .font(.headline)

            Text(section.emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .padding(.horizontal, 24)
    }
}

private struct ProfileSupportSection: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

private enum ProfileSheet: String, Identifiable {
    case editProfile

    case notifications
    case security
    case appearance
    case language
    case helpCenter
    case reportBug
    case privacy
    case terms
    case about

    var id: String { rawValue }

    var presentationDetents: Set<PresentationDetent> {
        switch self {
        case .editProfile, .notifications, .security:
            return [.medium, .large]
        default:
            return [.large]
        }
    }
}
