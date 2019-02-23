//
//  RadarViewController.swift
//  MapboxNavigation
//
//  Created by Daniel Slapelis on 2/23/19.
//  Copyright © 2019 Mapbox. All rights reserved.
//

import UIKit
import MapboxCoreNavigation
import AVFoundation

extension RadarViewController: UIViewControllerTransitioningDelegate {
    @objc public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return DismissAnimator()
    }
    
    @objc public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return PresentAnimator()
    }
    
    @objc public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactor.hasStarted ? interactor : nil
    }
}

/**
 The `FeedbackViewControllerDelegate` protocol provides methods for responding to feedback events.
 */
@objc public protocol RadarViewControllerDelegate {
    
    /**
     Called when the user opens the feedback form.
     */
    @objc optional func  radarViewControllerDidOpen(_ radarViewController: RadarViewController)
    
    /**
     Called when a `FeedbackViewController` is dismissed for any reason without giving explicit feedback.
     */
    @objc optional func radarViewControllerDidCancel(_ radarViewController: RadarViewController)
}

public class RadarViewController: UIViewController, DismissDraggable, UIGestureRecognizerDelegate {
    let interactor = Interactor()
    
    var draggableHeight: CGFloat {
        return 500.0
    }
    
    static let sceneTitle = NSLocalizedString("RADAR_TITLE", value: "Nearby Radar", comment: "Title of view controller for viewing radar")
    static let cellReuseIdentifier = "collectionViewCellId"
    
}
