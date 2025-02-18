//
//  ImportBirthdayView.swift
//  secant-testnet
//
//  Created by Lukáš Korba on 03/06/2023.
//

import SwiftUI
import ComposableArchitecture
import Generated
import UIComponents

public struct ImportBirthdayView: View {
    var store: ImportWalletStore

    public init(store: ImportWalletStore) {
        self.store = store
    }
    
    public var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                Text(L10n.ImportWallet.Birthday.description)
                    .font(
                        .custom(FontFamily.Inter.regular.name, size: 16)
                        .weight(.bold)
                    )
                    .foregroundColor(Asset.Colors.Mfp.fontDark.color)
                
                TextField(
                    L10n.ImportWallet.Birthday.placeholder,
                    text: viewStore.bindingForRedactableBirthday(viewStore.birthdayHeight)
                )
                .keyboardType(.numberPad)
                .autocapitalization(.none)
                .importSeedEditorModifier()
                
                Button(L10n.ImportWallet.Button.restoreWallet) {
                    viewStore.send(.restoreWallet)
                }
                .activeButtonStyle
                .importWalletButtonLayout()
                .disable(
                    when: !viewStore.isValidForm,
                    dimmingOpacity: 0.5
                )
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .applyScreenBackground()
            .scrollableWhenScaledUp()
            .onAppear(perform: { viewStore.send(.onAppear) })
        }
    }
}

// MARK: - Previews

struct ImportBirthdayView_Previews: PreviewProvider {
    static var previews: some View {
        ImportBirthdayView(store: .demo)
            .preferredColorScheme(.light)

        ImportBirthdayView(store: .demo)
            .previewDevice(PreviewDevice(rawValue: "iPhone SE (2nd generation)"))
            .preferredColorScheme(.light)
    }
}
