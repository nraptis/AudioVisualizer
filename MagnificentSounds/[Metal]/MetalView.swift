//
//  GameView.swift
//  RebuildEarth
//
//  Created by Nicky Taylor on 2/9/23.
//

import UIKit

class MetalView: UIView {
    
    let delegate: GraphicsDelegate
    let graphics: Graphics
    
    private var timer: CADisplayLink?
    
    required init(delegate: GraphicsDelegate,
                  graphics: Graphics,
                  width: CGFloat,
                  height: CGFloat) {
        self.delegate = delegate
        self.graphics = graphics
        super.init(frame: CGRect(x: 0.0, y: 0.0, width: width, height: height))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var engine: MetalEngine = {
        MetalEngine(delegate: delegate, graphics: graphics, layer: layer as! CAMetalLayer)
    }()
    
    lazy var pipeline: MetalPipeline = {
        MetalPipeline(engine: engine)
    }()
    
    override class var layerClass: AnyClass {
        return CAMetalLayer.self
    }
    
    func load() {
        
        delegate.initialize(graphics: graphics)
        
        engine.load()
        pipeline.load()
        
        delegate.load()
        
        timer?.invalidate()
        timer = CADisplayLink(target: self, selector: #selector(render))
        if let timer = timer {
            timer.add(to: RunLoop.main, forMode: .default)
        }
    }
    
    @objc func render() {
        delegate.update()
        engine.draw()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            delegate.touchBegan(touch: touch,
                                x: Float(location.x),
                                y: Float(location.y))
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            delegate.touchMoved(touch: touch,
                                x: Float(location.x),
                                y: Float(location.y))
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            delegate.touchEnded(touch: touch,
                                x: Float(location.x),
                                y: Float(location.y))
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            delegate.touchEnded(touch: touch,
                                x: Float(location.x),
                                y: Float(location.y))
        }
    }
    
}
