//
//  RxActionSheetView.swift
//  Yep
//
//  Created by 宋宋 on 16/4/1.
//  Copyright © 2016年 Catch Inc. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources
import NSObject_Rx
import RxOptional

// MARK: - ActionSheetDefaultCell

private class RxActionSheetDefaultCell: UITableViewCell {
    
    class var reuseIdentifier: String {
        return "\(self)"
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        
        makeUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var colorTitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFontOfSize(18, weight: UIFontWeightLight)
        label.font = UIFont(name: "HelveticaNeue-Light", size: 18)!
        return label
    }()
    
    var colorTitleLabelTextColor: UIColor = UIColor.yepTintColor() {
        willSet {
            colorTitleLabel.textColor = newValue
        }
    }
    
    func makeUI() {
        
        contentView.addSubview(colorTitleLabel)
        colorTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        colorTitleLabel.centerXAnchor.constraintEqualToAnchor(contentView.centerXAnchor).active = true
        colorTitleLabel.centerYAnchor.constraintEqualToAnchor(contentView.centerYAnchor).active = true
        
    }
}

// MARK: - ActionSheetDetailCell

private class RxActionSheetDetailCell: UITableViewCell {
    
    class var reuseIdentifier: String {
        return "\(self)"
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        accessoryType = .DisclosureIndicator
        
        layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        
        textLabel?.textColor = UIColor.darkGrayColor()
        
        textLabel?.font = UIFont.systemFontOfSize(18, weight: UIFontWeightLight)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - ActionSheetSwitchCell

private class RxActionSheetSwitchCell: UITableViewCell {
    
    class var reuseIdentifier: String {
        return "\(self)"
    }
    
    var action: (Bool -> Void)?
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        
        textLabel?.textColor = UIColor.darkGrayColor()
        textLabel?.font = UIFont.systemFontOfSize(18, weight: UIFontWeightLight)
        
        makeUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var checkedSwitch: UISwitch = {
        let s = UISwitch()
        s.addTarget(self, action: #selector(RxActionSheetSwitchCell.toggleSwitch(_:)), forControlEvents: .ValueChanged)
        return s
    }()
    
    @objc private func toggleSwitch(sender: UISwitch) {
        action?(sender.on)
    }
    
    func makeUI() {
        contentView.addSubview(checkedSwitch)
        checkedSwitch.translatesAutoresizingMaskIntoConstraints = false
        checkedSwitch.centerYAnchor.constraintEqualToAnchor(contentView.centerYAnchor).active = true
        checkedSwitch.trailingAnchor.constraintEqualToAnchor(contentView.trailingAnchor, constant: -20).active = true
    }
}

private class RxActionSheetCheckCell: UITableViewCell {
    
    class var reuseIdentifier: String {
        return "\(self)"
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        makeUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var colorTitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFontOfSize(18, weight: UIFontWeightLight)
        label.font = UIFont(name: "HelveticaNeue-Light", size: 18)!
        return label
    }()
    
    lazy var checkImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "icon_location_checkmark"))
        return imageView
    }()
    
    var colorTitleLabelTextColor: UIColor = UIColor.yepTintColor() {
        willSet {
            colorTitleLabel.textColor = newValue
        }
    }
    
    func makeUI() {
        
        contentView.addSubview(colorTitleLabel)
        contentView.addSubview(checkImageView)
        colorTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        checkImageView.translatesAutoresizingMaskIntoConstraints = false
        
        colorTitleLabel.centerXAnchor.constraintEqualToAnchor(contentView.centerXAnchor).active = true
        colorTitleLabel.centerYAnchor.constraintEqualToAnchor(contentView.centerYAnchor).active = true
        
        checkImageView.centerYAnchor.constraintEqualToAnchor(contentView.centerYAnchor).active = true
        checkImageView.trailingAnchor.constraintEqualToAnchor(contentView.trailingAnchor, constant: -20).active = true
        
    }
}

// MARK: - ActionSheetView

class RxActionSheetView: UIView {
    
    enum Item {
        case Default(title: String, titleColor: UIColor, action: () -> Bool)
        case Detail(title: String, titleColor: UIColor, action: () -> Void)
        case Switch(title: String, titleColor: UIColor, switchOn: Bool, action: (switchOn: Bool) -> Void)
        case Check(title: String, titleColor: UIColor, checked: Bool, action: () -> Void)
        case Cancel
    }
    
    var items: [Item]
    
    let rx_items = Variable<[Item]>([])
    
    private let rowHeight: CGFloat = 60
    
    private var totalHeight: CGFloat {
        return CGFloat(items.count) * rowHeight
    }
    
    init(items: [Item]) {
        self.items = items
        
        super.init(frame: CGRect.zero)
        
        self.rx_items.value = items
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.clearColor()
        return view
    }()
    
    private lazy var tableView: UITableView = {
        let view = UITableView()
        view.rowHeight = self.rowHeight
        view.scrollEnabled = false
        
        view.registerClass(RxActionSheetDefaultCell.self, forCellReuseIdentifier: RxActionSheetDefaultCell.reuseIdentifier)
        view.registerClass(RxActionSheetDetailCell.self, forCellReuseIdentifier: RxActionSheetDetailCell.reuseIdentifier)
        view.registerClass(RxActionSheetSwitchCell.self, forCellReuseIdentifier: RxActionSheetSwitchCell.reuseIdentifier)
        view.registerClass(RxActionSheetCheckCell.self, forCellReuseIdentifier: RxActionSheetCheckCell.reuseIdentifier)
        
        return view
    }()
    
    private var isFirstTimeBeenAddedAsSubview = true
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        if isFirstTimeBeenAddedAsSubview {
            isFirstTimeBeenAddedAsSubview = false
            
            makeUI()
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(RxActionSheetView.hide))
            containerView.addGestureRecognizer(tap)
            
