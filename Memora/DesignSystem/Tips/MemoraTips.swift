import TipKit

// MARK: - Memora Tips

/// ホーム画面で初回録音時に表示
struct FirstRecordingTip: Tip {
    var title: Text { Text("録音を開始") }
    var message: Text? { Text("右下のボタンをタップして、会議やメモを録音できます。") }
    var image: Image? { Image(systemName: "mic.circle.fill") }
}

/// 文字起こし完了後に表示
struct TranscriptionModeTip: Tip {
    var title: Text { Text("文字起こしモード") }
    var message: Text? { Text("設定で「ローカル」（無料）または「API」（高精度）を選べます。") }
}

/// AskAI 初回表示時に表示
struct AskAITip: Tip {
    var title: Text { Text("AI に質問") }
    var message: Text? { Text("録音内容についてAIに質問できます。ファイル単位、プロジェクト単位、全体から検索可能です。") }
}

/// ToDo 自動抽出のヒント
struct ToDoAutoExtractTip: Tip {
    var title: Text { Text("ToDo自動抽出") }
    var message: Text? { Text("録音を要約すると、自動的にToDoが抽出されます。ここで確認・編集できます。") }
}

/// デバイス連携のヒント
struct DeviceConnectionTip: Tip {
    var title: Text { Text("デバイス連携") }
    var message: Text? { Text("Omi ウェアラブルデバイスを接続して、リアルタイム文字起こしが可能です。") }
}
