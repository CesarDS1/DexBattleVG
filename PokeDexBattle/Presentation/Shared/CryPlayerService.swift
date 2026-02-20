//
//  CryPlayerService.swift
//  PokeDexBattle — Presentation Layer / Shared
//
//  Downloads and plays a Pokémon cry MP3 from the Pokémon Showdown audio CDN.
//  Owned as @State by PokemonDetailView — one instance per detail screen.
//
//  Audio source: https://play.pokemonshowdown.com/audio/cries/{name}.mp3
//  iOS supports MP3 natively via AVAudioPlayer.
//
//  States:
//    idle      — nothing playing; button shows static speaker icon
//    loading   — MP3 is being downloaded; button shows a progress spinner
//    playing   — audio is playing; button shows an animated waveform icon
//    error     — download or playback failed; button shows an error icon
//

import AVFoundation
import Observation

/// Downloads and plays a single Pokémon cry MP3 on demand.
/// Use one instance per detail screen, stored as `@State`.
@MainActor
@Observable
final class CryPlayerService: NSObject {

    // MARK: - Public state (read by the View)

    enum PlaybackState: Equatable {
        case idle, loading, playing, error
    }

    private(set) var state: PlaybackState = .idle

    // MARK: - Private

    private var audioPlayer: AVAudioPlayer?
    private var downloadTask: URLSessionDataTask?

    // MARK: - Public API

    /// Toggles playback: stops if currently playing/loading, otherwise downloads and plays `url`.
    func toggle(url: URL) {
        switch state {
        case .playing, .loading:
            stop()
        case .idle, .error:
            play(url: url)
        }
    }

    /// Stops playback and cancels any in-flight download, resetting to idle.
    func stop() {
        downloadTask?.cancel()
        downloadTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        state = .idle
    }

    // MARK: - Private helpers

    private func play(url: URL) {
        state = .loading

        // Download the MP3 data then hand it to AVAudioPlayer.
        // URLSession is used directly (not async/await) so we can cancel mid-download.
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Ignore result if stop() was called while downloading
                guard self.state == .loading else { return }

                if let error, (error as NSError).code == NSURLErrorCancelled {
                    return  // User tapped stop — already reset to idle
                }

                guard let data, error == nil,
                      let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else {
                    self.state = .error
                    return
                }

                do {
                    let player = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.mp3.rawValue)
                    player.delegate = self
                    // Configure audio session so cry plays even when device is silent
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                    try AVAudioSession.sharedInstance().setActive(true)
                    player.prepareToPlay()
                    player.play()
                    self.audioPlayer = player
                    self.state = .playing
                } catch {
                    self.state = .error
                }
            }
        }
        downloadTask = task
        task.resume()
    }
}

// MARK: - AVAudioPlayerDelegate

extension CryPlayerService: AVAudioPlayerDelegate {
    /// Called on the main thread when the cry finishes playing naturally.
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.audioPlayer = nil
            self?.state = .idle
        }
    }

    /// Called when AVAudioPlayer encounters a decode error mid-playback.
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            self?.audioPlayer = nil
            self?.state = .error
        }
    }
}