            tap.cancelsTouchesInView = true
            tap.delegate = self
            
        }
    }
    
    func refreshItems() {
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            self?.tableView.reloadData()
        }
    }
    
    private var tableViewBottomConstraint: NSLayoutConstraint?
    
    private func makeUI() {
        
        addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        let viewsDictionary = [
            "containerView": containerView,
            "tableView": tableView,
            ]
        
        // layout for containerView
        
        containerView.topAnchor.constraintEqualToAnchor(topAnchor).active = true
        containerView.trailingAnchor.constraintEqualToAnchor(trailingAnchor).active = true
        containerView.leadingAnchor.constraintEqualToAnchor(leadingAnchor).active = true
        containerView.bottomAnchor.constraintEqualToAnchor(bottomAnchor).active = true
        
        // layout for tableView
        
        tableView.trailingAnchor.constraintEqualToAnchor(containerView.trailingAnchor).active = true
        tableView.leadingAnchor.constraintEqualToAnchor(containerView.leadingAnchor).active = true
        tableView.heightAnchor.constraintEqualToConstant(totalHeight).active = true
        let tableViewBottomConstraint = tableView.bottomAnchor.constraintEqualToAnchor(containerView.bottomAnchor)
        tableViewBottomConstraint.active = true
        self.tableViewBottomConstraint = tableViewBottomConstraint
        
        // TODO: - 先写在这里，== View 也要改才方便传递 ==
        
        rx_items.asObservable()
            .bindTo(tableView.rx_itemsWithCellFactory) { (tableView, index, item) in
                switch item {
                case let .Default(title, titleColor, _):
                    let cell = tableView.dequeueReusableCellWithIdentifier(RxActionSheetDefaultCell.reuseIdentifier) as! RxActionSheetDefaultCell
                    cell.colorTitleLabel.text = title
                    cell.colorTitleLabelTextColor = titleColor
                    return cell
                    
                case let .Detail(title, titleColor, _):
                    let cell = tableView.dequeueReusableCellWithIdentifier(RxActionSheetDetailCell.reuseIdentifier) as! RxActionSheetDetailCell
                    cell.textLabel?.text = title
                    cell.textLabel?.textColor = titleColor
                    return cell
                case let .Switch(title, titleColor, switchOn, action):
                    let cell = tableView.dequeueReusableCellWithIdentifier(RxActionSheetSwitchCell.reuseIdentifier) as! RxActionSheetSwitchCell
                    cell.textLabel?.text = title
                    cell.textLabel?.textColor = titleColor
                    cell.checkedSwitch.on = switchOn
                    cell.action = action
                    return cell
                    
                case let .Check(title, titleColor, checked, _):
                    let cell = tableView.dequeueReusableCellWithIdentifier(RxActionSheetCheckCell.reuseIdentifier) as! RxActionSheetCheckCell
                    cell.colorTitleLabel.text = title
                    cell.colorTitleLabelTextColor = titleColor
                    cell.checkImageView.hidden = !checked
                    return cell
                    
                case .Cancel:
                    let cell = tableView.dequeueReusableCellWithIdentifier(RxActionSheetDefaultCell.reuseIdentifier) as! RxActionSheetDefaultCell
                    cell.colorTitleLabel.text = NSLocalizedString("Cancel", comment: "")
                    cell.colorTitleLabelTextColor = UIColor.yepTintColor()
                    return cell
                }
        }.addDisposableTo(rx_disposeBag)
        
        tableView.rx_modelItemSelected(Item).subscribeNext { [unowned self] item, ip in
            defer {
                self.tableView.deselectRowAtIndexPath(ip, animated: true)
            }
            
            switch item {
                
            case .Default(_, _, let action): if action() { self.hide() }

            case .Detail(_, _, let action): self.hideAndDo { action() }
                
            case .Switch: break
                
            case .Check(_, _, _, let action):
                action()
                self.hide()
                
            case .Cancel:
                self.hide()
                break
            }
        }.addDisposableTo(rx_disposeBag)
        
        
    }
    
    func showInView(view: UIView) {
        
        frame = view.bounds
        
        view.addSubview(self)
        
        layoutIfNeeded()
        
        containerView.alpha = 1
        
        UIView.animateWithDuration(0.2, delay: 0.0, options: .CurveEaseIn, animations: { _ in
            self.containerView.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.3)
            }, completion: nil)
        
        UIView.animateWithDuration(0.2, delay: 0.1, options: .CurveEaseOut, animations: { _ in
            self.tableViewBottomConstraint?.constant = 0
            self.layoutIfNeeded()
            }, completion: nil)
    }
    
    func hide() {
        
        UIView.animateWithDuration(0.2, delay: 0.0, options: .CurveEaseIn, animations: { _ in
            self.tableViewBottomConstraint?.constant = self.totalHeight
            self.layoutIfNeeded()
            }, completion: nil)
        
        UIView.animateWithDuration(0.2, delay: 0.1, options: .CurveEaseOut, animations: { _ in
            self.containerView.backgroundColor = UIColor.clearColor()
            }) { _ in self.removeFromSuperview() }
    }
    
    func hideAndDo(afterHideAction: (() -> Void)?) {
        
        UIView.animateWithDuration(0.2, delay: 0.0, options: .CurveLinear, animations: { _ in
            self.containerView.alpha = 0
            self.tableViewBottomConstraint?.constant = self.totalHeight
            self.layoutIfNeeded()
            
            }) { _ in self.removeFromSuperview() }
        
        delay(0.1) {
            afterHideAction?()
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension RxActionSheetView: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        
        if touch.view != containerView {
            return false
        }
        
        return true
    }
}
