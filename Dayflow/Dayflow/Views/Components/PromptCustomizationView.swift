//
//  PromptCustomizationView.swift
//  Dayflow
//
//  Generic reusable view for prompt customization UI
//

import SwiftUI

/// Generic view for prompt customization that works for any provider
struct PromptCustomizationView: View {
    let introText: String
    let fields: [PromptFieldConfig]
    @Binding var fieldStates: [String: PromptFieldState]
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(introText)
                .font(.custom("Nunito", size: 12))
                .foregroundColor(.black.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(fields, id: \.key) { field in
                promptSection(
                    heading: field.heading,
                    description: field.description,
                    fieldKey: field.key
                )
            }

            HStack {
                Spacer()
                DayflowSurfaceButton(
                    action: onReset,
                    content: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Dayflow defaults")
                                .font(.custom("Nunito", size: 13))
                        }
                        .padding(.horizontal, 2)
                    },
                    background: Color.white,
                    foreground: Color(red: 0.25, green: 0.17, blue: 0),
                    borderColor: Color(hex: "FFE0A5"),
                    cornerRadius: 8,
                    horizontalPadding: 18,
                    verticalPadding: 9,
                    showOverlayStroke: true
                )
            }
        }
    }

    @ViewBuilder
    private func promptSection(
        heading: String,
        description: String,
        fieldKey: String
    ) -> some View {
        let state = Binding(
            get: { fieldStates[fieldKey] ?? PromptFieldState(defaultText: "") },
            set: { fieldStates[fieldKey] = $0 }
        )

        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(
                get: { state.wrappedValue.isEnabled },
                set: { state.wrappedValue.isEnabled = $0 }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(heading)
                        .font(.custom("Nunito", size: 14))
                        .fontWeight(.semibold)
                        .foregroundColor(.black.opacity(0.75))
                    Text(description)
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.black.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.25, green: 0.17, blue: 0)))

            promptEditorBlock(
                title: "Prompt text",
                text: Binding(
                    get: { state.wrappedValue.text },
                    set: { state.wrappedValue.text = $0 }
                ),
                isEnabled: state.wrappedValue.isEnabled,
                defaultText: state.wrappedValue.defaultText
            )
        }
        .padding(16)
        .background(Color.white.opacity(0.95))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "FFE0A5"), lineWidth: 0.8)
        )
    }

    private func promptEditorBlock(
        title: String,
        text: Binding<String>,
        isEnabled: Bool,
        defaultText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("Nunito", size: 12))
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.6))
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(defaultText)
                        .font(.custom("Nunito", size: 12))
                        .foregroundColor(.black.opacity(0.4))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .fixedSize(horizontal: false, vertical: true)
                        .allowsHitTesting(false)
                }

                TextEditor(text: text)
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.black.opacity(isEnabled ? 0.85 : 0.45))
                    .scrollContentBackground(.hidden)
                    .disabled(!isEnabled)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: isEnabled ? 140 : 120)
                    .background(Color.white)
            }
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )
            .cornerRadius(8)
            .opacity(isEnabled ? 1 : 0.6)
        }
    }
}
