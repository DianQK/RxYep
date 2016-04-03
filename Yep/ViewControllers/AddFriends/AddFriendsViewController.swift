//
//  AddFriendsViewController.swift
//  Yep
//
//  Created by NIX on 15/5/19.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit
import AddressBook
import Proposer
import RxSwift
import RxCocoa
import RxDataSources
import NSObject_Rx

private typealias AddFriendsSection = AnimatableSectionModel<AddFriendsViewController.Section, String>

class AddFriendsViewController: UIViewController, NavigationBarAutoShowable {

    @IBOutlet private weak var addFriendsTableView: UITableView!

    private static let addFriendSearchCellIdentifier = "AddFriendSearchCell"
    private static let addFriendMoreCellIdentifier = "AddFriendMoreCell"
    
    private let section = Variable([AddFriendsSection(model: .Search, items: [""]),
        AddFriendsSection(model: .More, items: [AddFriendsViewController.More.Contacts.description])])
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        yepAutoShowNavigationBar()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Add Friends", comment: "")

        addFriendsTableView.rowHeight = 60

        addFriendsTableView.registerNib(UINib(nibName: AddFriendsViewController.addFriendSearchCellIdentifier, bundle: nil), forCellReuseIdentifier: AddFriendsViewController.addFriendSearchCellIdentifier)
        addFriendsTableView.registerNib(UINib(nibName: AddFriendsViewController.addFriendMoreCellIdentifier, bundle: nil), forCellReuseIdentifier: AddFriendsViewController.addFriendMoreCellIdentifier)
        
        let dataSource = RxTableViewSectionedReloadDataSource<AddFriendsSection>()
        dataSource.configureCell = { ds, tb, ip, i in
            switch ds.sectionAtIndex(ip.section).identity {
            case .Search:
                let cell = tb.dequeueReusableCellWithIdentifier(AddFriendsViewController.addFriendSearchCellIdentifier) as! AddFriendSearchCell
                cell.searchTextField.returnKeyType = .Search
                cell.searchTextField.delegate = self
                cell.searchTextField.becomeFirstResponder()
                return cell
            case .More:
                let cell = tb.dequeueReusableCellWithIdentifier(AddFriendsViewController.addFriendMoreCellIdentifier) as! AddFriendMoreCell
                cell.annotationLabel.text = More(rawValue: ip.row)?.description
                return cell
            }
        }
        
        section.asObservable()
            .bindTo(addFriendsTableView.rx_itemsWithDataSource(dataSource))
            .addDisposableTo(rx_disposeBag)
        
        addFriendsTableView.rx_modelItemSelected(IdentifiableValue<String>)
            .subscribeNext { [unowned self] tb, i, ip in
                switch ip.section {  // TODO: - 这并不是一个好的方案
                case Section.More.rawValue:
                    let propose: Propose = {
                        proposeToAccess(.Contacts, agreed: { [weak self] in
                            self?.yep_performSegueWithIdentifier("showFriendsInContacts", sender: nil)
                            }, rejected: { [weak self] in
                                self?.alertCanNotAccessContacts()
                            })
                    }
                    self.showProposeMessageIfNeedForContactsAndTryPropose(propose)
                default: break
                }
                tb.deselectRowAtIndexPath(ip, animated: true)
            }
            .addDisposableTo(rx_disposeBag)
        
    }

    // MARK: Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if let searchTextBox = sender as? Box<String> where segue.identifier == "showSearchedUsers" {
            let vc = segue.destinationViewController as! SearchedUsersViewController
            vc.searchText = searchTextBox.value.trimming(.WhitespaceAndNewline)
        }
        
    }
}

extension AddFriendsViewController {

    private enum Section: Int {
        case Search = 0
        case More
    }

    private enum More: Int, CustomStringConvertible {
        case Contacts
        //case FaceToFace

        var description: String {
            switch self {

            case .Contacts:
                return NSLocalizedString("Friends in Contacts", comment: "")

            //case .FaceToFace:
            //    return NSLocalizedString("Face to Face", comment: "")
            }
        }
    }

}

extension AddFriendsViewController: UITextFieldDelegate {

    func textFieldShouldReturn(textField: UITextField) -> Bool {

        guard let text = textField.text where text.isNotEmpty else { return false }

        textField.resignFirstResponder()

        yep_performSegueWithIdentifier("showSearchedUsers", sender: Box(text))

        return true
    }
}
