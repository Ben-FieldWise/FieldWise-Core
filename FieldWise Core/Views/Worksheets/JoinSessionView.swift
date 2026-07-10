//
//  JoinSessionView.swift
//  FieldWise Core
//
//  Student-facing entry point for Phase 1C: enter a session code from
//  their teacher, then push into WorksheetFillView once joined. Mirrors
//  the visual style of the existing join-a-class flow (WelcomeView).
//

import SwiftUI

struct JoinSessionView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var store = SessionStore()

    @State private var code = ""
    @State private var pushFillView = false
    @FocusState private var codeFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(Color("BrandGreen"))
                    Text("Join a worksheet")
                        .font(.system(size: 20, weight: .bold))
                    Text("Enter the code your teacher gave you for this activity.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 12)

                TextField("e.g. K7P2QX", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1))
                    .focused($codeFieldFocused)
                    .submitLabel(.go)
                    .onSubmit { Task { await join() } }

                Button {
                    Task { await join() }
                } label: {
                    if store.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Join").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("BrandGreen"))
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isLoading)
            }
            .padding(24)
        }
        .background(Color("GeoSurface"))
        .navigationTitle("Join Worksheet")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $pushFillView) {
            WorksheetFillView(store: store)
        }
        .alert("Couldn't join", isPresented: .constant(store.errorText != nil), actions: {
            Button("OK") { store.errorText = nil }
        }, message: {
            Text(store.errorText ?? "")
        })
        .onAppear { codeFieldFocused = true }
    }

    private func join() async {
        codeFieldFocused = false
        await store.joinAndLoad(code: code)
        if store.errorText == nil, store.myResponse != nil {
            pushFillView = true
        }
    }
}
