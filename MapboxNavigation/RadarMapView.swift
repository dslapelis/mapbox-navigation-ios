//
//  RadarMapView.swift
//  MapboxNavigation
//
//  Created by Daniel Slapelis on 2/24/19.
//  Copyright © 2019 Mapbox. All rights reserved.
//

import UIKit
import CoreLocation
import Mapbox
import MapboxDirections
import MapboxCoreNavigation

class RadarMapView: UIViewController, MGLMapViewDelegate {
    
    var mapView: NavigationMapView!
    var rasterLayer: MGLRasterStyleLayer?
    
    override func viewWillAppear(_ animated: Bool) {
        let url = URL(string: "mapbox://styles/mapbox/streets-v11")
        mapView = NavigationMapView(frame: view.bounds, styleURL: url)
        mapView.showsUserLocation = true
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.delegate = self
        mapView.setUserTrackingMode(.follow, animated: true)
        view.addSubview(mapView)
    }
    
    func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
        // Add a new raster source and layer.
        let source = MGLRasterTileSource(identifier: "stamen-watercolor", tileURLTemplates: ["https://mesonet.agron.iastate.edu/cache/tile.py/1.0.0/nexrad-n0q-900913/{z}/   {x}/{y}.png"], options: [ .tileSize: 256 ])
        let rasterLayer = MGLRasterStyleLayer(identifier: "stamen-watercolor", source: source)
        
        style.addSource(source)
        style.addLayer(rasterLayer)
        
        self.rasterLayer = rasterLayer
        rasterLayer.rasterOpacity = NSExpression(forConstantValue: 0.5 as NSNumber)
    }

}
