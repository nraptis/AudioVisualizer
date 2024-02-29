//
//  AudioWave.swift
//  MagnificentSounds
//
//  Created by Tiger Nixon on 5/5/23.
//

import Foundation
import Metal
import simd

class AudioWaveNode {
    var x: Float
    var magnitude: Float
    init() {
        x = 0.0
        magnitude = 0.0
    }
    init(x: Float, magnitude: Float) {
        self.x = x
        self.magnitude = magnitude
    }
}

class AudioWave {
    
    struct DrawNode {
        let x: Float
        let y: Float
        let r: Float
        let g: Float
        let b: Float
        let a: Float
    }
    
    let graphics: Graphics
    required init(graphics: Graphics) {
        self.graphics = graphics
    }
    
    var nodes = [AudioWaveNode]()
    var nodeCount = 0
    
    var listX = [Float]()
    var listY = [Float]()
    
    var normX = [Float]()
    var normY = [Float]()
    
    var spline = CubicSpline()
    
    var thickness: Float = 5.0
    
    var drawNodes = [DrawNode]()
    var drawIndices = [Int16]()
    
    var drawNodesBuffer: MTLBuffer?
    var drawIndicesBuffer: MTLBuffer?
    
    lazy var uniformsShapeNodeIndexedVertex: UniformsShapeNodeIndexedVertex = {
        var result = UniformsShapeNodeIndexedVertex()
        result.projectionMatrix.ortho(width: graphics.width, height: graphics.height)
        result.modelViewMatrix = matrix_identity_float4x4
        return result
    }()
    
    lazy var uniformsShapeNodeIndexedVertexBuffer: MTLBuffer = {
        graphics.buffer(uniform: uniformsShapeNodeIndexedVertex)
    }()
    
    lazy var uniformsShapeNodeIndexedFragment: UniformsShapeNodeIndexedFragment = {
        var result = UniformsShapeNodeIndexedFragment()
        result.set(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        return result
    }()
    
    lazy var uniformsShapeNodeIndexedFragmentBuffer: MTLBuffer = {
        graphics.buffer(uniform: uniformsShapeNodeIndexedFragment)
    }()
    
    
    //var uniformsShapeNodeIndexedVertex = UniformsShapeNodeIndexedVertex()
    //var uniformsShapeNodeIndexedVertexBuffer = UniformsShapeNodeIndexedVertex()
    
    
    func set(nodes: [AudioWaveNode], count: Int) {
        
        var count = count
        if count > nodes.count { count = nodes.count }
        
        self.nodeCount = count
        while self.nodes.count < count {
            self.nodes.append(AudioWaveNode())
        }
        
        for index in 0..<count {
            self.nodes[index].x = nodes[index].x
            self.nodes[index].magnitude = nodes[index].magnitude
        }
        
    }
    
    func draw(renderEncoder: MTLRenderCommandEncoder) {
        
        generate(graphics: graphics)
        
        guard let drawNodesBuffer = drawNodesBuffer else { return }
        guard let drawIndicesBuffer = drawIndicesBuffer else { return }
        
        graphics.set(pipelineState: .shapeNodeColoredIndexed2DAlphaBlending, renderEncoder: renderEncoder)
        
        graphics.setVertexUniformsBuffer(uniformsShapeNodeIndexedVertexBuffer, renderEncoder: renderEncoder)
        graphics.setFragmentUniformsBuffer(uniformsShapeNodeIndexedFragmentBuffer, renderEncoder: renderEncoder)
        
        graphics.setVertexDataBuffer(drawNodesBuffer, renderEncoder: renderEncoder)
        
        
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: drawIndices.count,
                                            indexType: .uint16,
                                            indexBuffer: drawIndicesBuffer,
                                            indexBufferOffset: 0)
        
        
        /*
        for index in 0..<count {
                    let percent = Float(index) / Float(count - 1)
                    let angle = percent * Float.pi * 2.0
                    
                    let dir = Math.vector2D(radians: angle)
                    
                    vertices.append(simd_float2(centerX + dir.x * radiusInner, centerY + dir.y * radiusInner))
                    vertices.append(simd_float2(centerX + dir.x * radiusOuter, centerY + dir.y * radiusOuter))
                }
                
                var back1: Int16 = 0
                var back2: Int16 = 1
                
                for i in 1..<count {
                    
                    let cur1: Int16 = Int16(i * 2)
                    let cur2: Int16 = cur1 + 1
                    
                    
                    
                    back1 = cur1
                    back2 = cur2
                }
                
                let dataBuffer = graphics.buffer(array: vertices)
                
                guard let indexBuffer = graphics.buffer(array: indices) else {
                    return
                }
                
                graphics.setVertexUniformsBuffer(uniformsVertexBuffer, renderEncoder: renderEncoder)
                graphics.setFragmentUniformsBuffer(uniformsFragmentBuffer, renderEncoder: renderEncoder)
                
                graphics.setVertexDataBuffer(dataBuffer, renderEncoder: renderEncoder)
                
                renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                    indexCount: indices.count,
                                                    indexType: .uint16,
                                                    indexBuffer: indexBuffer,
                                                    indexBufferOffset: 0)
        */
    }
    
