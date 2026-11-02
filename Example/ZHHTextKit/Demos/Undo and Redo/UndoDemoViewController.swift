//
//  UndoDemoViewController.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

final class UndoDemoViewController: UIViewController {
    private let viewModel = UndoDemoViewModel()
    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "重做", style: .plain, target: self, action: #selector(redo)),
            UIBarButtonItem(title: "撤销", style: .plain, target: self, action: #selector(undo))
        ]
        textView.font = UIFont.systemFont(ofSize: 18)
        textView.text = "可以摇一摇撤销和重做，也可以点右上角的按钮。\nYou can shake the device to undo and redo."
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        pinToSafeArea(textView, in: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }

    @objc private func undo() {
        textView.becomeFirstResponder()
        textView.undoManager?.undo()
    }

    @objc private func redo() {
        textView.becomeFirstResponder()
        textView.undoManager?.redo()
    }
}

/// 汉字假名注音示例。
