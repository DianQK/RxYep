//
//  PickLocationViewController.swift
//  Yep
//
//  Created by NIX on 15/5/4.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit
import MapKit
import Proposer
import RxSwift
import RxCocoa
import RxDataSources
import RxOptional
import NSObject_Rx
import RxGesture

class PickLocationViewController: UIViewController {

    enum Purpose {
        case Message
        case Feed
    }
    var purpose: Purpose = .Message

    var preparedSkill: Skill?

    var afterCreatedFeedAction: ((feed: DiscoveredFeed) -> Void)?

    typealias SendLocationAction = (locationInfo: Location.Info) -> Void
    var sendLocationAction: SendLocationAction?

    @IBOutlet private weak var cancelButton: UIBarButtonItem!
    @IBOutlet private weak var doneButton: UIBarButtonItem!
    @IBOutlet private weak var mapView: MKMapView!
    @IBOutlet private weak var pinImageView: UIImageView!
    @IBOutlet private weak var searchBar: UISearchBar!
    @IBOutlet private weak var searchBarTopToSuperBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView! // 其状态不应该去和 ViewModel 相关 == ViewModel 初始化就是获得了位置，此时已经 stop

    private var viewModel: PickLocationViewModel!

    private lazy var geocoder = CLGeocoder()
    
    private var userLocationPlacemarks = [CLPlacemark]()
    
    private enum Section {
        //        case CurrentLocation
        //        case UserPickedLocation
        //        case UserLocationPlacemarks
        case SearchedLocation(MKMapItem)
        case Foursquare(FoursquareVenue) //删除 "Venue"
    }

    private let pickLocationCellIdentifier = "PickLocationCell"

    enum Location {

        struct Info {
            let coordinate: CLLocationCoordinate2D
            var name: String?
        }

        case Default(info: Info)
        case Picked(info: Info)
        case Selected(info: Info)

        var info: Info {
            switch self {
            case .Default(let locationInfo):
                return locationInfo
            case .Picked(let locationInfo):
                return locationInfo
            case .Selected(let locationInfo):
                return locationInfo
            }
        }

        var isPicked: Bool {
            switch self {
            case .Picked:
                return true
            default:
                return false
            }
        }
    }

    private var location: Location? {
        willSet {
            if let _ = newValue {
                doneButton.enabled = true
            }
        }
    }

    private var selectedLocationIndexPath: NSIndexPath?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Pick Location", comment: "")

        cancelButton.title = NSLocalizedString("Cancel", comment: "")

        switch purpose {
        case .Message:
            doneButton.title = NSLocalizedString("Send", comment: "")
        case .Feed:
            doneButton.title = NSLocalizedString("Next", comment: "")
        }

        searchBar.placeholder = NSLocalizedString("Search", comment: "")

        tableView.registerNib(UINib(nibName: pickLocationCellIdentifier, bundle: nil), forCellReuseIdentifier: pickLocationCellIdentifier)
        tableView.rowHeight = 50

        doneButton.enabled = false
        
        mapView.showsUserLocation = true
        
        let locationCoordinate: Driver<CLLocationCoordinate2D>
        
        if let location = YepLocationService.sharedManager.locationManager.location {
            let region = MKCoordinateRegionMakeWithDistance(location.coordinate.yep_applyChinaLocationShift, 1000, 1000)
            mapView.setRegion(region, animated: false)
            
            locationCoordinate = Driver.just(location.coordinate.yep_applyChinaLocationShift)

            self.location = .Default(info: Location.Info(coordinate: location.coordinate.yep_applyChinaLocationShift, name: nil))

            placemarksAroundLocation(location) { [weak self] placemarks in
                self?.userLocationPlacemarks = placemarks.filter({ $0.name != nil })
            }

        } else {
            locationCoordinate = Driver.empty()
            
            proposeToAccess(.Location(.WhenInUse), agreed: {

                YepLocationService.turnOn()

            }, rejected: {
                self.alertCanNotAccessLocation()
            })

            activityIndicator.startAnimating()
        }

        view.bringSubviewToFront(tableView)
        view.bringSubviewToFront(searchBar)
        view.bringSubviewToFront(activityIndicator)

        let pan = UIPanGestureRecognizer()
        mapView.addGestureRecognizer(pan)
        pan.delegate = self
        
