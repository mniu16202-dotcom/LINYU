import SwiftUI

struct LoginView: View {

    @EnvironmentObject private var session: AppSession
    @StateObject private var model = LoginModel()
    @FocusState private var focusedField: Field?

    private enum Field {
        case phone
        case code
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    phoneField
                    codeField
                    messageRow
                    signInButton
                }
                .padding(24)
            }
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: model.signedInContext) { _, context in
                if let context {
                    session.signIn(context)
                }
            }
        }
    }

    // MARK: - 子视图

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("淋浴")
                .font(.system(size: 34, weight: .bold))
            Text("校园热水 · iOS 端")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var phoneField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("手机号")
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField("11 位手机号", text: $model.phone)
                .keyboardType(.numberPad)
                .textContentType(.telephoneNumber)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .phone)
        }
    }

    private var codeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("短信验证码")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                TextField("验证码", text: $model.code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .code)

                Button {
                    focusedField = nil
                    Task { await model.sendCode() }
                } label: {
                    Text(model.sendCodeTitle)
                        .frame(minWidth: 96)
                }
                .buttonStyle(.bordered)
                .disabled(!model.canSendCode)
            }
        }
    }

    @ViewBuilder
    private var messageRow: some View {
        if let message = model.message {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var signInButton: some View {
        Button {
            focusedField = nil
            Task { await model.signIn() }
        } label: {
            Text(model.isSigningIn ? "登录中…" : "登录")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!model.canSignIn)
    }
}

#Preview {
    LoginView()
        .environmentObject(AppSession())
}
