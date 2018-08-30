//
//  SPBWebViewController.swift
//  SPBinApp
//
//  Created by Bondi, Andrea on 29/08/2018.
//  Copyright © 2018 Bondi, Andrea. All rights reserved.
//

import Foundation
import UIKit
import WebKit

class SPBWkWebViewController: UIViewController, WKNavigationDelegate {
    var url: URL? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let navigationBar = UINavigationBar()
        navigationBar.barTintColor = UIColor.lightGray
        navigationBar.isTranslucent = false
//        navigationBar.delegate = self
        navigationBar.backgroundColor = .white


        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: nil)

        let navigationItem = UINavigationItem(title: "Checkout with cards")
        navigationItem.rightBarButtonItem = cancelButton

        navigationBar.items = [navigationItem]
        
        view.addSubview(navigationBar)

        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        navigationBar.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        navigationBar.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        
        if #available(iOS 11, *) {
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        } else {
            navigationBar.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor).isActive = true
        }
        
        let screenSize: CGRect = UIScreen.main.bounds
        let webView = WKWebView(frame: CGRect(x: 0, y: 72, width: screenSize.width, height: screenSize.height-72))

        let request = URLRequest(url: url!)
        webView.navigationDelegate = self

        view.addSubview(webView)
        webView.load(request)

    }
    
    func loadUrl(url: URL){
        self.url = url
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        var action: WKNavigationActionPolicy?
        
        defer {
            decisionHandler(action ?? .allow)
        }
        
        guard let url = navigationAction.request.url else { return }
        
        print(url)
        
        if (url.scheme == "uk.co.paypal.spbinapp"){
            if(url.host == "success"){
                print("returning with url: " + url.absoluteString)
                let token = getQueryStringParameter(url: url.absoluteString, param: "token")
                let payerID = getQueryStringParameter(url: url.absoluteString, param: "payerID")
                let nc = NotificationCenter.default
                nc.post(name: .complete, object: nil, userInfo: ["token": token!, "payerID": payerID!])
            } else if(url.host == "cancel"){
                print("returning with url: " + url.absoluteString)
                let token = getQueryStringParameter(url: url.absoluteString, param: "token")
                let nc = NotificationCenter.default
                nc.post(name: .cancel, object: nil, userInfo: ["token": token!])
            }

        }
    }
}
