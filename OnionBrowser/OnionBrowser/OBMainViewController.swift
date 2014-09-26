//  OnionBrowser
//  Copyright (c) 2014 Mike Tigas. All rights reserved; see LICENSE file.
//  https://mike.tig.as/onionbrowser/
//  https://github.com/mtigas/iOS-OnionBrowser

import UIKit
import WebKit

let TOOLBAR_HEIGHT : CGFloat = 44.0

class OBTab {
  var webView : WKWebView
  var URL : NSURL
  required init(webView inWebView: WKWebView, URL inURL: NSURL) {
    self.webView = inWebView
    self.URL = inURL
  }
}

class OBMainViewController: UIViewController {

  var tabs : NSMutableArray,
    toolbar : UIToolbar,
    pageTitle : UILabel,
    addressField: UITextField,
    currentTab : Int;

  override init() {
    self.tabs = NSMutableArray()
    self.toolbar = UIToolbar()
    self.pageTitle = UILabel()
    self.addressField = UITextField()
    self.currentTab = -1
    super.init()
  }

  required init(coder aCoder: NSCoder) {
    self.tabs = NSMutableArray()
    self.toolbar = UIToolbar()
    self.pageTitle = UILabel()
    self.addressField = UITextField()
    self.currentTab = -1
    super.init(coder: aCoder)
  }

  override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: NSBundle!) {
    self.tabs = NSMutableArray()
    self.toolbar = UIToolbar()
    self.pageTitle = UILabel()
    self.addressField = UITextField()
    self.currentTab = -1
    super.init(nibName:nibNameOrNil, bundle:nibBundleOrNil)
  }


  // MARK: -

  override func viewDidLoad() {
    var firstTab = OBTab(
      webView: WKWebView(frame:self.view.frame),
      URL: NSURL(string:"https://check.torproject.org/")
    )
    self.tabs.addObject(firstTab);
    self.currentTab = 0
    self.view.addSubview(firstTab.webView)
    self.view.bringSubviewToFront(firstTab.webView)

    var firstReq = NSURLRequest(URL:firstTab.URL)
    firstTab.webView.loadRequest(firstReq)

    self.toolbar.frame = CGRectMake(
      0, self.view.frame.height - TOOLBAR_HEIGHT,
      self.view.frame.width, TOOLBAR_HEIGHT
    )

    super.viewDidLoad()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

}
