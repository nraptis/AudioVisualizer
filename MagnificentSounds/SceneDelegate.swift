//
//  SceneDelegate.swift
//  MagnificentSounds
//
//  Created by Tiger Nixon on 5/4/23.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    lazy var audioSampler: AudioSampler = {
        AudioSampler()
    }()
    
    lazy var playbackMenuViewController: PlaybackMenuViewController = {
        PlaybackMenuViewController(audioSampler: audioSampler)
    }()
    
    lazy var audioWaveScene: AudioWaveScene = {
        AudioWaveScene(playbackMenuViewController: playbackMenuViewController,
                       audioSampler: audioSampler,
                       timeSampler: audioSampler.timeSampler)
    }()
    

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        
        guard let window = window else { return }
        
        let graphics = Graphics(delegate: audioWaveScene,
                                width: Float(UIScreen.main.bounds.width),
                                height: Float(UIScreen.main.bounds.height))
        window.rootViewController = graphics.metalViewController
        graphics.metalViewController.load()
        window.makeKeyAndVisible()
        
        if let playbackMenuView = playbackMenuViewController.view {
            playbackMenuView.translatesAutoresizingMaskIntoConstraints = false
            window.addSubview(playbackMenuViewController.view)
            NSLayoutConstraint.activate([
                playbackMenuView.leftAnchor.constraint(equalTo: window.leftAnchor),
                playbackMenuView.rightAnchor.constraint(equalTo: window.rightAnchor),
                playbackMenuView.topAnchor.constraint(equalTo: window.topAnchor),
                NSLayoutConstraint(item: playbackMenuView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 44.0 + 16.0 + 16.0 + window.safeAreaInsets.top)
                
            ])
        }
    }
    
}