        /// 地理位置更新
        let didUpdateLocation = mapView.rx_didUpdateUserLocation.asDriver().map { $0.location }.filterNil()
        /// map 成 Coordinate
        let didUpdateCoordinate = didUpdateLocation.map { $0.coordinate.yep_cancelChinaLocationShift }
        /// pan 手势移动 Coordinate
        let didMoveCoordinate = pan.rx_event.asDriver().filter { $0.state == .Ended }.map { [unowned self] _ in self.fixedCenterCoordinate.yep_cancelChinaLocationShift }
        /// merge 以上两种情况
        let didChangeCoordinate = [locationCoordinate, didUpdateCoordinate, didMoveCoordinate].toObservable().merge().asDriver(onErrorJustReturn: fixedCenterCoordinate.yep_cancelChinaLocationShift )
        
        didMoveCoordinate
            .driveNext { [unowned self] coordinate in
                self.location = .Picked(info: Location.Info(coordinate: coordinate, name: nil))
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                self.placemarksAroundLocation(location) { placemarks in
                    let pickedLocationPlacemarks = placemarks.filter({ $0.name != nil })
                    if let placemark = pickedLocationPlacemarks.first, location = self.location {
                        if case .Picked = location {
                            var info = location.info
                            info.name = placemark.yep_autoName
                            self.location = .Picked(info: info)
                        }
                    }
                }
            }
            .addDisposableTo(rx_disposeBag)

        let searchText = searchBar.rx_text.asDriver().debounce(0.3)
        
        viewModel = PickLocationViewModel(input: (
            didUpdateCoordinate: didChangeCoordinate,
            searchPlacesName: searchText))
        
        didUpdateLocation.asObservable().take(1)
            .subscribeNext { [unowned self] location in
                
                if let realLocation = YepLocationService.sharedManager.locationManager.location { // 这部分是？
                    let latitudeShift = location.coordinate.latitude - realLocation.coordinate.latitude
                    let longitudeShift = location.coordinate.longitude - realLocation.coordinate.longitude
                    YepUserDefaults.latitudeShift.value = latitudeShift
                    YepUserDefaults.longitudeShift.value = longitudeShift
                }
            
                self.activityIndicator.stopAnimating()
            
                self.doneButton.enabled = true
                
                self.mapView.showsUserLocation = false
            
            }
            .addDisposableTo(rx_disposeBag)
        
        didChangeCoordinate // 绑定中心点，这个不需要 ViewModel 帮助
            .driveNext { [unowned self] coordinate in
                self.mapView.setCenterCoordinate(coordinate, animated: true)
            }
            .addDisposableTo(rx_disposeBag)
        
        let foursquareVenues = viewModel.foursquareVenues.asObservable().map { $0.map { Section.Foursquare($0) } }
        
        let searchedMapItems = viewModel.searchedMapItems.asObservable().map { $0.map { Section.SearchedLocation($0) } }
        
        [foursquareVenues, searchedMapItems].toObservable().merge()
            .bindTo(tableView.rx_itemsWithCellIdentifier(pickLocationCellIdentifier, cellType: PickLocationCell.self)) { [unowned self] ip, i, c in
                c.iconImageView.hidden = false
                c.iconImageView.image = UIImage(named: "icon_pin")
                c.checkImageView.hidden = true
                
                switch i {
                case .Foursquare(let venues):
                    c.locationLabel.text = venues.name
                case .SearchedLocation(let mapItem):
                    c.locationLabel.text = mapItem.placemark.name ?? "🐌" // ==
                }
                
                if let pickLocationIndexPath = self.selectedLocationIndexPath {
                    c.checkImageView.hidden = !(pickLocationIndexPath == ip)
                }
            }
            .addDisposableTo(rx_disposeBag)
        
