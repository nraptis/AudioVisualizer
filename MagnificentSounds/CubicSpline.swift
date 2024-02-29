//
//  CubicSpline.swift
//
//  Created by Nicholas Raptis on 8/22/16.
//

import Foundation
import simd

class CubicSpline {
    
    private struct CubicSplineNode {
        var value: Float = 0.0
        var delta: Float = 0.0
        var derivative: Float = 0.0
        var coefA: Float = 0.0
        var coefB: Float = 0.0
        var coefC: Float = 0.0
    }
    
    init() {
        
    }
    
    private var x = [CubicSplineNode]()
    private var y = [CubicSplineNode]()
    
    var maxPos: Float {
        Float(maxIndex)
    }
    
    var maxIndex: Int {
        x.count <= 1 ? 0 : (_controlPointCount - 1)
    }
    
    var controlPointCount: Int {
        _controlPointCount
    }
    
    func add(_ x:Float, y:Float) {
        set(_controlPointCount, x: x, y: y)
    }
    
    func reset() {
        _controlPointCount = 0
    }
    
    func clear() {
        reset()
        x.removeAll()
        y.removeAll()
    }
    
    func set(_ index:Int, x:Float, y:Float) {
        if index >= controlPointCount { _controlPointCount = index + 1 }
        if index >= self.x.count {
            let newCapacity = _controlPointCount + _controlPointCount / 2 + 1
            self.x.reserveCapacity(newCapacity)
            self.y.reserveCapacity(newCapacity)
            while self.x.count < newCapacity {
                self.x.append(CubicSplineNode())
                self.y.append(CubicSplineNode())
            }
        }
        
        self.x[index].value = x
        self.y[index].value = y
    }
    
    func get(_ pos: Float) -> SIMD2<Float> {
        var point = SIMD2<Float>(x: 0.0, y: 0.0)
        if controlPointCount > 1 {
            if pos <= 0.0 {
                point.x = x[0].value
                point.y = y[0].value
            } else {
                var index:Int = Int(pos)
                var factor = pos - Float(index)
                if index < 0 {
                    index = 0
                    factor = 0.0
                } else if index >= _controlPointCount {
                    index = _controlPointCount - 1
                    factor = 1.0
                }
                
                // c * p^3 + b * p^2 + a * p + x
                point.x = x[index].value + (((x[index].coefC * factor) + x[index].coefB) * factor + x[index].coefA) * factor
                point.y = y[index].value + (((y[index].coefC * factor) + y[index].coefB) * factor + y[index].coefA) * factor
            }
        } else if controlPointCount == 1 {
            point.x = x[0].value
            point.y = y[0].value
        }
        return point
    }
    
    private var _controlPointCount: Int = 0
    
    func compute() {
        compute(coord: &x)
        compute(coord: &y)
    }
    
    private func compute(coord: inout [CubicSplineNode]) {
        guard controlPointCount >= 2 else { return }
        let count = controlPointCount
        let count1 = controlPointCount - 1
        let count2 = count1 - 1
        if controlPointCount == 2 {
            //Solve linear coefficients.
            var j = 0
            for i in 1..<count {
                coord[j].coefA = coord[i].value - coord[j].value
                coord[j].coefB = 0.0
                coord[j].coefC = 0.0
                j = i
            }
        } else {
            
            //compute derivatives for natural cubic spline.
            coord[0].delta = 3.0 * (coord[1].value - coord[0].value) * 0.25
            for i in 1..<count1 {
                coord[i].delta = (3.0 * (coord[i+1].value - coord[i-1].value) - coord[i-1].delta) * 0.25
            }
            coord[count1].delta = (3.0 * (coord[count1].value - coord[count2].value) - coord[count2].delta) * 0.25
            coord[count1].derivative = coord[count1].delta
            for i: Int in stride(from: (count2), to: -1, by: -1) {
                coord[i].derivative = coord[i].delta - 0.25 * coord[i + 1].derivative
            }
            
            //Find the coefficients.
            for i in 0..<count1 {
                coord[i].coefA = coord[i].derivative
                coord[i].coefB = 3.0 * (coord[i+1].value - coord[i].value) - 2.0 * coord[i].derivative - coord[i+1].derivative
                coord[i].coefC = 2.0 * (coord[i].value - coord[i+1].value) + coord[i].derivative + coord[i+1].derivative
            }
        }
    }
}



