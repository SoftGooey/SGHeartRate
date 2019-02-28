//
//  GraphView.swift
//  SGHeartRate
//
//  Created by Sophie Prince on 2019-02-27.
//  Copyright © 2019 SoftGooey. All rights reserved.
//
//  A very basic graph view.  addPoint will trigger a redraw
//  Drawing involves a BezierPath to draw all the points 
//

import UIKit

class GraphView: UIView {
    
    // y axis labels
    var maxLabel: UILabel! = UILabel()
    var minLabel: UILabel! = UILabel()
    
    var dataPoints: [Int]! = [Int]()
    var shapeLayer: CAShapeLayer! = CAShapeLayer()
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    func setupView() {
        shapeLayer.strokeColor = UIColor.white.cgColor
        shapeLayer.lineWidth = 2
        layer.addSublayer(shapeLayer)
        
        minLabel.textColor = UIColor.white
        maxLabel.textColor = UIColor.white
        addSubview(maxLabel)
        addSubview(minLabel)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = self.bounds
        minLabel.frame = CGRect(x: 0, y: self.bounds.size.height - 20, width: 30, height: 20)
        maxLabel.frame = CGRect(x: 0, y: 0, width: 30, height: 20)
    }
    
    override func draw(_ rect: CGRect) {
        
        if dataPoints.count < 2 {
            // not enough points to draw
        }
        else
        {
            let max = dataPoints.max()
            let min = dataPoints.min()
            
            if min != nil && max != nil {
                let yMax = max! + 1
                let yMin = min! - 1
                maxLabel.text = String(yMax)
                minLabel.text = String(yMin)
                
                let yPointSize = self.bounds.size.height / CGFloat(yMax - yMin)
                let xPointSize = self.bounds.size.width / CGFloat(dataPoints.count - 1)
                
                let bezierPath: UIBezierPath! = UIBezierPath()
                var index : Int = 0
                
                for currentPoint in self.dataPoints {
                    let xValue = CGFloat(index) * xPointSize
                    let yValue = self.bounds.size.height - CGFloat(currentPoint - yMin) * yPointSize;
                    
                    if (index > 0) {
                        bezierPath.addLine(to: CGPoint(x: xValue, y: yValue))
                    }
                    bezierPath.move(to: CGPoint(x: xValue, y: yValue))
                    index += 1
                }
                
                bezierPath.close()
                shapeLayer.path = bezierPath.cgPath
            }
        }
    }
    
    func addPoint(aPoint : Int) {
        dataPoints.append(aPoint)
        self.setNeedsDisplay()
    }
}
