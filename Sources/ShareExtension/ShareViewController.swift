//
//  ShareViewController.swift
//  ShareExtension
//
//  Entry point for the Share Extension. Presents a SwiftUI ShareView
//  hosted inside a UIHostingController with the shared container injected.
//

import UIKit
import SwiftUI
import SwiftData

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create the SwiftUI view and inject the shared container.
        let shareView = ShareView(
            extensionContext: extensionContext,
            onComplete: { [weak self] in
                self?.extensionContext?.completeRequest(
                    returningItems: nil,
                    completionHandler: nil
                )
            }
        )
        .modelContainer(SharedDataManager.shared.container)

        let hostingController = UIHostingController(rootView: shareView)
        addChild(hostingController)
        view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        hostingController.didMove(toParent: self)
    }
}