        tableView.rx_modelItemSelected(Section)
            .subscribeNext { [unowned self] tb, i, ip in
                
                if let selectedLocationIndexPath = self.selectedLocationIndexPath {
                    if let cell = tb.cellForRowAtIndexPath(selectedLocationIndexPath) as? PickLocationCell {
                        cell.checkImageView.hidden = true
                    }
                    
                }
//                else {
//                    if let cell = tb.cellForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: Section.CurrentLocation.rawValue)) as? PickLocationCell {
//                        cell.checkImageView.hidden = true
//                    }
//                }
                
                if let cell = tb.cellForRowAtIndexPath(ip) as? PickLocationCell {
                    cell.checkImageView.hidden = false
                }
                
                self.selectedLocationIndexPath = ip
                
                switch i {
                case .Foursquare(let venue):
                    let coordinate = venue.coordinate.yep_applyChinaLocationShift
                    self.location = .Selected(info: Location.Info(coordinate: coordinate, name: venue.name))
                    self.mapView.setCenterCoordinate(coordinate, animated: true) // 选择某个 Cell 时也需要切换一下 Center
                case .SearchedLocation(let mapItem):
                    let placemark = mapItem.placemark
                    guard let _location = placemark.location else { break }
                    self.location = .Selected(info: Location.Info(coordinate: _location.coordinate, name: placemark.name))
                    self.mapView.setCenterCoordinate(_location.coordinate, animated: true)
                }
                
                tb.deselectRowAtIndexPath(ip, animated: true)

            }
            .addDisposableTo(rx_disposeBag)
        
    }

    // MARK: Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if let locationBox = sender as? Box<Location> where segue.identifier == "showNewFeed" {
            let vc = segue.destinationViewController as! NewFeedViewController
            
            vc.attachment = .Location(locationBox.value)
            
            vc.preparedSkill = preparedSkill
            
            vc.afterCreatedFeedAction = afterCreatedFeedAction
        }

    }

    // MARK: Actions
    
    @IBAction private func cancel(sender: UIBarButtonItem) {

        dismissViewControllerAnimated(true, completion: nil)
    }

    private var fixedCenterCoordinate: CLLocationCoordinate2D {
        return mapView.convertPoint(mapView.center, toCoordinateFromView: mapView)
    }

    @IBAction private func done(sender: UIBarButtonItem) {

        switch purpose {

        case .Message:

            dismissViewControllerAnimated(true) {

                if let sendLocationAction = self.sendLocationAction {

                    if let location = self.location {
                        sendLocationAction(locationInfo: location.info)

                    } else {
                        sendLocationAction(locationInfo: Location.Info(coordinate: self.fixedCenterCoordinate, name: nil))
                    }
                }
            }

        case .Feed:

            if let location = location {
                yep_performSegueWithIdentifier("showNewFeed", sender: Box(location))

            } else {
                let _location = Location.Default(info: Location.Info(coordinate: fixedCenterCoordinate, name: userLocationPlacemarks.first?.yep_autoName))

                yep_performSegueWithIdentifier("showNewFeed", sender: Box(_location))
            }
        }
    }

    private func placemarksAroundLocation(location: CLLocation, completion: [CLPlacemark] -> Void) {

        geocoder.reverseGeocodeLocation(location, completionHandler: { placemarks, error in

            if error != nil {
                println("reverse geodcode fail: \(error?.localizedDescription)")

                completion([])

                return
            }

            if let placemarks = placemarks {
                
                completion(placemarks)

            } else {
                println("No Placemarks!")

                completion([])
            }
        })
    }

}

// MARK: - MKMapViewDelegate

extension PickLocationViewController: UIGestureRecognizerDelegate {

    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {

        return true
    }
}

// MARK: - MKMapViewDelegate

extension PickLocationViewController: MKMapViewDelegate {

    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {

        if let annotation = annotation as? LocationPin {

            let identifier = "LocationPinView"

            if let annotationView = mapView.dequeueReusableAnnotationViewWithIdentifier(identifier) {
                annotationView.annotation = annotation

                return annotationView

            } else {
                let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView.image = UIImage(named: "icon_pin_shadow")
                annotationView.enabled = false
                annotationView.canShowCallout = false

                return annotationView
            }
        }

        return nil
    }
}

// MARK: - UISearchBarDelegate

extension PickLocationViewController: UISearchBarDelegate {
    
    func searchBarShouldBeginEditing(searchBar: UISearchBar) -> Bool {

        navigationController?.setNavigationBarHidden(true, animated: true)

        UIView.animateWithDuration(0.3, delay: 0.0, options: .CurveEaseInOut, animations: { _ in
            self.searchBarTopToSuperBottomConstraint.constant = CGRectGetHeight(self.view.bounds) - 20
            self.view.layoutIfNeeded()

        }, completion: { finished in
            self.searchBar.setShowsCancelButton(true, animated: true)
        })

        return true
    }

    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        shrinkSearchLocationView()
    }

    func shrinkSearchLocationView() {
        searchBar.resignFirstResponder()

        navigationController?.setNavigationBarHidden(false, animated: true)

        UIView.animateWithDuration(0.3, delay: 0.0, options: .CurveEaseInOut, animations: { _ in
            self.searchBarTopToSuperBottomConstraint.constant = 250
            self.view.layoutIfNeeded()

        }) { finished in
            self.searchBar.setShowsCancelButton(false, animated: true)
        }
    }

    func searchBarSearchButtonClicked(searchBar: UISearchBar) {

        guard let _ = searchBar.text else { return }

        shrinkSearchLocationView() // 不是 ViewModel 的事情
    }

}
