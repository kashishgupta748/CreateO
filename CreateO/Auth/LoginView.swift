//
//  LoginView.swift
//  creato
//
//  Created by GU on 24/04/26.
//

import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(DataStore.self) private var designStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage("profile.theme") private var themeRawValue = CreatoTheme.system.rawValue

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var isLoading = false
    @State private var isSendingReset = false
    @State private var showSignUp = false
    @State private var showPassword = false

    private var selectedTheme: CreatoTheme {
        CreatoTheme.from(themeRawValue)
    }

    private var emailIsValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    private var canSubmit: Bool {
        !isLoading && emailIsValid && !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                    formSection
                    footerSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 24)
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSignUp) {
                NavigationStack {
                    SignUpView()
                        .environment(authManager)
                        .environment(designStore)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CreateO")
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text("Sign in to continue.")
                .font(.title3.weight(.semibold))
        }
        .padding(.top, 12)
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 14) {
                field(
                    title: "Email",
                    showsWarning: !email.isEmpty && !emailIsValid
                ) {
                    TextField("", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                field(title: "Password") {
                    HStack(spacing: 12) {
                        Group {
                            if showPassword {
                                TextField("Enter your password", text: $password)
                            } else {
                                SecureField("Enter your password", text: $password)
                            }
                        }
                        .textContentType(.password)

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Spacer()

                Button {
                    Task { await sendPasswordReset() }
                } label: {
                    if isSendingReset {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Forgot Password?")
                            .font(.footnote.weight(.semibold))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(emailIsValid ? Color.accentColor : .secondary)
                .disabled(isSendingReset || !emailIsValid)
                .opacity((isSendingReset || emailIsValid) ? 1 : 0.55)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if let infoMessage {
                Text(infoMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if !email.isEmpty && !emailIsValid {
                Text("Enter a valid email address.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await signIn() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.5)

            Button {
                showSignUp = true
            } label: {
                Text("Create Account")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Continue with Demo Data") {
                errorMessage = nil
                authManager.continueAsGuest()
                Task { await designStore.bootstrap(authManager: authManager) }
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            Text("Preview the app first with sample content.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func field<Content: View>(
        title: String,
        showsWarning: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(showsWarning ? Color.red.opacity(0.35) : Color.clear, lineWidth: 1)
                )
        }
    }

    private func signIn() async {
        infoMessage = nil
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await authManager.signIn(email: email, password: password)
            await designStore.clearAndLoadFromCloud(authManager: authManager)
            dismiss()
        } catch {
            let message = error.localizedDescription.lowercased()
            if message.contains("invalid login credentials") {
                errorMessage = "Invalid email or password."
            } else if message.contains("email not confirmed") {
                errorMessage = "Please confirm your email before signing in again."
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func sendPasswordReset() async {
        guard emailIsValid else {
            errorMessage = "Enter your email first to reset your password."
            infoMessage = nil
            return
        }

        errorMessage = nil
        infoMessage = nil
        isSendingReset = true
        defer { isSendingReset = false }

        do {
            try await authManager.sendPasswordReset(email: email)
            infoMessage = "Password reset email sent."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
