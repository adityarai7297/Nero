import SwiftUI
import Neumorphic

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    // ID-based shake animation - new ID triggers new animation
    @State private var emailShakeID = UUID()
    @State private var passwordShakeID = UUID()
    
    var body: some View {
        ZStack {
            // Background
            Color.offWhite.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 20) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.blue)
                        
                        Text("Nero")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Track your workouts with precision")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Main Content - switches based on AuthPhase
                    switch authService.phase {
                    case .idle, .error:
                        loginForm
                    case .loading:
                        loginForm
                            .overlay(loadingOverlay, alignment: .center)
                    case .success:
                        EmptyView() // Navigation handled by root app
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical, 20)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isSignUp)
        .onChange(of: authService.phase) { _, newPhase in
            if case .error(let authError) = newPhase {
                handleAuthError(authError)
            }
        }
    }
    
    // MARK: - Login Form
    
    private var loginForm: some View {
        VStack(spacing: 0) {
            // Mode Selector
            NeumorphicSegmentedSwitch(
                labels: ["Sign In", "Sign Up"],
                selection: $isSignUp
            )
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .onChange(of: isSignUp) { _, _ in
                authService.resetPhase()
            }
            
            // Form Fields
            VStack(spacing: 24) {
                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Email")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if case .error(let authError) = authService.phase,
                           isEmailError(authError) {
                            Text(authError.errorDescription ?? "")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                        }
                    }
                    
                    TextField("Enter your email", text: $email)
                        .id(emailShakeID) // ID-based shake
                        .textFieldStyle(ModernFieldStyle(
                            hasError: isEmailFieldError,
                            shouldShake: isEmailFieldError
                        ))
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                // Password Field
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Password")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if case .error(let authError) = authService.phase,
                           isPasswordError(authError) {
                            Text(authError.errorDescription ?? "")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                        }
                    }
                    
                    SecureField("Enter your password", text: $password)
                        .id(passwordShakeID) // ID-based shake
                        .textFieldStyle(ModernFieldStyle(
                            hasError: isPasswordFieldError,
                            shouldShake: isPasswordFieldError
                        ))
                }
                
                // Confirm Password (Sign Up only)
                if isSignUp {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        SecureField("Confirm your password", text: $confirmPassword)
                            .textFieldStyle(ModernFieldStyle(hasError: false, shouldShake: false))
                    }
                    .transition(.opacity.combined(with: .slide))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            // Login Button
            Button(action: handleAuth) {
                HStack {
                    Text(isSignUp ? "Create Account" : "Sign In")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
            }
            .softButtonStyle(
                RoundedRectangle(cornerRadius: 12),
                padding: 14,
                mainColor: isFormValid ? Color.accentBlue : Color.gray,
                textColor: .white,
                pressedEffect: .hard
            )
            .disabled(!isFormValid || authService.phase == .loading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            // Divider
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                
                Text("or")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            
            // Social Login
            VStack(spacing: 12) {
                SocialButton(
                    title: "Continue with Google",
                    icon: "globe",
                    backgroundColor: Color(.systemGray6),
                    foregroundColor: .primary
                ) {
                    Task { await authService.signInWithGoogle() }
                }
                
                SocialButton(
                    title: "Continue with Apple",
                    icon: "applelogo",
                    backgroundColor: .black,
                    foregroundColor: .white
                ) {
                    Task { await authService.signInWithApple() }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)
            
            Text(isSignUp ? "Creating account..." : "Signing in...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10)
        )
        .allowsHitTesting(false)
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        let emailValid = !email.isEmpty && email.contains("@")
        let passwordValid = password.count >= 6
        let confirmValid = !isSignUp || (confirmPassword == password && !confirmPassword.isEmpty)
        
        return emailValid && passwordValid && confirmValid
    }
    
    private var isEmailFieldError: Bool {
        if case .error(let authError) = authService.phase {
            return isEmailError(authError)
        }
        return false
    }
    
    private var isPasswordFieldError: Bool {
        if case .error(let authError) = authService.phase {
            return isPasswordError(authError)
        }
        return false
    }
    
    // MARK: - Helper Methods
    
    private func isEmailError(_ error: AuthError) -> Bool {
        switch error {
        case .userExists, .invalidEmail:
            return true
        default:
            return false
        }
    }
    
    private func isPasswordError(_ error: AuthError) -> Bool {
        switch error {
        case .wrongCredentials, .weakPassword:
            return true
        default:
            return false
        }
    }
    
    private func handleAuth() {
        // Client-side validation first
        if !email.contains("@") || email.isEmpty {
            triggerEmailShake()
            return
        }
        
        if password.count < 6 {
            triggerPasswordShake()
            return
        }
        
        if isSignUp && password != confirmPassword {
            triggerPasswordShake()
            return
        }
        
        // Proceed with authentication
        Task {
            if isSignUp {
                await authService.signUp(email: email, password: password)
            } else {
                await authService.signIn(email: email, password: password)
            }
        }
    }
    
    private func handleAuthError(_ error: AuthError) {
        switch error {
        case .userExists, .invalidEmail:
            triggerEmailShake()
        case .wrongCredentials, .weakPassword:
            triggerPasswordShake()
        case .networkError, .unknown:
            // Show general error without field-specific shake
            break
        }
    }
    
    private func triggerEmailShake() {
        emailShakeID = UUID() // New ID triggers new animation
    }
    
    private func triggerPasswordShake() {
        passwordShakeID = UUID() // New ID triggers new animation
    }
}

// MARK: - Custom Styles & Components

struct ModernFieldStyle: TextFieldStyle {
    let hasError: Bool
    let shouldShake: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.offWhite)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(hasError ? Color.red : Color.clear, lineWidth: hasError ? 2 : 0)
                    )
                    .softInnerShadow(
                        RoundedRectangle(cornerRadius: 12),
                        darkShadow: Color.black.opacity(0.2),
                        lightShadow: Color.white,
                        spread: 0.15,
                        radius: 3
                    )
            )
            .modifier(ShakeEffect(shouldShake: shouldShake))
    }
}

