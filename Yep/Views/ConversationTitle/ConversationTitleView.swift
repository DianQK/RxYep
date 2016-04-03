//
//  ConversationTitleView.swift
//  Yep
//
//  Created by NIX on 15/4/30.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit

class ConversationTitleView: UIView {

    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .Center
        label.font = UIFont.systemFontOfSize(15, weight: UIFontWeightBold)
        return label
    }()

    lazy var stateInfoLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .Center
        label.font = UIFont.systemFontOfSize(10, weight: UIFontWeightLight)
        label.textColor = UIColor.grayColor()
        return label
    }()

    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        makeUI()
    }

    func makeUI() {
        addSubview(nameLabel)
        addSubview(stateInfoLabel)

        let helperView = UIView()

        addSubview(helperView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        stateInfoLabel.translatesAutoresizingMaskIntoConstraints = false

        helperView.translatesAutoresizingMaskIntoConstraints = false

        let viewsDictionary = [
            "nameLabel": nameLabel,
            "stateInfoLabel": stateInfoLabel,
            "helperView": helperView,
        ]
        
        helperView.centerXAnchor.constraintEqualToAnchor(centerXAnchor).active = true
        helperView.centerYAnchor.constraintEqualToAnchor(centerXAnchor).active = true
        helperView.topAnchor.constraintEqualToAnchor(nameLabel.topAnchor).active = true
        helperView.bottomAnchor.constraintEqualToAnchor(stateInfoLabel.bottomAnchor).active = true
        

        let constraintsV = NSLayoutConstraint.constraintsWithVisualFormat("V:[nameLabel(24)][stateInfoLabel(12)]", options: [.AlignAllCenterX, .AlignAllLeading, .AlignAllTrailing], metrics: nil, views: viewsDictionary)

        let constraintsH = NSLayoutConstraint.constraintsWithVisualFormat("H:|[nameLabel]|", options: [], metrics: nil, views: viewsDictionary)

        NSLayoutConstraint.activateConstraints(constraintsV)
        NSLayoutConstraint.activateConstraints(constraintsH)
    }
}