    func drawMarkers(renderEncoder: MTLRenderCommandEncoder, recyclerShapeQuad2D: RecyclerShapeQuad2D) {
        
        generate(graphics: graphics)
        
        let centerY = Float(Int(graphics.height * 0.5 + 0.5))
        
        var matrixProjection = simd_float4x4()
        matrixProjection.ortho(width: graphics.width, height: graphics.height)
        
        let matrixModelView = matrix_identity_float4x4
        
        recyclerShapeQuad2D.set(red: 1.0, green: 1.0, blue: 1.0)
        
        for index in 0..<nodeCount {
            let node = nodes[index]
            
            let x = node.x
            let y: Float
            let height: Float
            if node.magnitude < 0.0 {
                y = centerY + node.magnitude
                height = -node.magnitude
            } else {
                y = centerY
                height = node.magnitude
            }
            
            //+ node.magnitude
            if node.magnitude < 0 {
                
            }
            
            recyclerShapeQuad2D.drawRect(graphics: graphics,
                                         renderEncoder: renderEncoder,
                                         projection: matrixProjection,
                                         modelView: matrixModelView,
                                         origin: simd_float2(x, y), size: simd_float2(40.0, height))
            
        }
        
        
        
        
        
        
        for index in 0..<listX.count {
            let x = listX[index]
            let y = listY[index]
            
            let percent1 = Float(index) / Float(listX.count - 1)
            var percent2 = percent1 + 0.5
            if percent2 > 1.0 { percent2 -= 1.0 }
            
            recyclerShapeQuad2D.set(red: percent1, green: percent2, blue: (1.0 + sinf(percent2 * Float.pi * 2.0)) / 2.0)
            recyclerShapeQuad2D.drawRect(graphics: graphics,
                                         renderEncoder: renderEncoder,
                                         projection: matrixProjection,
                                         modelView: matrixModelView,
                                         origin: simd_float2(x - 2.0, y - 2.0), size: simd_float2(3.0, 3.0))
            
        }
        
        
        for index in 0..<listX.count {
            let x = listX[index]
            let y = listY[index]
            
            let nx = normX[index]
            let ny = normY[index]
            
            recyclerShapeQuad2D.drawLine(graphics: graphics,
                                         renderEncoder: renderEncoder,
                                         projection: matrixProjection,
                                         modelView: matrixModelView,
                                         p1: simd_float2(x, y), p2: simd_float2(x + nx * 10.0, y + ny * 10.0))
            
        }
        
        
        /*
        while pos <= spline.maxPos {
            
            let percent = pos / spline.maxPos
            
            let point = spline.get(pos)
            let x = point.x
            let y = point.y
            
            recyclerShapeQuad2D.set(red: percent, green: 1.0 - percent, blue: sinf(percent * Float.pi))
            recyclerShapeQuad2D.drawRect(graphics: graphics,
                                         renderEncoder: renderEncoder,
                                         projection: matrixProjection,
                                         modelView: matrixModelView,
                                         origin: simd_float2(x, y), size: simd_float2(4.0, 4.0))
            
            pos += 0.025
        }
        */
        
    }
    