struct ShakeEffect: ViewModifier {
    let shouldShake: Bool
    @State private var shakeOffset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onAppear {
                if shouldShake {
                    startShaking()
                }
            }
            .onChange(of: shouldShake) { _, newValue in
                if newValue {
                    startShaking()
                }
            }
    }
    
    private func startShaking() {
        let animation = Animation
            .easeInOut(duration: 0.1)
            .repeatCount(6, autoreverses: true)
        
        withAnimation(animation) {
            shakeOffset = 8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            shakeOffset = 0
        }
    }
}

struct SocialButton: View {
    let title: String
    let icon: String
    let backgroundColor: Color
    let foregroundColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(foregroundColor)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(foregroundColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Group {
                    if backgroundColor == .black {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(backgroundColor)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.offWhite)
                            .softOuterShadow()
                    }
                }
            )
        }
    }
}

// MARK: - Neumorphic Segmented Switch

struct NeumorphicSegmentedSwitch: View {
    let labels: [String]
    @Binding var selection: Bool // false = first, true = second
    private let cornerRadius: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let thumbWidth = width / CGFloat(labels.count)

            ZStack(alignment: .leading) {
                // Groove (depressed)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.offWhite)
                    .softInnerShadow(
                        RoundedRectangle(cornerRadius: cornerRadius),
                        darkShadow: Color.black.opacity(0.2),
                        lightShadow: Color.white,
                        spread: 0.18,
                        radius: 3
                    )

                // Thumb (raised)
                RoundedRectangle(cornerRadius: cornerRadius - 4)
                    .fill(Color.offWhite)
                    .softOuterShadow()
                    .frame(width: thumbWidth - 4, height: geo.size.height - 4)
                    .offset(x: selection ? thumbWidth + 2 : 2)
                    .animation(.easeInOut(duration: 0.25), value: selection)

                // Labels overlay
                HStack(spacing: 0) {
                    ForEach(labels.indices, id: \ .self) { idx in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selection = idx == 1
                            }
                        }) {
                            Text(labels[idx])
                                .font(.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .foregroundColor(selection == (idx == 1) ? .primary : .secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .frame(height: 44)
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthService())
} 