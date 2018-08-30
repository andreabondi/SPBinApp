//
//  ViewController.swift
//  SPBinApp
//
//  Created by Bondi, Andrea on 28/08/2018.
//  Copyright © 2018 Bondi, Andrea. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import SafariServices
import NVActivityIndicatorView

class ViewController: UIViewController, SFSafariViewControllerDelegate, NVActivityIndicatorViewable {

    let customUrl = "uk.co.paypal.spbinapp"
    let host = "https://ppxoab.herokuapp.com"
    let appVersion = "0.1"

    @IBOutlet weak var pwppButton: UIImageView!
    @IBOutlet weak var pwCardsButton: UIImageView!
    
    var authSession: NSObject? = nil
    var url : URL? = nil

    var riskComponent: PPRiskComponent? = nil
    var spinnerControl: UIView? = nil
    var safariVC: SFSafariViewController? = nil
    var token: String! = nil
    var checkoutFlow: Payment? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // These two lines enable the debug mode for Magnes risk library, comment before production
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "dyson.debug.mode")
        
        let pwppTap = UITapGestureRecognizer(target: self, action: #selector(prepareForPwppCheckout))
        pwppButton.addGestureRecognizer(pwppTap)
        
        let cardsTap = UITapGestureRecognizer(target: self, action: #selector(prepareForCardsCheckout))
        pwCardsButton.addGestureRecognizer(cardsTap)
        
        NotificationCenter.default.addObserver(self, selector: #selector(executeFromSVC(notification:)), name: .complete , object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(cancelTransactionFromSVC(notification:)), name: .cancel , object: nil)

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func prepareForPwppCheckout(recognizer: UITapGestureRecognizer){
        print("PwPP Tapped")
        getToken(type: Payment.paypal)
    }
    
    @objc func prepareForCardsCheckout(recognizer: UITapGestureRecognizer){
        print("Cards Tapped")
        getToken(type: Payment.cards)
    }
    
    // Call your servers to retrieve an EC token. Here you can pass to your server also any additional details for the transaction e.g. the amount
    
    func getToken(type: Payment) {
        let size = CGSize(width: 30, height: 30)
        startAnimating(size, message: "Retrieving EC token...", type: NVActivityIndicatorType(rawValue: 16)!, fadeInAnimation: nil)
        
        Alamofire.request(host + "/tokenPwPP", method: .post).responseJSON{response in
            if let result = response.result.value{
                let json = JSON(result)
                self.token = json["TOKEN"].string!
                print(self.token)
                _ = self.sendSecurityPayload(token: self.token)
                self.stopAnimating()
                self.checkoutFlow = type
                if(type == Payment.paypal){
                    self.startCheckoutForPwpp(token: self.token)
                } else {
                    self.startCheckoutForCards(token: self.token)
                }
            }
        }
    }
    
    // Upload Magnes risk payload using the EC token as pairing id
    
    func sendSecurityPayload(token: String) -> String{
        var resultingPairingId = token
        let additionalParams: Dictionary = [kRiskManagerPairingId: token]
        if(self.riskComponent == nil){
            self.riskComponent = PPRiskComponent.initWith(PPRiskSourceAppUnknown, withSourceAppVersion: appVersion, withAdditionalParams: additionalParams)
        } else {
            resultingPairingId = PPRiskComponent.shared().generatePairingId(token)
        }
        return resultingPairingId
    }

    /*
     Open the PayPal redirect. For iOS 9,10 use SFSafariViewController, while for iOS 11 use SFAuthenticationSession.
     iOS 12 will deprecate SFAuthenticationSession replacing it with ASWebAuthenticationSession which will provide similar functionalities and APIs.
     After confirmation, PayPal will return to RETURN_URL (or CANCEL_URL) that will map to the Custom URL of the mobile app.
     For SFSafariViewController this return is handled from the main AppDelegate open(url) function, otherwise the behaviour is specified in the completionHandler
    */

    func startCheckoutForPwpp(token: String){
        let checkoutString = "https://www.sandbox.paypal.com/checkoutnow?useraction=commit&token=" + token
        let url = URL(string: checkoutString)
        if #available(iOS 11, *) {
            authSession = SFAuthenticationSession(url: url!, callbackURLScheme: customUrl, completionHandler: { (callback: URL?, error: Error?) in
                guard error == nil, let successURL = callback else {
                    print(error!)
                    self.cancelTransaction(token: token)
                    return
                }
                print(successURL)
                if(successURL.host == "success"){
                    let token = getQueryStringParameter(url: successURL.absoluteString, param: "token")
                    let payerID = getQueryStringParameter(url: successURL.absoluteString, param: "payerID")
                    self.executePayment(token: token!, payerID: payerID!)
                }
                else if(successURL.host == "cancel"){
                    let token = getQueryStringParameter(url:successURL.absoluteString, param: "token")
                    self.cancelTransaction(token: token!)
                }
            })
            (authSession as! SFAuthenticationSession).start()
        } else {
            safariVC = SFSafariViewController(url: url!)
            self.present(safariVC!, animated: true, completion: nil)
            safariVC!.delegate = self
        }
    }
    
    /*
     Open the page to load SmartPaymentButton component. The page should be opened inside a SFSafariViewController for iOS > 11,]
     while for previous iOS versions should use a WKWebView. The reason is that checkout.js relies on opening new tabs, which isn't supported
     in older versions of SFSafariViewController.
     The return flow will be handled similarly to the normal PayPal flow, using the Custom URL
    */
    
    func startCheckoutForCards(token: String){
        let checkoutString = "https://ppxoab.herokuapp.com/testSPBinApp.html?token=" + token
        url = URL(string: checkoutString)
        
        // Pre-iOS 11 SVC don't support opening new tabs
        if #available(iOS 11, *) {
            let safariVC = SFSafariViewController(url: url!)
            self.present(safariVC, animated: true, completion: nil)
            safariVC.delegate = self
        } else {
            performSegue(withIdentifier: "ShowWkWebView", sender: self)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowWkWebView" {
            let destination = segue.destination as! SPBWkWebViewController
            destination.loadUrl(url: url!)
        }
    }
    
    // Dismiss the current view and execute the payment. Called using Notification Center
    
    @objc func executeFromSVC(notification: NSNotification) {
        if #available(iOS 11, *) {
            self.dismiss(animated: true, completion: nil)
        } else {
            // PayPal flow will load on a SFSafariViewController, so dismiss
            if(checkoutFlow == Payment.paypal){
                self.dismiss(animated: true, completion: nil)
            }else if checkoutFlow == Payment.cards{
                navigationController?.popViewController(animated: true)
            }
        }
        executePayment(token: notification.userInfo?["token"] as! String, payerID: notification.userInfo?["payerID"] as! String)
    }

    // Dismiss the current view and cancel the flow. Called using Notification Center
    
    @objc func cancelTransactionFromSVC(notification: NSNotification) {
        if #available(iOS 11, *) {
            self.dismiss(animated: true, completion: nil)
        } else {
            navigationController?.popViewController(animated: true)
        }
        let token = notification.userInfo?["token"] as! String
        cancelTransaction(token: token)
    }
    
    // Just show an alert with the cancelled transaction token
    
    func cancelTransaction(token: String){
        let message = "Transaction cancelled by user.\nToken: \(token)"
        let alertController = UIAlertController(title: "Transaction cancelled!", message: message, preferredStyle: UIAlertControllerStyle.alert)
        alertController.addAction(UIAlertAction(title: "Copy & Dismiss", style: UIAlertActionStyle.default,handler: { (self) in
            UIPasteboard.general.string = message
        }))
        alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default,handler: nil))
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    // Call the server-side API to execute the transaction, sending the required parameters to your backend servers
    
    func executePayment(token: String, payerID: String){
        let size = CGSize(width: 30, height: 30)
        startAnimating(size, message: "Executing payment...", type: NVActivityIndicatorType(rawValue: 16)!, fadeInAnimation: nil)
        
        let parameters: Parameters = ["token": token, "payerID": payerID]
        Alamofire.request(host + "/execute", method: .post, parameters: parameters).responseJSON { response in
            if let result = response.result.value{
                print(result)
                let json = JSON(result)
                if (json["ACK"].string == "Success" && json["PAYMENTINFO_0_PAYMENTSTATUS"] == "Completed"){
                    let message = "Token: \(json["TOKEN"].string!)\nTransaction ID: \(json["PAYMENTINFO_0_TRANSACTIONID"].string!)\nCorrelation ID: \(json["CORRELATIONID"].string!)"
                    let alertController = UIAlertController(title: "Payment completed!", message: message, preferredStyle: UIAlertControllerStyle.alert)
                    alertController.addAction(UIAlertAction(title: "Copy & Dismiss", style: UIAlertActionStyle.default,handler: { (self) in
                        UIPasteboard.general.string = message
                    }))
                    alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default,handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                } else if (json["ACK"].string == "Failure"){
                    let message = "Token: \(json["TOKEN"].string!)\nError code: \(json["L_ERRORCODE0"].string!)\nCorrelation ID: \(json["CORRELATIONID"].string!)"
                    let alertController = UIAlertController(title: "Transaction failed!", message: message, preferredStyle: UIAlertControllerStyle.alert)
                    alertController.addAction(UIAlertAction(title: "Copy & Dismiss", style: UIAlertActionStyle.default,handler: { (self) in
                        UIPasteboard.general.string = message
                    }))
                    alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default,handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                }
                self.stopAnimating()
            }
        }
    }
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController)
    {
        controller.dismiss(animated: true, completion: nil)
    }
}
