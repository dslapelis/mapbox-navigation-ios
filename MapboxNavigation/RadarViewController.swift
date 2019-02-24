import UIKit
import MapboxCoreNavigation
import AVFoundation

extension RadarViewController: UIViewControllerTransitioningDelegate {
    @objc public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        abortAutodismiss()
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

/**
 A view controller containing a grid of buttons the user can use to denote an issue their current navigation experience.
 */
@objc(MBRadarViewController)
public class RadarViewController: UIViewController, DismissDraggable, UIGestureRecognizerDelegate {
    
    static let sceneTitle = NSLocalizedString("RADAR_TITLE", value: "Radar Map", comment: "Title of view controller for viewing radar")
    static let cellReuseIdentifier = "collectionViewCellId"
    static let autoDismissInterval: TimeInterval = 30
    var rasterLayer: MGLRasterStyleLayer?
    let interactor = Interactor()
    
    @objc public weak var delegate: RadarViewControllerDelegate?
    
    lazy var mapView: NavigationMapView = {
        let url = URL(string: "mapbox://styles/mapbox/dark-v9")
        let map = NavigationMapView(frame: view.bounds, styleURL: url)
        map.delegate = self
        map.showsUserLocation = true
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        map.translatesAutoresizingMaskIntoConstraints = false
        map.setUserTrackingMode(.follow, animated: true)
        return map
    }()
    
    lazy var radarMapLabel: UILabel = {
        let label: UILabel = .forAutoLayout()
        label.textAlignment = .center
        label.text = RadarViewController.sceneTitle
        label.textColor = .white
        label.backgroundColor = .black
        return label
    }()
    
    lazy var progressBar: ProgressBar = .forAutoLayout()
    
    var draggableHeight: CGFloat {
        // V:|-0-recordingAudioLabel.height-collectionView.height-progressBar.height-0-|
        let radarLabelHeight = radarMapLabel.bounds.height
        let mapHeight = mapView.bounds.height/2
        return radarLabelHeight + mapHeight + progressBar.bounds.height
    }
    
    func commonInit() {
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = self
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.clear
        view.isOpaque = false
        setupViews()
        setupConstraints()
        view.layoutIfNeeded()
        transitioningDelegate = self
        enableDraggableDismiss()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        progressBar.progress = 1
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        delegate?.radarViewControllerDidOpen?(self)
        
        UIView.animate(withDuration: RadarViewController.autoDismissInterval) {
            self.progressBar.progress = 0
        }
        
        enableAutoDismiss()
        mapView.zoomLevel = 4
    }
    
    override public func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        
        // Dismiss the feedback view when switching between landscape and portrait mode.
        if traitCollection.verticalSizeClass != newCollection.verticalSizeClass {
            dismissFeedback()
        }
    }
    
    func enableAutoDismiss() {
        abortAutodismiss()
        perform(#selector(dismissFeedback), with: nil, afterDelay: RadarViewController.autoDismissInterval)
    }
    
    func abortAutodismiss() {
        progressBar.progress = 0
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(dismissFeedback), object: nil)
    }
    
    /**
     Instantly dismisses the FeedbackViewController if it is currently presented.
     */
    @objc public func dismissFeedback() {
        abortAutodismiss()
        dismissFeedbackItem()
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Only respond to touches outside/behind the view
        let isDescendant = touch.view?.isDescendant(of: view) ?? true
        return !isDescendant
    }
    
    @objc func handleDismissTap(sender: UITapGestureRecognizer) {
        dismissFeedback()
    }
    
    private func setupViews() {
        [radarMapLabel, mapView, progressBar].forEach(view.addSubview(_:))
        view.backgroundColor = .black
    }
    
    private func setupConstraints() {
        let labelTop = radarMapLabel.topAnchor.constraint(equalTo: view.topAnchor)
        let labelHeight = radarMapLabel.heightAnchor.constraint(equalToConstant: 30.0)
        let labelLeading = radarMapLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        let labelTrailing = radarMapLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        let mapViewLabelSpacing = mapView.topAnchor.constraint(equalTo: radarMapLabel.bottomAnchor)
        let mapViewLeading = mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        let mapViewTrailing = mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        let mapViewBarSpacing = mapView.bottomAnchor.constraint(equalTo: progressBar.topAnchor)
        
        let constraints = [labelTop, labelHeight, labelLeading, labelTrailing,
                           mapViewLabelSpacing, mapViewLeading, mapViewTrailing, mapViewBarSpacing]
        
        NSLayoutConstraint.activate(constraints)
        
        progressBar.heightAnchor.constraint(equalToConstant: 6.0).isActive = true
        progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        progressBar.bottomAnchor.constraint(equalTo: view.safeBottomAnchor).isActive = true
    }
    
    func dismissFeedbackItem() {
        delegate?.radarViewControllerDidCancel?(self)
        dismiss(animated: true, completion: nil)
    }
    
    @objc public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // In case the view is scrolled, dismiss the feedback window immediately
        // and reset the `progressBar` back to a full progress.
        abortAutodismiss()
        progressBar.progress = 1.0
    }
}

extension RadarViewController: MGLMapViewDelegate {
    @objc public func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
        // Add a new raster source and layer.
        let source = MGLRasterTileSource(identifier: "stamen-watercolor", tileURLTemplates: ["https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/nexrad-n0q-900913/{z}/{x}/{y}.png"], options: [ .tileSize: 256 ])
        let rasterLayer = MGLRasterStyleLayer(identifier: "stamen-watercolor", source: source)
        
        style.addSource(source)
        style.addLayer(rasterLayer)
        
        self.rasterLayer = rasterLayer
        rasterLayer.rasterOpacity = NSExpression(forConstantValue: 0.5 as NSNumber)
    }

}
