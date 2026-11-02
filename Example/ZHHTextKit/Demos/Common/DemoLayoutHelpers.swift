//
//  DemoLayoutHelpers.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

func pinToSafeArea(_ child: UIView, in controller: UIViewController) {
    child.translatesAutoresizingMaskIntoConstraints = false
    controller.view.addSubview(child)
    NSLayoutConstraint.activate([
        child.topAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.topAnchor),
        child.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor),
        child.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor),
        child.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor)
    ])
}

func rgb(_ hex: UInt32) -> UIColor {
    UIColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

func shadow(color: UIColor, x: CGFloat, y: CGFloat, radius: CGFloat) -> NSShadow {
    let item = NSShadow()
    item.shadowColor = color
    item.shadowOffset = CGSize(width: x, height: y)
    item.shadowBlurRadius = radius
    return item
}

/// 编辑区用的胶囊附件：一个字符，退格天然整颗删除。
/// 标记编辑区胶囊附件（U+FFFC），退格时整颗删。
