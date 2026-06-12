//
//  SignUpView.swift
//  creato
//
//  Created by GU on 24/04/26.
//

import SwiftUI

struct SignUpView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(DataStore.self) private var designStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage("profile.theme") private var themeRawValue = CreatoTheme.system.rawValue

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showPassword = false
    @State private var showConfirmPassword = false

    private var selectedTheme: CreatoTheme {
        CreatoTheme.from(themeRawValue)
    }

    private var emailIsValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    private var isFormValid: Bool {
        emailIsValid && password.count >= 6 && password == confirmPassword
    }

    private func friendlyMessage(for error: Error) -> String {
        let message = error.localizedDescription.lowercased()

        if message.contains("email rate limit exceeded") || message.contains("email limit exceeded") {
            return "Too many confirmation emails were requested. Try again in a little while."
        }

        if message.contains("user already registered") {
            return "That email already has an account. Try signing in instead."
        }

        return error.localizedDescription
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                headerSection
                formSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Create your account")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text("Set up your workspace in a few seconds.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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
                    secureInput(
                        placeholder: "Create a password",
                        text: $password,
                        isVisible: $showPassword
                    )
                }

                field(
                    title: "Confirm Password",
                    showsWarning: !confirmPassword.isEmpty && password != confirmPassword
                ) {
                    secureInput(
                        placeholder: "Re-enter your password",
                        text: $confirmPassword,
                        isVisible: $showConfirmPassword
                    )
                }
            }

            Text("Use at least 6 characters. If email confirmation is on, you can still enter the app right away and verify later.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await signUp() }
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create Account")
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
            .disabled(isLoading || !isFormValid)
            .opacity(isFormValid ? 1 : 0.5)
        }
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

    @ViewBuilder
    private func secureInput(
        placeholder: String,
        text: Binding<String>,
        isVisible: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Group {
                if isVisible.wrappedValue {
                    TextField(placeholder, text: text)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .textContentType(.newPassword)

            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func signUp() async {
        errorMessage = nil

        guard emailIsValid else {
            errorMessage = "Enter a valid email address."
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }

        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await authManager.signUp(email: email, password: password)

            switch result {
            case .authenticated:
                await designStore.clearAndLoadFromCloud(authManager: authManager)
                dismiss()

            case .needsEmailConfirmation:
                errorMessage = nil
                await designStore.bootstrap(authManager: authManager)
                dismiss()
            }
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }
}
