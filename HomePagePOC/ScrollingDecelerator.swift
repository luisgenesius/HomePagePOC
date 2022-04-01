//
//  ScrollingDecelerator.swift
//  HomePagePOC
//
//  Created by Zulwiyoza Putra on 08/02/22.
//

import UIKit

// Reference:
// https://medium.com/@esskeetit/scrolling-mechanics-of-uiscrollview-142adee1142c
// https://gist.github.com/levantAJ/7860d3053324e4fc20e12d5dd3c51fb1

protocol ScrollingDeceleratorProtocol {
    func decelerate(by deceleration: ScrollingDeceleration)
    func invalidateIfNeeded()
}

// MARK: - TimerAnimationProtocol
protocol TimerAnimationProtocol {
    func invalidate()
}

final class ScrollingDecelerator {
    weak var scrollView: UIScrollView?
    var scrollingAnimation: TimerAnimationProtocol?
    let threshold: CGFloat
    
    init(scrollView: UIScrollView) {
        self.scrollView = scrollView
        threshold = 0.1
    }
}

//extension CGPoint {
//    // Calculate projection with initial velocity and deceleration rate
//    // Reference:
//    // https://gist.github.com/super-ultra/34143ebd4211fa4f470a6f35d0c73877#file-projection_wwdc18_1-swift
//    func projection(initialVelocity: CGPoint, decelerationRate: CGFloat) -> CGPoint {
//        rerturn .zer
//    }
//}

// MARK: - ScrollingDeceleratorProtocol
extension ScrollingDecelerator: ScrollingDeceleratorProtocol {
    func decelerate(by deceleration: ScrollingDeceleration) {
        guard let scrollView = scrollView else { return }
        
        let velocity = CGPoint(
            x: deceleration.velocity.x,
            y: deceleration.velocity.y * 1000 * threshold
        )
        
        scrollingAnimation = beginScrollAnimation(
            initialContentOffset: scrollView.contentOffset,
            initialVelocity: velocity,
            decelerationRate: deceleration.decelerationRate.rawValue
        ) { [weak scrollView] point in
            guard let scrollView = scrollView else { return }
            if deceleration.velocity.y < 0 {
                scrollView.contentOffset.y = max(point.y, 0)
            } else {
                scrollView.contentOffset.y = max(0, min(point.y, scrollView.contentSize.height - scrollView.frame.height))
            }
        }
    }
    
    func invalidateIfNeeded() {
        guard scrollView?.isUserInteracted == true else { return }
        scrollingAnimation?.invalidate()
        scrollingAnimation = nil
    }
}

// MARK: - Privates
extension ScrollingDecelerator {
    private func beginScrollAnimation(
        initialContentOffset: CGPoint,
        initialVelocity: CGPoint,
        decelerationRate: CGFloat,
        animations: @escaping (CGPoint) -> Void
    ) -> TimerAnimationProtocol {
        let timingParameters = ScrollTimingParameters(
            initialContentOffset: initialContentOffset,
            initialVelocity: initialVelocity,
            decelerationRate: decelerationRate,
            threshold: threshold
        )
        
        return TimerAnimation(duration: timingParameters.duration, animations: { progress in
            let point = timingParameters.point(at: progress * timingParameters.duration)
            animations(point)
        })
    }
}

// MARK: - ScrollTimingParameters
extension ScrollingDecelerator {
    struct ScrollTimingParameters {
        let initialContentOffset: CGPoint
        let initialVelocity: CGPoint
        let decelerationRate: CGFloat
        let threshold: CGFloat
    }
}

extension ScrollingDecelerator.ScrollTimingParameters {
    var duration: TimeInterval {
        guard decelerationRate < 1
            && decelerationRate > 0
            && initialVelocity.length != 0 else { return 0 }
        
        let dCoeff = 1000 * log(decelerationRate)
        return TimeInterval(log(-dCoeff * threshold / initialVelocity.length) / dCoeff)
    }
    
    func point(at time: TimeInterval) -> CGPoint {
        guard decelerationRate < 1
            && decelerationRate > 0
            && initialVelocity != .zero else { return .zero }
        
        let dCoeff = 1000 * log(decelerationRate)
        return initialContentOffset + (pow(decelerationRate, CGFloat(1000 * time)) - 1) / dCoeff * initialVelocity
    }
}

// MARK: - TimerAnimation
extension ScrollingDecelerator {
    final class TimerAnimation {
        typealias Animations = (_ progress: Double) -> Void
        typealias Completion = (_ isFinished: Bool) -> Void
        
        weak var displayLink: CADisplayLink?
        private(set) var isRunning: Bool
        private let duration: TimeInterval
        private let animations: Animations
        private let completion: Completion?
        private let firstFrameTimestamp: CFTimeInterval
        
        init(duration: TimeInterval, animations: @escaping Animations, completion: Completion? = nil) {
            self.duration = duration
            self.animations = animations
            self.completion = completion
            firstFrameTimestamp = CACurrentMediaTime()
            isRunning = true
            let displayLink = CADisplayLink(target: self, selector: #selector(step))
            displayLink.add(to: .main, forMode: .common)
            self.displayLink = displayLink
        }
    }
}

// MARK: - TimerAnimationProtocol
extension ScrollingDecelerator.TimerAnimation: TimerAnimationProtocol {
    func invalidate() {
        guard isRunning else { return }
        isRunning = false
        stopDisplayLink()
        completion?(false)
    }
}

// MARK: - Privates
extension ScrollingDecelerator.TimerAnimation {
    @objc private func step(displayLink: CADisplayLink) {
        guard isRunning else { return }
        let elapsed = CACurrentMediaTime() - firstFrameTimestamp
        if elapsed >= duration
            || duration == 0 {
            animations(1)
            isRunning = false
            stopDisplayLink()
            completion?(true)
        } else {
            animations(elapsed / duration)
        }
    }
    
    private func stopDisplayLink() {
        displayLink?.isPaused = true
        displayLink?.invalidate()
        displayLink = nil
    }
}

// MARK: - CGPoint
private extension CGPoint {
    var length: CGFloat {
        return sqrt(x * x + y * y)
    }
    
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func * (lhs: CGFloat, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs * rhs.x, y: lhs * rhs.y)
    }
}

final class ScrollingDeceleration {
    let velocity: CGPoint
    let decelerationRate: UIScrollView.DecelerationRate
    
    init(velocity: CGPoint, decelerationRate: UIScrollView.DecelerationRate) {
        self.velocity = velocity
        self.decelerationRate = decelerationRate
    }
}

// MARK: - Equatable
extension ScrollingDeceleration: Equatable {
    static func == (lhs: ScrollingDeceleration, rhs: ScrollingDeceleration) -> Bool {
        return lhs.velocity == rhs.velocity
            && lhs.decelerationRate == rhs.decelerationRate
    }
}


// MARK: - UIScrollView
extension UIScrollView {
    // Indicates that the scrolling is caused by user.
    var isUserInteracted: Bool {
        return isTracking || isDragging || isDecelerating
    }
}
