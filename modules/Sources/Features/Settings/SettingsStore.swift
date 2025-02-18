import ComposableArchitecture
import MessageUI
import SwiftUI
import AppVersion
import MnemonicClient
import LogsHandler
import LocalAuthenticationHandler
import SupportDataGenerator
import Models
import RecoveryPhraseDisplay
import ZcashLightClientKit
import Generated
import WalletStorage
import SDKSynchronizer
import UserPreferencesStorage
import ExportLogs
import CrashReporter

public typealias SettingsStore = Store<SettingsReducer.State, SettingsReducer.Action>
public typealias SettingsViewStore = ViewStore<SettingsReducer.State, SettingsReducer.Action>

public struct SettingsReducer: ReducerProtocol {
    public struct State: Equatable {
        public enum Destination {
            case about
            case backupPhrase
        }

        @PresentationState public var alert: AlertState<Action>?
        public var appVersion = ""
        public var appBuild = ""
        public var destination: Destination?
        public var exportLogsState: ExportLogsReducer.State
        @BindingState public var isCrashReportingOn: Bool
        public var phraseDisplayState: RecoveryPhraseDisplayReducer.State
        public var supportData: SupportData?
        
        public init(
            appVersion: String = "",
            appBuild: String = "",
            destination: Destination? = nil,
            exportLogsState: ExportLogsReducer.State,
            isCrashReportingOn: Bool,
            phraseDisplayState: RecoveryPhraseDisplayReducer.State,
            supportData: SupportData? = nil
        ) {
            self.appVersion = appVersion
            self.appBuild = appBuild
            self.destination = destination
            self.exportLogsState = exportLogsState
            self.isCrashReportingOn = isCrashReportingOn
            self.phraseDisplayState = phraseDisplayState
            self.supportData = supportData
        }
    }

    public enum Action: BindableAction, Equatable {
        case alert(PresentationAction<Action>)
        case backupWallet
        case backupWalletAccessRequest
        case binding(BindingAction<SettingsReducer.State>)
        case exportLogs(ExportLogsReducer.Action)
        case onAppear
        case phraseDisplay(RecoveryPhraseDisplayReducer.Action)
        case sendSupportMail
        case sendSupportMailFinished
        case updateDestination(SettingsReducer.State.Destination?)
    }

    @Dependency(\.appVersion) var appVersion
    @Dependency(\.localAuthentication) var localAuthentication
    @Dependency(\.mnemonic) var mnemonic
    @Dependency(\.sdkSynchronizer) var sdkSynchronizer
    @Dependency(\.logsHandler) var logsHandler
    @Dependency(\.walletStorage) var walletStorage
    @Dependency(\.userStoredPreferences) var userStoredPreferences
    @Dependency(\.crashReporter) var crashReporter

    public init() {}
    
    public var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isCrashReportingOn = !userStoredPreferences.isUserOptedOutOfCrashReporting()
                state.appVersion = appVersion.appVersion()
                state.appBuild = appVersion.appBuild()
                return .none
            case .backupWalletAccessRequest:
                return .run { send in
                    if await localAuthentication.authenticate() {
                        await send(.backupWallet)
                    }
                }
                
            case .backupWallet:
                do {
                    let storedWallet = try walletStorage.exportWallet()
                    let phraseWords = mnemonic.asWords(storedWallet.seedPhrase.value())
                    let recoveryPhrase = RecoveryPhrase(words: phraseWords.map { $0.redacted })
                    state.phraseDisplayState.phrase = recoveryPhrase
                    return EffectTask(value: .updateDestination(.backupPhrase))
                } catch {
                    state.alert = AlertState.cantBackupWallet(error.toZcashError())
                }
                return .none
                
            case .binding(\.$isCrashReportingOn):
                if state.isCrashReportingOn {
                    crashReporter.optOut()
                } else {
                    crashReporter.optIn()
                }

                return .run { [state] _ in
                    await userStoredPreferences.setIsUserOptedOutOfCrashReporting(state.isCrashReportingOn)
                }
                
            case .exportLogs:
                return .none

            case .phraseDisplay:
                state.destination = nil
                return .none
                
            case .updateDestination(let destination):
                state.destination = destination
                return .none

            case .binding:
                return .none

            case .sendSupportMail:
                if MFMailComposeViewController.canSendMail() {
                    state.supportData = SupportDataGenerator.generate()
                } else {
                    state.alert = AlertState.sendSupportMail()
                }
                return .none

            case .sendSupportMailFinished:
                state.supportData = nil
                return .none
                
            case .alert(.presented(let action)):
                return EffectTask(value: action)

            case .alert(.dismiss):
                state.alert = nil
                return .none

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: /Action.alert)

        Scope(state: \.phraseDisplayState, action: /Action.phraseDisplay) {
            RecoveryPhraseDisplayReducer()
        }

        Scope(state: \.exportLogsState, action: /Action.exportLogs) {
            ExportLogsReducer()
        }
    }
}

// MARK: - ViewStore

extension SettingsViewStore {
    var destinationBinding: Binding<SettingsReducer.State.Destination?> {
        self.binding(
            get: \.destination,
            send: SettingsReducer.Action.updateDestination
        )
    }
    
    var bindingForBackupPhrase: Binding<Bool> {
        self.destinationBinding.map(
            extract: { $0 == .backupPhrase },
            embed: { $0 ? .backupPhrase : nil }
        )
    }
    
    var bindingForAbout: Binding<Bool> {
        self.destinationBinding.map(
            extract: { $0 == .about },
            embed: { $0 ? .about : nil }
        )
    }
}

// MARK: - Store

extension SettingsStore {
    func backupPhraseStore() -> RecoveryPhraseDisplayStore {
        self.scope(
            state: \.phraseDisplayState,
            action: SettingsReducer.Action.phraseDisplay
        )
    }
}

// MARK: Alerts

extension AlertState where Action == SettingsReducer.Action {
    public static func cantBackupWallet(_ error: ZcashError) -> AlertState {
        AlertState {
            TextState(L10n.Settings.Alert.CantBackupWallet.title)
        } message: {
            TextState(L10n.Settings.Alert.CantBackupWallet.message(error.message, error.code.rawValue))
        }
    }
    
    public static func sendSupportMail() -> AlertState {
        AlertState {
            TextState(L10n.Settings.Alert.CantSendEmail.title)
        } actions: {
            ButtonState(action: .sendSupportMailFinished) {
                TextState(L10n.General.ok)
            }
        } message: {
            TextState(L10n.Settings.Alert.CantSendEmail.message)
        }
    }
}

// MARK: Placeholders

extension SettingsReducer.State {
    public static let placeholder = SettingsReducer.State(
        exportLogsState: .placeholder,
        isCrashReportingOn: true,
        phraseDisplayState: RecoveryPhraseDisplayReducer.State(
            phrase: .placeholder
        )
    )
}

extension SettingsStore {
    public static let placeholder = SettingsStore(
        initialState: .placeholder,
        reducer: SettingsReducer()
    )
}
