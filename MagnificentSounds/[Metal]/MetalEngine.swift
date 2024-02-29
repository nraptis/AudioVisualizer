//
//  MetalEngine.swift
//  RebuildEarth
//
//  Created by Nicky Taylor on 2/10/23.
//

import Foundation
import UIKit
import Metal

class MetalEngine {
    
    let delegate: GraphicsDelegate
    let graphics: Graphics
    let layer: CAMetalLayer
    
    var scale: CGFloat
    var device: MTLDevice
    var library: MTLLibrary
    var commandQueue: MTLCommandQueue
    
    var samplerStateLinearClamp: MTLSamplerState!
    var samplerStateLinearRepeat: MTLSamplerState!
    
    var depthStateDisabled: MTLDepthStencilState!
    var depthStateLessThan: MTLDepthStencilState!
    var depthStateLessThanEqual: MTLDepthStencilState!
    
    var antialiasingTexture: MTLTexture!
    
    required init(delegate: GraphicsDelegate, graphics: Graphics, layer: CAMetalLayer) {
        self.delegate = delegate
        self.graphics = graphics
        self.layer = layer
        
        scale = UIScreen.main.scale
        device = MTLCreateSystemDefaultDevice()!
        library = device.makeDefaultLibrary()!
        commandQueue = device.makeCommandQueue()!
        
        layer.device = device
        layer.contentsScale = scale
        layer.frame = CGRect(x: 0.0, y: 0.0, width: CGFloat(graphics.width), height: CGFloat(graphics.height))
        
        print("awake layer size \(layer.frame.width) x \(layer.frame.height)")
        print("awake layer scale \(scale)")
        
        
        
    }
    
    func load() {
        let width = Int(CGFloat(graphics.width) * scale + 0.5)
        let height = Int(CGFloat(graphics.height) * scale + 0.5)
        antialiasingTexture = createAntialiasingTexture(width: width, height: height)
        buildSamplerStates()
    }
    
    func draw() {
        
        guard let drawable = layer.nextDrawable() else { return }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = antialiasingTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .multisampleResolve
        renderPassDescriptor.colorAttachments[0].resolveTexture = drawable.texture
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.055, green: 0.125, blue: 0.105, alpha: 1.0)

        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            delegate.draw(renderEncoder: renderEncoder)
            renderEncoder.endEncoding()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    private func buildSamplerStates() {
        let samplerDescriptorLinearClamp = MTLSamplerDescriptor()
        samplerDescriptorLinearClamp.minFilter = .linear
        samplerDescriptorLinearClamp.magFilter = .linear
        samplerDescriptorLinearClamp.sAddressMode = .clampToEdge
        samplerDescriptorLinearClamp.tAddressMode = .clampToEdge
        samplerStateLinearClamp = device.makeSamplerState(descriptor: samplerDescriptorLinearClamp)
        
        let samplerDescriptorLinearRepeat = MTLSamplerDescriptor()
        samplerDescriptorLinearRepeat.minFilter = .linear
        samplerDescriptorLinearRepeat.magFilter = .linear
        samplerDescriptorLinearRepeat.sAddressMode = .repeat
        samplerDescriptorLinearRepeat.tAddressMode = .repeat
        samplerStateLinearRepeat = device.makeSamplerState(descriptor: samplerDescriptorLinearRepeat)
    }
    
    func createAntialiasingTexture(width: Int, height: Int) -> MTLTexture {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.sampleCount = 4
        textureDescriptor.pixelFormat = layer.pixelFormat
        textureDescriptor.width = width
        textureDescriptor.height = height
        textureDescriptor.textureType = .type2DMultisample
        textureDescriptor.usage = .renderTarget
        textureDescriptor.resourceOptions = .storageModePrivate
        return device.makeTexture(descriptor: textureDescriptor)!
    }
}
