//
//  PlaybackMenuViewController.swift
//  MagnificentSounds
//
//  Created by Tiger Nixon on 5/4/23.
//

import UIKit
import AVFoundation

class PlaybackMenuViewController: UIViewController {
    
    var audioPlayer: AVAudioPlayer?
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var progressView: UIProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        progressView.progress = 0.0
    }
    
    let audioSampler: AudioSampler
    required init(audioSampler: AudioSampler) {
        self.audioSampler = audioSampler
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var samplerTask: Task<Void, Never>?
    
    private func stopAudioPlayer() {
        if let audioPlayer = audioPlayer {
            audioPlayer.stop()
            audioPlayer.delegate = nil
            self.audioPlayer = nil
        }
        
        if let samplerTask = samplerTask {
            samplerTask.cancel()
            self.samplerTask = nil
        }
        setPlayButtonImagePlay()
        progressView.progress = 0.0
        audioSampler.notifyStopped()
    }
    
    @IBAction func playButtonAction(_ sender: UIButton) {
        if let audioPlayer = audioPlayer {
            if audioPlayer.isPlaying {
                stopAudioPlayer()
                return
            }
        }
        
        //rguard let url = Bundle.main.url(forResource: "sample", withExtension: "mp3") else {
        //guard let url = Bundle.main.url(forResource: "fanfare", withExtension: "mp3") else {
        //guard let url = Bundle.main.url(forResource: "heroes", withExtension: "mp3") else {
        guard let url = Bundle.main.url(forResource: "super_mario_world_overworld", withExtension: "mp3") else {
        //guard let url = Bundle.main.url(forResource: "super_mario_world_title", withExtension: "mp3") else {
            print("failed to load song.mp3")
            return
        }
        
        setPlayButtonImageStop()
        //setPlayButtonImagePause()
        
        samplerTask?.cancel()
        samplerTask = Task {
            await audioSampler.load(url: url)
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            if let audioPlayer = audioPlayer {
                audioPlayer.delegate = self
                audioPlayer.play()
                audioSampler.notifyPlaying()
            } else {
                audioSampler.notifyStopped()
            }
        } catch let error {
            print("audio player error: \(error.localizedDescription)")
        }
    }
    
    func setPlayButtonImageStop() {
        DispatchQueue.main.async {
            self.playButton.setImage(UIImage(systemName: "stop.fill"), for: .normal)
        }
    }
    
    func setPlayButtonImagePlay() {
        DispatchQueue.main.async {
            self.playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        }
    }
    
    func setPlayButtonImagePause() {
        DispatchQueue.main.async {
            self.playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
    }
    
    func update() {
        if let audioPlayer = audioPlayer {
            if audioPlayer.isPlaying {
                if audioSampler.timeSampler.trackLength > 0.1 {
                    let currentTime = audioPlayer.currentTime
                    audioSampler.time = currentTime
                    
                    var progress = Float(currentTime / audioSampler.timeSampler.trackLength)
                    if progress < 0.0 { progress = 0.0 }
                    if progress > 1.0 { progress = 1.0 }
                    progressView.progress = progress
                } else {
                    audioSampler.time = 0.0
                    progressView.progress = 0.0
                }
            } else {
                audioSampler.time = 0.0
                progressView.progress = 0.0
            }
        } else {
            audioSampler.time = 0.0
            progressView.progress = 0.0
        }
    }
}

extension PlaybackMenuViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("FINISH PLAYING")
        stopAudioPlayer()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("AV ERROR!")
        stopAudioPlayer()
    }
    
    func audioPlayerBeginInterruption(_ player: AVAudioPlayer) {
        print("AV INTERRUPTED, NOW PAUSED")
        stopAudioPlayer()
    }
    
    func audioPlayerEndInterruption(_ player: AVAudioPlayer, withOptions flags: Int) {
        print("AV END INTERRUPTION")
    }
}
