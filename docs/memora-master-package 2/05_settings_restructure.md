# 05. 設定画面の階層化 詳細設計書

Lane: A (UI) / STT コア変更: なし / 依存: なし / 対応 PR: PR-A8

---

## 1. 目的

現状 `SettingsView` は1画面に 16 セクションが平置きされ、BLE デバッグ・開発者機能・デバッグまでユーザーに露出している(確認済み)。PLAUD 同様「基本操作は浅く、高度な機能は深く」の階層へ再構成し、開発者向け項目は DEBUG ビルド限定にする。

## 2. 現状のセクション一覧と行き先(確認済み 16 個)

| 現行セクション | 新配置 |
|---|---|
| TranscriptionSettingsSection | ルート「文字起こしと AI」 |
| AIProviderSection | ルート「文字起こしと AI」 |
| V6AIProviderSettingsSheet | ルート「文字起こしと AI」から開く AI モデル／API キー設定シート |
| CustomTemplateSection | ルート「文字起こしと AI」 |
| NotionIntegrationSection | 「連携」サブ画面 |
| GoogleMeetSection | 「連携」サブ画面 |
| MeetingCaptureSection | 「連携」サブ画面 |
| BotMeetingSection | 「連携」サブ画面(experimental 注記を付ける) |
| DeviceConnectionSection | 「連携」サブ画面 |
| MemorySettingsSection | ルート「AI メモリ」(既存 `MemorySettingsView` への NavigationLink があるなら踏襲) |
| RealtimeTranscriptionSection | 「高度な設定」サブ画面 |
| UsageInstructionsSection | ルート最下部「ヘルプ」 |
| DataManagementSection | 「高度な設定」サブ画面 |
| BLEDebugSection | 「開発者」サブ画面(**#if DEBUG**) |
| DeveloperFeaturesSection | 「開発者」サブ画面(**#if DEBUG**) |
| DebugSection | 「開発者」サブ画面(**#if DEBUG**) |

■確認せよ: 各 Section が受け取る `state`(`SettingsBindings` の型)の伝搬。サブ画面へは同じ state オブジェクトを渡す。

## 3. 実装

### 3.1 新規ファイル(3つ)

`Memora/Views/Settings/IntegrationsSettingsView.swift`:

```swift
import SwiftUI

struct IntegrationsSettingsView: View {
    // ■確認: SettingsView が保持する state の型名(例: SettingsState / SettingsBindings)
    @Bindable var state: SettingsState

    var body: some View {
        Form {
            DeviceConnectionSection()
            NotionIntegrationSection(state: state)
            GoogleMeetSection(state: state)
            MeetingCaptureSection()
            Section {
                BotMeetingSection(state: state)
            } footer: {
                Text("会議 Bot は実験的な機能です。動作にはセルフホストの Bot サーバーが必要です。")
            }
        }
        .navigationTitle("連携")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

`Memora/Views/Settings/AdvancedSettingsView.swift`:

```swift
import SwiftUI

struct AdvancedSettingsView: View {
    @Bindable var state: SettingsState

    var body: some View {
        Form {
            RealtimeTranscriptionSection()
            DataManagementSection(state: state)
        }
        .navigationTitle("高度な設定")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

`Memora/Views/Settings/DeveloperSettingsView.swift`:

```swift
#if DEBUG
import SwiftUI

struct DeveloperSettingsView: View {
    @Bindable var state: SettingsState

    var body: some View {
        Form {
            DeveloperFeaturesSection(state: state)
            BLEDebugSection()
            DebugSection(state: state)
        }
        .navigationTitle("開発者")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
```

### 3.2 `SettingsView.swift` の再構成

```swift
var body: some View {
    NavigationStack {          // ■確認: 既存が NavigationStack を持つか。持つならそのまま
        Form {
            Section("文字起こしと AI") {
                TranscriptionSettingsSection(state: state)
                AIProviderSection(state: state)
                // API キーは V6AIProviderSettingsSheet で Keychain に保存する
                CustomTemplateSection(state: state)
            }

            Section("AI メモリ") {
                MemorySettingsSection()
            }

            Section {
                NavigationLink {
                    IntegrationsSettingsView(state: state)
                } label: {
                    Label("連携", systemImage: "link")
                }
                NavigationLink {
                    AdvancedSettingsView(state: state)
                } label: {
                    Label("高度な設定", systemImage: "gearshape.2")
                }
                #if DEBUG
                NavigationLink {
                    DeveloperSettingsView(state: state)
                } label: {
                    Label("開発者", systemImage: "hammer")
                }
                #endif
            }

            Section("ヘルプ") {
                UsageInstructionsSection()
            }
        }
        .navigationTitle("設定")
    }
}
```

注意:
- 既存 Section が自前で `Section { ... }` を含む実装の場合、二重 Section になる。■確認: 各 `*Section` の中身。自前 Section を持つものはルート `Section("...")` で包まず並置する(Form 直下)。上記コードは「Section を持たない行の集合」前提の参考形。実装時に各ファイルを開いて判断し、**見た目のグルーピングが §2 の表どおりになること**を優先する。
- `STTDiagnosticsView` への既存導線が設定内にある場合(■確認)、「高度な設定」内へ移す。

### 3.3 リリースビルドでの検証

`#if DEBUG` の効きを確認するため、Release configuration でビルドし「開発者」リンクが出ないことを確認(XcodeBuildMCP `build_sim` に `-configuration Release` 相当。不可ならスキーム設定で確認)。

## 4. AC

1. 設定ルートの表示要素が「文字起こしと AI(4項目)/ AI メモリ / 連携 / 高度な設定 / (DEBUG のみ)開発者 / ヘルプ」に収まる。
2. 全 16 セクションの機能が新配置で従来どおり動作する(各画面を開いて操作)。
3. Release ビルドで開発者リンクが非表示。
4. `state` の変更が全サブ画面で双方向に反映される(例: API キー入力 → 文字起こしに反映)。
5. 既存のディープリンク/他画面からの設定参照(あれば ■確認)が壊れていない。

## 5. QA チェックリスト

- [ ] API キー入力 → API モード文字起こしが成功
- [ ] Notion 接続テスト / ページ選択
- [ ] PLAUD ログイン・同期(DeviceConnection)
- [ ] データ管理(削除系)の確認ダイアログ
- [ ] リアルタイム文字起こしのトグル
- [ ] DEBUG ビルドで開発者3セクションが機能
