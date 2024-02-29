//
//  AudioWaveScene.swift
//  MagnificentSounds
//
//  Created by Tiger Nixon on 5/4/23.
//

import Foundation
import Metal
import UIKit
import simd

class AudioWaveScene: GraphicsDelegate {
    unowned var graphics: Graphics!
    
    weak var playbackMenuViewController: PlaybackMenuViewController!
    weak var audioSampler: AudioSampler!
    weak var timeSampler: TimeSampler!
    
    let recyclerShapeQuad2D = RecyclerShapeQuad2D()
    
    lazy var testWave: AudioWave = {
        AudioWave(graphics: graphics)
    }()
    
    lazy var waveBuilderMain: AudioWaveBuilder = {
        AudioWaveBuilder(graphics: graphics, count: 6)
    }()
    
    init(playbackMenuViewController: PlaybackMenuViewController, audioSampler: AudioSampler, timeSampler: TimeSampler) {
        self.playbackMenuViewController = playbackMenuViewController
        self.audioSampler = audioSampler
        self.timeSampler = timeSampler
    }
    
    var samples = [Float](repeating: -80.0, count: 32)
    
    func load() {
        
        
    }
    
    func update() {
        playbackMenuViewController.update()
        
        var sample: Float = -80.0
        if audioSampler.isPlaying {
            let time = audioSampler.time
            let duration = Float(timeSampler.trackLength)
            if duration > Math.epsilon {
                sample = timeSampler.sample(time: time)
            }
        } else {
            
        }
        
        for i in 1..<samples.count {
            samples[i - 1] = samples[i]
        }
        samples[samples.count - 1] = sample
        
        
        var percent = (80.0 + sample) / 80.0
        if percent < 0.0 { percent = 0.0 }
        if percent > 1.0 { percent = 1.0 }
        
        //percent = 1.0 - (1.0 - percent * percent)
        
        
        waveBuilderMain.update(decibels: sample, percent: percent)
        
        var magz = [AudioWaveNode]()
        
        var barWIdtt = graphics.width * 0.85
        
        var sliceWidth = barWIdtt / 5.0
        var barX = graphics.width / 2.0 - barWIdtt / 2.0
        var magFLopper = false
        
        magz.append(AudioWaveNode(x: barX + sliceWidth * 0.0, magnitude: graphics.height * 0.125))
        magz.append(AudioWaveNode(x: barX + sliceWidth * 1.0, magnitude: -graphics.height * 0.135))
        magz.append(AudioWaveNode(x: barX + sliceWidth * 2.0, magnitude: graphics.height * 0.125))
        magz.append(AudioWaveNode(x: barX + sliceWidth * 3.0, magnitude: -graphics.height * 0.115))
        magz.append(AudioWaveNode(x: barX + sliceWidth * 4.0, magnitude: graphics.height * 0.135))
        magz.append(AudioWaveNode(x: barX + sliceWidth * 5.0, magnitude: -graphics.height * 0.145))
        //magz.append(AudioWaveNode(x: barX + sliceWidth * 6.0, magnitude: graphics.height * 0.175))
        //magz.append(AudioWaveNode(x: barX + sliceWidth * 7.0, magnitude: -graphics.height * 0.125))
        
        testWave.set(nodes: magz, count: 6)
        
        
        
        
        
        //testWave
        
        
    }
    
    func draw(renderEncoder: MTLRenderCommandEncoder) {
        
        var matrixProjection = simd_float4x4()
        matrixProjection.ortho(width: graphics.width, height: graphics.height)
        
        var matrixModelView = matrix_identity_float4x4
        
        recyclerShapeQuad2D.reset()
        
        var width = roundf((graphics.width - 60.0) / Float(samples.count))
        var totalWidth = width * Float(samples.count)
        var x = roundf(graphics.width * 0.5 - totalWidth * 0.5)
        
        graphics.set(pipelineState: .shape2DNoBlending, renderEncoder: renderEncoder)
        
        for i in 0..<samples.count {
            
            let sample = samples[i]
            var percent = (80.0 + sample) / 80.0
            if percent < 0.0 { percent = 0.0 }
            if percent > 1.0 { percent = 1.0 }
            
            percent = 1.0 - (1.0 - percent * percent)
            
            //__exp10f(sample / 20.0)
            //print("per = \(percent)")
            
            var centerY = graphics.height * 0.5
            
            var height = graphics.height * 0.5 * percent
            
            var y = centerY - (height * 0.5)
            
            
            recyclerShapeQuad2D.set(red: Float.random(in: 0.0...1.0), green: Float.random(in: 0.0...1.0), blue: Float.random(in: 0.0...1.0))
            recyclerShapeQuad2D.drawRect(graphics: graphics,
                                         renderEncoder: renderEncoder,
                                         projection: matrixProjection,
                                         modelView: matrixModelView,
                                         origin: simd_float2(x, y),
                                         size: simd_float2(width, height))
            
            
            x += width
        }
            
        //testWave.drawMarkers(renderEncoder: renderEncoder, recyclerShapeQuad2D: recyclerShapeQuad2D)
        
        //testWave.draw(renderEncoder: renderEncoder)
        
        
        waveBuilderMain.draw(renderEncoder: renderEncoder)
        
    }
    
    func touchBegan(touch: UITouch, x: Float, y: Float) {
        
    }
    
    func touchMoved(touch: UITouch, x: Float, y: Float) {
        
    }
    
    func touchEnded(touch: UITouch, x: Float, y: Float) {
        
    }
}