    func generate(graphics: Graphics) {
        
        let centerY = Float(Int(graphics.height * 0.5 + 0.5))
        
        spline.reset()
        
        listX.removeAll(keepingCapacity: true)
        listY.removeAll(keepingCapacity: true)
        
        for index in 0..<nodeCount {
            let x = nodes[index].x
            let y = centerY + nodes[index].magnitude
            spline.add(x, y: y)
        }
        
        spline.compute()
        
        let largeStep: Float = 0.005
        let smallStep: Float = 0.0002
        
        var pos: Float = 0.0
        
        let point = spline.get(0)
        listX.append(point.x)
        listY.append(point.y)
        
        let distThreshold: Float = 5.0 * 5.0
        
        var lastX = listX[0]
        var lastY = listY[0]
        
        var bigLoops = 0
        var smallLoops = 0
        while true {
            
            var lastPos = pos
            var checkPos = pos + largeStep
            var checkPoint = spline.get(checkPos)
            var checkX = checkPoint.x
            var checkY = checkPoint.y
            
            var diffX = checkX - lastX
            var diffY = checkY - lastY
            var distSquared = diffX * diffX + diffY * diffY
            
            //print("big loop lastPos: \(lastPos) checkPos: \(checkPos)")
            while distSquared < distThreshold && checkPos <= spline.maxPos {
                
                bigLoops += 1
                
                lastPos = checkPos
                checkPos += largeStep
                checkPoint = spline.get(checkPos)
                
                checkX = checkPoint.x
                checkY = checkPoint.y
                
                
                diffX = checkX - lastX
                diffY = checkY - lastY
                distSquared = diffX * diffX + diffY * diffY
            }
            
            checkPos = lastPos + smallStep
            checkPoint = spline.get(checkPos)
            checkX = checkPoint.x
            checkY = checkPoint.y
            
            diffX = checkX - lastX
            diffY = checkY - lastY
            distSquared = diffX * diffX + diffY * diffY
            
            while distSquared < distThreshold && checkPos <= spline.maxPos {
                
                smallLoops += 1
                
                lastPos = checkPos
                checkPos += smallStep
                checkPoint = spline.get(checkPos)
                checkX = checkPoint.x
                checkY = checkPoint.y
                diffX = checkX - lastX
                diffY = checkY - lastY
                distSquared = diffX * diffX + diffY * diffY
            }
            
            if checkPos > spline.maxPos { break }
            
            listX.append(checkX)
            listY.append(checkY)
            
            lastX = checkX
            lastY = checkY
            
            pos = checkPos
        }
        
        normX.removeAll(keepingCapacity: true)
        normY.removeAll(keepingCapacity: true)
        
        var index = 0
        
        if listX.count > 0 {
            
            if listX.count == 1 {
                normX.append(0)
                normY.append(-1.0)
            } else {
                
                var startX0 = listX[0]
                var startY0 = listY[0]
                
                var startX1 = listX[1]
                var startY1 = listY[1]
                
                var diffX = startX1 - startX0
                var diffY = startY1 - startY0
                
                var dist = diffX * diffX + diffY * diffY
                if dist > Math.epsilon {
                    dist = sqrtf(dist)
                    diffX /= dist
                    diffY /= dist
                } else {
                    diffX = 0.0
                    diffY = -1.0
                }
                
                normX.append(-diffY)
                normY.append(diffX)
                
                index = 1
                let cap = listX.count - 1
                
                while index < cap {
                    
                    let x1 = listX[index - 1]
                    let y1 = listY[index - 1]
                    
                    let x2 = listX[index]
                    let y2 = listY[index]
                    
                    let x3 = listX[index + 1]
                    let y3 = listY[index + 1]
                    
                    diffX = x2 - x1
                    diffY = y2 - y1
                    dist = diffX * diffX + diffY * diffY
                    if dist > Math.epsilon {
                        dist = sqrtf(dist)
                        diffX /= dist
                        diffY /= dist
                    } else {
                        diffX = 0.0
                        diffY = -1.0
                    }
                    
                    let dirX1 = -diffY
                    let dirY1 = diffX
                    
                    diffX = x3 - x2
                    diffY = y3 - y2
                    dist = diffX * diffX + diffY * diffY
                    if dist > Math.epsilon {
                        dist = sqrtf(dist)
                        diffX /= dist
                        diffY /= dist
                    } else {
                        diffX = 0.0
                        diffY = -1.0
                    }
                    
                    let dirX2 = -diffY
                    let dirY2 = diffX
                    
                    var lerpX = dirX1 + dirX2
                    var lerpY = dirY1 + dirY2
                    
                    var lerpLength = lerpX * lerpX + lerpY * lerpY
                    if lerpLength > Math.epsilon {
                        lerpLength = sqrtf(lerpLength)
                        lerpX /= lerpLength
                        lerpY /= lerpLength
                        
                    } else {
                        lerpX = dirX1
                        lerpY = dirY1
                    }
                    
                    normX.append(lerpX)
                    normY.append(lerpY)
                    
                    index += 1
                }
                
                startX0 = listX[listX.count - 2]
                startY0 = listY[listY.count - 2]
                
                startX1 = listX[listX.count - 1]
                startY1 = listY[listY.count - 1]
                
                diffX = startX1 - startX0
                diffY = startY1 - startY0
                
                dist = diffX * diffX + diffY * diffY
                if dist > Math.epsilon {
                    dist = sqrtf(dist)
                    diffX /= dist
                    diffY /= dist
                } else {
                    diffX = 0.0
                    diffY = -1.0
                }
                
                normX.append(-diffY)
                normY.append(diffX)
            }
        }
        
        
        drawNodes.removeAll(keepingCapacity: true)
        drawIndices.removeAll(keepingCapacity: true)
        
        //var  = [DrawNode]()
        //var indices = [Int16]()
        
        index = 0
        while index < listX.count {
            
            let percent = Float(index) / Float(listX.count - 1)
            
            let x = listX[index]
            let y = listY[index]
            
            let nx = normX[index]
            let ny = normY[index]
            
            let x1 = x + nx * thickness
            let y1 = y + ny * thickness
            
            let x2 = x - nx * thickness
            let y2 = y - ny * thickness
            
            let node1 = DrawNode(x: x1, y: y1, r: percent, g: 0.5, b: 1.0, a: 0.75)
            let node2 = DrawNode(x: x2, y: y2, r: 1.0, g: 1.0, b: 1.0 - percent, a: 0.75)
            
            drawNodes.append(node1)
            drawNodes.append(node2)
            
            index += 1
        }
        
        // 0    1
        // 2    3
        // 4    5
        
        // index * 2     index * 2 + 1
        
        index = 1
        while index < listX.count {
            
            let indexBackTop: Int16 = (Int16(index) - 1) * 2
            let indexBackBottom: Int16 = (Int16(index) - 1) * 2 + 1
            
            let indexTop: Int16 = (Int16(index)) * 2
            let indexBottom: Int16 = (Int16(index)) * 2 + 1
            
            
            drawIndices.append(indexTop)
            drawIndices.append(indexBackTop)
            drawIndices.append(indexBackBottom)
            
            
            drawIndices.append(indexTop)
            drawIndices.append(indexBackBottom)
            drawIndices.append(indexBottom)
            
            
            /*
            // triangle 1
            indices.append(back1)
            indices.append(cur1)
            indices.append(back2)
            
            // triangle 2
            indices.append(back2)
            indices.append(cur2)
            indices.append(cur1)
            */
            
            index += 1
        }
        
        
        let drawNodesLength = MemoryLayout<DrawNode>.size * drawNodes.count
        if let drawNodesBuffer = drawNodesBuffer {
            if drawNodesBuffer.length < drawNodesLength {
                self.drawNodesBuffer = graphics.device.makeBuffer(length: drawNodesLength + (drawNodesLength >> 1) + 1)
            }
            
            //TODO: ???
            if Int.random(in: 0...10) == 4 {
                self.drawNodesBuffer = graphics.device.makeBuffer(length: drawNodesLength + (drawNodesLength >> 1) + 1)
            }
        } else {
            self.drawNodesBuffer = graphics.device.makeBuffer(length: drawNodesLength + (drawNodesLength >> 1) + 1)
        }
        
        if let drawNodesBuffer = drawNodesBuffer {
            graphics.write(buffer: drawNodesBuffer, array: drawNodes)
        }
        
        let drawIndicesLength = MemoryLayout<Int16>.size * drawIndices.count
        if let drawIndicesBuffer = drawIndicesBuffer {
            if drawIndicesBuffer.length < drawIndicesLength {
                self.drawIndicesBuffer = graphics.device.makeBuffer(length: drawIndicesLength + (drawIndicesLength >> 1) + 1)
            }
            
            //TODO: ???
            if Int.random(in: 0...10) == 4 {
                self.drawIndicesBuffer = graphics.device.makeBuffer(length: drawIndicesLength + (drawIndicesLength >> 1) + 1)
            }
        } else {
            self.drawIndicesBuffer = graphics.device.makeBuffer(length: drawIndicesLength + (drawIndicesLength >> 1) + 1)
        }
        
        if let drawIndicesBuffer = drawIndicesBuffer {
            graphics.write(buffer: drawIndicesBuffer, array: drawIndices)
        }
        
        //var drawNodes = [DrawNode]()
        //var drawIndices = [Int16]()
        
        //var drawNodesBuffer: MTLBuffer?
        //var drawIndicesBuffer: MTLBuffer?
        
        
        //var nodes = [Node]()
        //var indices = [Int16]()
        
        
        /*
        lastX = listX[0]
        lastY = listY[0]
        
        var index = 1
        while index < listX.count {
            
            let x = listX[index]
            let y = listY[index]
            
            var diffX = x - lastX
            var diffY = y - lastY
            
            var dist = diffX * diffX + diffY * diffY
            if dist > Math.epsilon {
                dist = sqrtf(dist)
                diffX /= dist
                diffY /= dist
            } else {
                diffX = 0.0
                diffY = -1.0
            }
            
            normBaseX.append(-diffY)
            normBaseY.append(diffX)
            
            lastX = x
            lastY = y
            index += 1
        }
        
        if normBaseX.count > 0 {
            normBaseX.append(normBaseX[normBaseX.count - 1])
            normBaseY.append(normBaseY[normBaseY.count - 1])
        }
        
        
        normX.removeAll(keepingCapacity: true)
        normY.removeAll(keepingCapacity: true)
        
        if normBaseX.count > 1 {
            normX.append(normBaseX[0])
            normY.append(normBaseY[0])
            
            index = 1
            var cap = normBaseX.count - 1
            
            while index < cap {
                
                var prevBaseX = normBaseX[index - 1]
                var prevBaseY = normBaseY[index - 1]
                
                var nextBaseX = normBaseX[index - 1]
                var nextBaseY = normBaseY[index - 1]
                
                
                
                
                
                index += 1
            }
            
            normX.append(normBaseX[normBaseX.count - 1])
            normY.append(normBaseY[normBaseY.count - 1])
            
        }
        
        */
        
        
        /*
        
        
        var dists = [Float]()
        for i in 1..<listX.count {
            
            let x = listX[i]
            let y = listY[i]
            
            let diffX = x - lastX
            let diffY = y - lastY
            
            let dist = sqrtf(diffX * diffX + diffY * diffY)
            
            dists.append(dist)
            
            
            lastX = x
            lastY = y
            
        }
        
        print("dists: \(dists)")
        print("min dist: \(dists.min()!)")
        print("max dist: \(dists.max()!)")
        print("big hop: \(bigLoops)")
        print("little hop: \(smallLoops)")
        */
    }
    
}
