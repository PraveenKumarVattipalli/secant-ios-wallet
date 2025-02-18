//
//  OnboardingFooterView.swift
//  secant-testnet
//
//  Created by Adam Stener on 11/18/21.
//

import SwiftUI
import ComposableArchitecture
import Generated
import ImportWallet

public struct OnboardingFooterView: View {
    let store: OnboardingFlowStore
    let animationDuration: CGFloat = 0.8

    public init(store: OnboardingFlowStore) {
        self.store = store
    }
    
    public var body: some View {
        WithViewStore(self.store) { viewStore in
            VStack(spacing: 5) {
                if viewStore.isFinalStep {
                    Button(L10n.Onboarding.Button.newWallet) {
                        viewStore.send(.createNewWallet, animation: .easeInOut(duration: animationDuration))
                    }
                    .activeButtonStyle
                    .minimumScaleFactor(0.1)

                    Button(L10n.Onboarding.Button.importWallet) {
                        viewStore.send(.importExistingWallet, animation: .easeInOut(duration: animationDuration))
                    }
                    .activeButtonStyle
                    .minimumScaleFactor(0.1)
                } else {
                    Button(L10n.General.next) {
                        viewStore.send(.next, animation: .easeInOut(duration: animationDuration))
                    }
                    .activeButtonStyle
                    .minimumScaleFactor(0.1)

                    ProgressView(
                        String(format: "%02d", viewStore.index + 1),
                        value: Double(viewStore.index + 1),
                        total: Double(viewStore.steps.count)
                    )
                    .onboardingProgressStyle
                    .padding(.horizontal, 30)
                    .padding(.vertical, 20)
                }
            }
            .padding(.top, 10)
            .padding(.horizontal, 30)
            .navigationLinkEmpty(
                isActive: viewStore.bindingForDestination(.importExistingWallet),
                destination: {
                    ImportWalletView(
                        store: store.scope(
                            state: \.importWalletState,
                            action: OnboardingFlowReducer.Action.importWallet
                        )
                    )
                }
            )
        }
    }
}

// swiftlint:disable:next private_over_fileprivate strict_fileprivate
fileprivate struct OnboardingFooterButtonLayout: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(height: 60)
            .padding(.horizontal, 28)
            .transition(.opacity)
    }
}

extension View {
    func onboardingFooterButtonLayout() -> some View {
        modifier(OnboardingFooterButtonLayout())
    }
}

// MARK: - Previews

struct OnboardingFooterView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store<OnboardingFlowReducer.State, OnboardingFlowReducer.Action>(
            initialState: OnboardingFlowReducer.State(
                walletConfig: .default,
                importWalletState: .placeholder,
                index: 3
            ),
            reducer: OnboardingFlowReducer(saplingActivationHeight: 0)
        )
        
        Group {
            OnboardingFooterView(store: store)
                .applyScreenBackground()
                .preferredColorScheme(.light)
                .previewDevice("iPhone 14 Pro")

            OnboardingFooterView(store: store)
                .applyScreenBackground()
                .preferredColorScheme(.light)
                .previewDevice("iPhone 13 Pro Max")
            
            OnboardingFooterView(store: store)
                .applyScreenBackground()
                .preferredColorScheme(.light)
                .previewDevice("iPhone 13 mini")
        }
    }
}
