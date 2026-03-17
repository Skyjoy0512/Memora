import Foundation
import Observation

@Observable
final class HomeViewModel {
    var audioFiles: [AudioFile] = []

    func loadAudioFiles() {
        // TODO: SwiftData からファイルを読み込む
    }
}
