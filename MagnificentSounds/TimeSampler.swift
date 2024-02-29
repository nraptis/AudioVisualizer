//
//  TimeSampler.swift
//  MagnificentSounds
//
//  Created by Tiger Nixon on 5/4/23.
//

import Foundation

class TimeSampler {
    
    private static let percentScale: Float = 100_000.0
    
    var sampleCount = 0
    var trackLength: TimeInterval = 0.0
    private var samples = [Float]()
    private var percents = [Float]()
    
    func setup(sampleCount: Int, trackLength: TimeInterval) {
        self.sampleCount = max(sampleCount, 2)
        self.trackLength = trackLength
        if self.sampleCount > samples.count {
            let additionalSamples = [Float](repeating: -80.0, count: self.sampleCount - samples.count)
            samples.append(contentsOf: additionalSamples)
            percents.append(contentsOf: additionalSamples)
        }
        
        for index in 0..<self.sampleCount {
            let percent = Float(index) / Float(self.sampleCount - 1)
            percents[index] = percent * Self.percentScale
        }
    }
    
    func insert(samples: [Float], at index: Int) {
        for i in 0..<samples.count {
            let sample = samples[i]
            insert(sample: sample, at: index + i)
        }
        print("added samples [\(index)] \(samples)")
    }
    
    func insert(sample: Float, at index: Int) {
        
        if index >= 0 && index < samples.count {
            samples[index] = sample
        }
    }
    
    private func find(percent: Float) -> Int {
        
        if sampleCount <= 1 { return 0 }
        
        if percent <= percents[0] {
            return 0
        }
        if percent >= percents[sampleCount - 1] {
            return sampleCount - 1
        }
        
        var start = 0
        var end = sampleCount - 1
        var result = 0
        while start <= end {
            let mid = (start + end) >> 1
            if percent > percents[mid] {
                start = mid + 1
                result = start
            } else if percent < percents[mid] {
                end = mid - 1
                result = end
            } else {
                result = mid
                break
            }
        }
        return result
    }
    
    func sample(time: TimeInterval) -> Float {
        
        if trackLength >= 0.05 && sampleCount >= 2 {
            
            let percent = Float(time / trackLength) * Self.percentScale
            
            let index1 = find(percent: percent)
            if index1 >= (sampleCount - 1) {
                return samples[sampleCount - 1]
            } else {
                let index2 = index1 + 1
                let percent1 = percents[index1]
                let percent2 = percents[index2]
                
                if percent <= percent1 {
                    return samples[index1]
                } else if percent >= percent2 {
                    return samples[index2]
                } else {
                    let diff = percents[index2] - percents[index1]
                    if diff <= 0.001 {
                        return samples[index1]
                    }
                    
                    let numer = percent - percents[index1]
                    var factor = numer / diff
                    if factor < 0.0 {
                        factor = 0.0
                    }
                    if factor > 1.0 {
                        factor = 1.0
                    }
                    return samples[index1] + (samples[index2] - samples[index1]) * factor
                }
            }
        }
        return -80.0
    }
    
}
