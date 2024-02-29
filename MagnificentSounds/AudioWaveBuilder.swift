//
//  AudioWaveBuilder.swift
//  MagnificentSounds
//
//  Created by Tiger Nixon on 5/5/23.
//

import Foundation
import Metal

class AudioWaveModifier {
    var r1: Float
    var speed1: Float
    
    var r2: Float
    var speed2: Float
    
    var back: Int = 0
    
    var magnitude = [Float](repeating: 0.0, count: 64)
    var percent = [Float](repeating: 0.0, count: 64)
    
    var positive: Bool
    
    init() {
        r1 = 0.0
        speed1 = 0.01
        
        r2 = Float.pi
        speed2 = 0.015
        
        back = 0
        
        positive = false
    }
    
    func register(magnitude: Float) {
        for index in 1..<64 {
            self.magnitude[index - 1] = self.magnitude[index]
        }
        self.magnitude[63] = magnitude
    }
    
    func computeMagnitude() -> Float {
        var result: Float = 0.0
        for index in 0..<64 {
            result += magnitude[index]
        }
        result /= 63.0
        return result
    }
    
    func register(percent: Float) {
        for index in 1..<64 {
            self.percent[index - 1] = self.percent[index]
        }
        self.percent[63] = percent
    }
    
    func computePercent() -> Float {
        var result: Float = 0.0
        for index in 0..<64 {
            result += percent[index]
        }
        result /= 63.0
        return result
    }
}

class AudioWaveBuilder {
    
    let graphics: Graphics
    let count: Int
    
    var nodes: [AudioWaveNode]
    var modifiers: [AudioWaveModifier]
    
    var masterSine: Float = 0.0
    
    var buffer = [Float](repeating: 0.0, count: 256)
    
    lazy var audioWave: AudioWave = {
        let result = AudioWave(graphics: graphics)
        result.set(nodes: nodes, count: count)
        return result
    }()
    
    required init(graphics: Graphics, count: Int) {
        self.graphics = graphics
        self.count = count
        self.nodes = [AudioWaveNode]()
        
        for _ in 0..<count {
            self.nodes.append(AudioWaveNode())
        }
        
        self.modifiers = [AudioWaveModifier]()
        
        for _ in 0..<count {
            self.modifiers.append(AudioWaveModifier())
        }
        
        for index in 0..<count {
            modifiers[index].speed1 = ((index & 1) == 0) ? 0.01 : -0.01
            modifiers[index].speed2 = ((index & 1) == 0) ? -0.015 : 0.015
        }
        
        for index in 0..<count {
            modifiers[count - 1 - index].back = index * 12
            
        }
        
        for index in 0..<count {
            if ((index & 1) == 0) {
                modifiers[index].positive = true
            } else {
                modifiers[index].positive = false
            }
        }
        
        for index in 0..<count {
            let percent = Float(index) / Float(count - 1)
            nodes[index].x = graphics.width * percent
        }
    }
    
    func draw(renderEncoder: MTLRenderCommandEncoder) {
        audioWave.draw(renderEncoder: renderEncoder)
    }
    
    
    func update(decibels: Float, percent: Float) {
        
        let pi2 = Float.pi * 2.0
        
        for index in 1..<256 {
            buffer[index - 1] = buffer[index]
        }
        buffer[255] = percent
        
        masterSine += 0.2
        if masterSine >= pi2 {
            masterSine -= pi2
        }
        
        for index in 0..<count {
            let percent = buffer[255 - modifiers[index].back]
            modifiers[index].register(percent: percent)
        }
        
        //modifiers[count - 1].decibels = decibels
        //modifiers[count - 1].percent = percent
        
        
        for index in 0..<count {
            modifiers[index].r1 += modifiers[index].speed1
            if modifiers[index].r1 < 0 { modifiers[index].r1 += pi2 }
            if modifiers[index].r1 >= pi2 { modifiers[index].r1 -= pi2 }
            
            modifiers[index].r2 += modifiers[index].speed2
            if modifiers[index].r2 < 0 { modifiers[index].r2 += pi2 }
            if modifiers[index].r2 >= pi2 { modifiers[index].r2 -= pi2 }
        }
        
        var maxHeight: Float = graphics.height * 0.25
        if maxHeight > 120.0 { maxHeight = 120.0 }
        
        for index in 0..<count {
            
            var master = sinf(masterSine)
            if ((index & 1) == 0) { master = -master }
            
            let flanger1 = sinf(modifiers[index].r1)
            //if Bool.random() { flanger1 = -flanger1 }
            
            let flanger2 = sinf(modifiers[index].r2)
            //if Bool.random() { flanger2 = -flanger2 }
            
            let comp = master * 0.75 + flanger1 * 0.15 + flanger2 * 0.1
            //var comp = master
            
            let magnitude = comp * percent
            
            modifiers[index].register(magnitude: magnitude)
            
            let computedMagnitude = modifiers[index].computeMagnitude()
            let computedPercent = modifiers[index].computePercent()
            
            
            let percent = buffer[255 - modifiers[index].back]
            
            var height1 = computedPercent * maxHeight * 0.5
            if !modifiers[index].positive {
                height1 = -height1
            }
            
            nodes[index].magnitude = height1 + percent * computedMagnitude * maxHeight * 0.5
            
            //+ computedMagnitude * maxHeight
            //nodes[index].magnitude = modifiers[index].compute() * maxHeight
        }
        
        audioWave.set(nodes: nodes, count: count)
        
    }
    
    
}

