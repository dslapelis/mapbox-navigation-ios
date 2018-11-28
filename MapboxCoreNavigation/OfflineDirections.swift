import Foundation
import MapboxDirections
import MapboxNavigationNative

public typealias OfflineDirectionsCompletionHandler = (_ numberOfTiles: UInt64) -> Void

enum OfflineRoutingError: Error, LocalizedError {
    case unexpectedRouteResult(String)
    case corruptRouteData(String)
    case responseError(String)
    
    public var localizedDescription: String {
        switch self {
        case .corruptRouteData(let value):
            return value
        case .unexpectedRouteResult(let value):
            return value
        case .responseError(let value):
            return value
        }
    }
    
    var errorDescription: String? {
        return localizedDescription
    }
}

struct OfflineDirectionsConstants {
    static let offlineSerialQueueLabel = Bundle.mapboxCoreNavigation.bundleIdentifier!.appending(".offline")
    static let unpackSerialQueueLabel = Bundle.mapboxCoreNavigation.bundleIdentifier!.appending(".offline.unpack")
    static let offlineSerialQueue = DispatchQueue(label: OfflineDirectionsConstants.offlineSerialQueueLabel)
    static let unpackSerialQueue = DispatchQueue(label: OfflineDirectionsConstants.unpackSerialQueueLabel)
}

/**
 Defines additional functionality similar to `Directions` with support for offline routing.
 */
@objc(MBNavigatorDirectionsProtocol)
public protocol NavigatorDirectionsProtocol {
    
    /**
     Configures the router with the given set of tiles
     
     - parameter tilesURL: The location where the tiles has been sideloaded to.
     - parameter translationsURL: The location where the translations has been downloaded to.
     - parameter accessToken: A Mapbox [access token](https://www.mapbox.com/help/define-access-token/). If an access token is not specified when initializing the directions object, it should be specified in the `MGLMapboxAccessToken` key in the main application bundle’s Info.plist.
     - parameter host: An optional hostname to the server API. The [Mapbox Directions API](https://www.mapbox.com/api-documentation/?language=Swift#directions) endpoint is used by default.
     */
    func configureRouter(tilesURL: URL, translationsURL: URL?, completionHandler: @escaping OfflineDirectionsCompletionHandler)
    
    /**
     Begins asynchronously calculating the route or routes using the given options and delivers the results to a closure.
     
     This method retrieves the routes asynchronously via MapboxNavigationNative.
     
     Routes may be displayed atop a [Mapbox map](https://www.mapbox.com/maps/). They may be cached but may not be stored permanently. To use the results in other contexts or store them permanently, [upgrade to a Mapbox enterprise plan](https://www.mapbox.com/directions/#pricing).
     
     - parameter options: A `RouteOptions` object specifying the requirements for the resulting routes.
     - parameter completionHandler: The closure (block) to call with the resulting routes. This closure is executed on the application’s main thread.
     */
    func calculate(_ options: RouteOptions, offline: Bool, completionHandler: @escaping Directions.RouteCompletionHandler)
}

@objc(MBNavigationDirections)
public class NavigationDirections: Directions, NavigatorDirectionsProtocol {
    
    public typealias UnpackProgressHandler = (_ totalBytes: UInt64, _ remainingBytes: UInt64) -> ()
    public typealias UnpackCompletionHandler = (_ result: UInt64, _ error: Error?) -> ()
    
    public override init(accessToken: String? = nil, host: String? = nil) {
        super.init(accessToken: accessToken, host: host)
    }
    
    public func configureRouter(tilesURL: URL, translationsURL: URL? = nil, completionHandler: @escaping OfflineDirectionsCompletionHandler) {
        
        OfflineDirectionsConstants.offlineSerialQueue.sync {
            // Translations files bundled winthin navigation native
            // will be used when passing an empty string to `translationsPath`.
            let tileCount = self.navigator.configureRouter(forTilesPath: tilesURL.path, translationsPath: translationsURL?.path ?? "")
            
            DispatchQueue.main.async {
                completionHandler(tileCount)
            }
        }
    }
    
    public class func unpackTilePack(at filePath: URL, outputDirectory: URL, progressHandler: UnpackProgressHandler?, completionHandler: UnpackCompletionHandler?) {
        
        OfflineDirectionsConstants.offlineSerialQueue.sync {
            
            let totalPackedBytes = filePath.fileSize!
            
            // Report 0% progress
            progressHandler?(totalPackedBytes, totalPackedBytes)
            
            var timer: DispatchTimer? = DispatchTimer(countdown: .seconds(500), accuracy: .seconds(500), executingOn: OfflineDirectionsConstants.unpackSerialQueue) {
                if let remainingBytes = filePath.fileSize {
                    progressHandler?(totalPackedBytes, remainingBytes)
                }
            }

            timer?.arm()
            
            let tilePath = filePath.absoluteString.replacingOccurrences(of: "file://", with: "")
            let outputPath = outputDirectory.absoluteString.replacingOccurrences(of: "file://", with: "")
            
            let result = MBNavigator().unpackTiles(forPacked_tiles_path: tilePath, output_directory: outputPath)
            
            // Report 100% progress
            progressHandler?(totalPackedBytes, totalPackedBytes)
            
            timer?.disarm()
            timer = nil
            
            DispatchQueue.main.async {
                completionHandler?(result, nil)
            }
        }
    }
    
    public func calculate(_ options: RouteOptions, offline: Bool = true, completionHandler: @escaping Directions.RouteCompletionHandler) {
        
        guard offline == true else {
            super.calculate(options, completionHandler: completionHandler)
            return
        }
        
        let url = self.url(forCalculating: options)
        
        OfflineDirectionsConstants.offlineSerialQueue.async { [weak self] in
            
            guard let result = self?.navigator.getRouteForDirectionsUri(url.absoluteString) else {
                let error = OfflineRoutingError.unexpectedRouteResult("Unexpected routing result")
                return completionHandler(nil, nil, error as NSError)
            }
            
            guard let data = result.json.data(using: .utf8) else {
                let error = OfflineRoutingError.corruptRouteData("Corrupt route data")
                return completionHandler(nil, nil, error as NSError)
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
                if let errorValue = json["error"] as? String {
                    DispatchQueue.main.async {
                        let error = OfflineRoutingError.responseError(errorValue)
                        return completionHandler(nil, nil, error as NSError)
                    }
                } else {
                    
                    DispatchQueue.main.async {
                        let response = options.response(from: json)
                        return completionHandler(response.0, response.1, nil)
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    return completionHandler(nil, nil, error as NSError)
                }
            }
        }
    }
    
    var _navigator: MBNavigator!
    var navigator: MBNavigator {
        
        assert(currentQueueName() == OfflineDirectionsConstants.offlineSerialQueueLabel,
               "The offline navigator must be accessed from the dedicated serial queue")
        
        if _navigator == nil {
            self._navigator = MBNavigator()
        }
        
        return _navigator
    }
}

fileprivate func currentQueueName() -> String? {
    let name = __dispatch_queue_get_label(nil)
    return String(cString: name, encoding: .utf8)
}

extension URL {
    
    fileprivate var fileSize: UInt64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: self.path)
            return attributes[.size] as? UInt64
        } catch {
            return nil
        }
    }
}
