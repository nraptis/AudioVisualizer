//
//  AudioSampler.swift
//  MagnificentSounds
//
//  Created by Tiger Nixon on 5/4/23.
//

import Foundation
import AVFoundation
import Accelerate

class AudioSampler {
    
    let timeSampler = TimeSampler()
    
    private(set) var isPlaying = false
    
    func notifyPlaying() {
        isPlaying = true
    }
    
    var time: TimeInterval = 0.0
    
    func notifyStopped() {
        isPlaying = false
        time = 0.0
    }
    
    func load(url: URL) async {
        
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: NSNumber(booleanLiteral: true)])
        
        let assetTracks: [AVAssetTrack]
        do {
            assetTracks = try await asset.loadTracks(withMediaType: .audio)
        } catch let error {
            print("error loading tracks: \(error.localizedDescription)")
            return
        }
        
        if Task.isCancelled { return }
        
        let assetTrack: AVAssetTrack
        if assetTracks.count > 0 {
            assetTrack = assetTracks[0]
        } else {
            print("loaded empty array of asset tracks.")
            return
        }
        
        let duration: CMTime
        do {
            duration = try await asset.load(.duration)
        } catch let error {
            print("error loading duration: \(error.localizedDescription)")
            return
        }
        
        if Task.isCancelled { return }
        
        let formatDescriptions: [CMAudioFormatDescription]
        do {
            formatDescriptions = try await assetTrack.load(.formatDescriptions)
        } catch let error {
            print("error loading format descriptions: \(error.localizedDescription)")
            return
        }
        
        if Task.isCancelled { return }
        
        let formatDescription: CMAudioFormatDescription
        if formatDescriptions.count > 0 {
            formatDescription = formatDescriptions[0]
        } else {
            print("loaded empty array of format descriptions.")
            return
        }
        
        guard let streamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            print("unable to derive stream basic description")
            return
        }
        
        let seconds = Float64(duration.value) / Float64(duration.timescale)
        let sampleCount = Int((streamBasicDescription.pointee.mSampleRate) * Float64(duration.value) / Float64(duration.timescale))
        
        //TODO: 60 per second???
        let renderSampleCount = Int(seconds * 60.0)
        timeSampler.setup(sampleCount: renderSampleCount,
                          trackLength: TimeInterval(seconds))
        
        if Task.isCancelled { return }
        
        await proceedToProcess(sampleCount: sampleCount,
                               renderSampleCount: renderSampleCount,
                               asset: asset,
                               assetTrack: assetTrack,
                               duration: duration,
                               formatDescriptions: formatDescriptions)
    }
    
    func proceedToProcess(sampleCount: Int,
                          renderSampleCount: Int,
                          asset: AVAsset,
                          assetTrack: AVAssetTrack,
                          duration: CMTime,
                          formatDescriptions: [CMAudioFormatDescription]
    ) async {
        
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch let error {
            print("error creating asset reader: \(error.localizedDescription)")
            return
        }
        
        reader.timeRange = CMTimeRange(start: CMTime(value: CMTimeValue(0), timescale: duration.timescale),
                                       duration: duration)
        
        let outputSettingsDict: [String : Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        
        let readerOutput = AVAssetReaderTrackOutput(track: assetTrack,
                                                    outputSettings: outputSettingsDict)
        readerOutput.alwaysCopiesSampleData = false
        reader.add(readerOutput)
        
        var channelCount = 1
        for formatDescription in formatDescriptions {
            guard let streamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
                print("unable to derive stream basic description")
                return
            }
            channelCount = Int(streamBasicDescription.pointee.mChannelsPerFrame)
        }
        
        let samplesPerPixel = max(1, channelCount * sampleCount / renderSampleCount)
        let filter = [Float](repeating: 1.0 / Float(samplesPerPixel),
                             count: samplesPerPixel)
        
        var sampleBuffer = Data()
        
        if Task.isCancelled {
            return
        }
        
        reader.startReading()
        
        var insertIndex = 0
        while reader.status == .reading {
            
            if Task.isCancelled {
                reader.cancelReading()
                return
            }
            
            guard let readSampleBuffer = readerOutput.copyNextSampleBuffer() else {
                break
            }
            guard let readBuffer = CMSampleBufferGetDataBuffer(readSampleBuffer) else {
                    break
            }
            
            var readBufferLength = 0
            var readBufferPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(readBuffer,
                                        atOffset: 0,
                                        lengthAtOffsetOut: &readBufferLength,
                                        totalLengthOut: nil,
                                        dataPointerOut: &readBufferPointer)
            sampleBuffer.append(UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))
            CMSampleBufferInvalidate(readSampleBuffer)
            
            let totalSamples = sampleBuffer.count / MemoryLayout<Int16>.size
            let downSampledLength = totalSamples / samplesPerPixel
            let samplesToProcess = downSampledLength * samplesPerPixel
            guard samplesToProcess > 0 else { continue }
            let samples = process(sampleBuffer: &sampleBuffer,
                                samplesToProcess: samplesToProcess,
                                downSampledLength: downSampledLength,
                                samplesPerPixel: samplesPerPixel,
                                filter: filter)
            
            timeSampler.insert(samples: samples, at: insertIndex)
            insertIndex += samples.count
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
            } catch let error {
                print("task sleep error: \(error.localizedDescription)")
            }
        }
        
        let samplesToProcess = sampleBuffer.count / MemoryLayout<Int16>.size
        if samplesToProcess > 0 {
            let downSampledLength = 1
            let samplesPerPixel = samplesToProcess
            let filter = [Float](repeating: 1.0 / Float(samplesPerPixel), count: samplesPerPixel)
            let samples = process(sampleBuffer: &sampleBuffer,
                                samplesToProcess: samplesToProcess,
                                downSampledLength: downSampledLength,
                                samplesPerPixel: samplesPerPixel,
                                filter: filter)
            timeSampler.insert(samples: samples, at: insertIndex)
            insertIndex += samples.count
        }
        reader.cancelReading()
    }
    
    private func process(sampleBuffer: inout Data,
                        samplesToProcess: Int,
                        downSampledLength: Int,
                        samplesPerPixel: Int,
                        filter: [Float]) -> [Float] {
        var result = [Float](repeating: 0.0,
                             count: downSampledLength)
        sampleBuffer.withUnsafeBytes { (samples: UnsafeRawBufferPointer) in
            var processingBuffer = [Float](repeating: 0.0, count: samplesToProcess)
            let sampleCount = vDSP_Length(samplesToProcess)
            let unsafeBufferPointer = samples.bindMemory(to: Int16.self)
            let unsafePointer = unsafeBufferPointer.baseAddress!
            vDSP_vflt16(unsafePointer, 1, &processingBuffer, 1, sampleCount)
            
            
            vDSP_vabs(processingBuffer, 1, &processingBuffer, 1, sampleCount)
            
            var noiseFloor: Float = -80.0
            var zero: Float = 32768.0
            var ceil: Float = 0.0
            vDSP_vdbcon(processingBuffer, 1, &zero, &processingBuffer, 1, vDSP_Length(processingBuffer.count), 1)
            vDSP_vclip(processingBuffer, 1, &noiseFloor, &ceil, &processingBuffer, 1, vDSP_Length(processingBuffer.count))
            
            
            //toDecibels(normalizedSamples: &processingBuffer)
            
            vDSP_desamp(processingBuffer,
                        vDSP_Stride(samplesPerPixel),
                        filter, &result,
                        vDSP_Length(downSampledLength),
                        vDSP_Length(samplesPerPixel))
            sampleBuffer.removeFirst(samplesToProcess * MemoryLayout<Int16>.size)
        }
        return result
    }
    
    func toDecibels(normalizedSamples: inout [Float]) {
        var noiseFloor: Float = -80.0
        var zero: Float = 32768.0
        var ceil: Float = 0.0
        vDSP_vdbcon(normalizedSamples, 1, &zero, &normalizedSamples, 1, vDSP_Length(normalizedSamples.count), 1)
        vDSP_vclip(normalizedSamples, 1, &noiseFloor, &ceil, &normalizedSamples, 1, vDSP_Length(normalizedSamples.count))
    }
}
