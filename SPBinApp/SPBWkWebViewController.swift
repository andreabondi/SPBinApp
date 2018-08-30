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
    
    @IBOutlet weak var checkoutWebView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let webView = WKWebView(frame: .zero)

        let request = URLRequest(url: url!)
        webView.navigationDelegate = self

        checkoutWebView.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        let height = NSLayoutConstraint(item: webView, attribute: .height, relatedBy: .equal, toItem: checkoutWebView, attribute: .height, multiplier: 1, constant: 0)
        let width = NSLayoutConstraint(item: webView, attribute: .width, relatedBy: .equal, toItem: checkoutWebView, attribute: .width, multiplier: 1, constant: 0)
        view.addConstraints([height, width])
        
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
