//
//  DemoBanner.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

enum DemoBanner {
    /// 在指定页面显示一条提示文案。
    /// - Parameters:
    ///   - message: 提示内容。
    ///   - controller: 宿主页面。
    static func show(_ message: String, in controller: UIViewController) {
        controller.view.viewWithTag(9001)?.removeFromSuperview()
        let label = UILabel()
        label.tag = 9001
        label.text = "  \(message)  "
        label.textAlignment = .center
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        label.font = UIFont.systemFont(ofSize: 15)
        label.numberOfLines = 2
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: controller.view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: controller.view.trailingAnchor, constant: -24),
            label.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
        UIView.animate(withDuration: 0.25, delay: 1.3, options: [], animations: {
            label.alpha = 0
        }, completion: { _ in
            label.removeFromSuperview()
        })
    }
}
