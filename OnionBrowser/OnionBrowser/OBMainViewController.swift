//  OnionBrowser
//  Copyright (c) 2014 Mike Tigas. All rights reserved; see LICENSE file.
//  https://mike.tig.as/onionbrowser/
//  https://github.com/mtigas/iOS-OnionBrowser

import UIKit

// UI
let TOOLBAR_HEIGHT:CGFloat = 44.0 // default size
let NAVBAR_HEIGHT:CGFloat = 64.0  // default size

// UI: Toolbar
let ADDRESSBAR_TAG:Int = 2001
let FORWARDBUTTON_TAG:Int = 2003
let BACKWARDBUTTON_TAG:Int = 2004


// Container for info associated with an open tab.
class OBTab {
  var webView : UIWebView
  var URL : NSURL

  required init(webView inWebView: UIWebView, URL inURL: NSURL) {
    self.webView = inWebView
    self.URL = inURL
  }
}



class OBMainViewController: UIViewController, UITextFieldDelegate, UIWebViewDelegate, NJKWebViewProgressDelegate {
  var tabs = Array<OBTab>()
  var navbar = UINavigationBar()
  var toolbar = UIToolbar()
  var currentTab = -1
  var addressBarIsSubmitting = false
  var progressView : NJKWebViewProgressView?
  var progressProxy : NJKWebViewProgress?


  func initNewTab(tab:OBTab) {
    self.currentTab += 1
    tab.webView.autoresizingMask = UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleHeight
    tab.webView.scrollView.contentInset = UIEdgeInsetsMake(NAVBAR_HEIGHT, 0, TOOLBAR_HEIGHT, 0)
    tab.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(NAVBAR_HEIGHT, 0, TOOLBAR_HEIGHT, 0)
    self.tabs.append(tab)
  }

  override func viewDidLoad() {
    /********** Set up initial web view **********/
    let firstTab:OBTab = OBTab(
      webView: UIWebView(frame:self.view.frame),
      URL: NSURL(string:"https://check.torproject.org/")!
    )

    initNewTab(firstTab)
    self.view.addSubview(firstTab.webView)
    firstTab.webView.loadRequest(NSURLRequest(URL:firstTab.URL))

    /********** Initialize Navbar **********/
    self.navbar.frame = CGRectMake(0, 0, self.view.frame.width, NAVBAR_HEIGHT)
    self.navbar.autoresizingMask = UIViewAutoresizing.FlexibleWidth

    var address:UITextField = UITextField(frame: CGRectMake(10, 25, self.view.frame.width-20, NAVBAR_HEIGHT-35))
    address.autoresizingMask = .FlexibleWidth
    address.borderStyle = .RoundedRect
    address.backgroundColor = UIColor(white:0.9, alpha:1.0)
    address.font = .systemFontOfSize(17)
    address.keyboardType = .URL
    address.returnKeyType = .Go
    address.autocorrectionType = .No
    address.autocapitalizationType = .None
    //address.clearButtonMode = .Never
    address.tag = ADDRESSBAR_TAG
    address.delegate = self
    address.text = firstTab.URL.absoluteString

    address.addTarget(self, action: "loadAddressBar:event:", forControlEvents: UIControlEvents.EditingDidEnd|UIControlEvents.EditingDidEndOnExit)
    self.navbar.addSubview(address)
    address.enabled = true

    var progressBarHeight:CGFloat = 2.0;
    var barFrame:CGRect = CGRectMake(0, self.navbar.bounds.size.height - progressBarHeight,
        self.navbar.bounds.size.width, progressBarHeight);

    progressView = NJKWebViewProgressView(frame: barFrame);
    progressView?.autoresizingMask = UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleTopMargin;
    progressView?.setProgress(1.0, animated: true);
    self.navbar.addSubview(progressView!)
    self.navbar.bringSubviewToFront(progressView!)

    progressProxy = NJKWebViewProgress()
    firstTab.webView.delegate = progressProxy;
    progressProxy?.webViewProxyDelegate = self;
    progressProxy?.progressDelegate = self;

    self.view.addSubview(self.navbar)
    self.view.bringSubviewToFront(self.navbar)

    /********** Initialize Toolbar **********/
    self.toolbar.frame = CGRectMake(
      0, self.view.frame.height - TOOLBAR_HEIGHT,
      self.view.frame.width, TOOLBAR_HEIGHT
    )
    self.toolbar.autoresizingMask = UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleTopMargin

    var space:UIBarButtonItem          = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FlexibleSpace, target: nil, action: nil)
    var backButton:UIBarButtonItem     = UIBarButtonItem(image: self.forwardBackButtonImage(BACKWARDBUTTON_TAG), style: UIBarButtonItemStyle.Plain, target: nil, action: nil) // TODO
    var forwardButton:UIBarButtonItem  = UIBarButtonItem(image: self.forwardBackButtonImage(FORWARDBUTTON_TAG), style: UIBarButtonItemStyle.Plain, target: nil, action: nil) // TODO
    var toolButton:UIBarButtonItem     = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Action, target: self, action: "openToolMenu") // TODO
    var bookmarkButton:UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Bookmarks, target: nil, action: nil) // TODO
    var tabsButton:UIBarButtonItem     = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Organize, target: nil, action: nil) // TODO

    backButton.enabled = true
    forwardButton.enabled = true
    toolButton.enabled = true
    bookmarkButton.enabled = true
    tabsButton.enabled = true

    var toolbarItems:Array = [backButton, space, forwardButton, space, toolButton, space, bookmarkButton, space, tabsButton]
    self.toolbar.setItems(toolbarItems, animated: false)

    self.toolbar.alpha = 1.0
    self.toolbar.tintColor = self.toolbar.tintColor.colorWithAlphaComponent(1.0)

    self.view.addSubview(self.toolbar)
    self.view.bringSubviewToFront(self.toolbar)

    super.viewDidLoad()
  }

  override func supportedInterfaceOrientations() -> Int {
    if (UIDevice.currentDevice().userInterfaceIdiom == .Pad) {
      return Int(UIInterfaceOrientationMask.All.rawValue)
    } else {
      return Int(UIInterfaceOrientationMask.AllButUpsideDown.rawValue)
    }
  }


  func forwardBackButtonImage(whichButton:Int) -> UIImage {
    // Draws the vector image for the forward or back button. (see kForwardButton
    // and kBackwardButton for the "whichButton" values)
    var scale:CGFloat = UIScreen.mainScreen().scale
    var size:UInt = UInt(round(30.0 * Float(scale)))
    var context:CGContextRef = CGBitmapContextCreate(
      nil,
      size, size,
      8,0,
      CGColorSpaceCreateDeviceRGB(),
      CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue)
    )


    var color:CGColorRef = UIColor.blackColor().CGColor
    //CGContextSetFillColor(context, CGColorGetComponents(color))
    CGContextSetStrokeColorWithColor(context, color);

    CGContextSetLineWidth(context, 3.0);

    CGContextBeginPath(context)
    if (whichButton == FORWARDBUTTON_TAG) {
        CGContextMoveToPoint(context, CGFloat(5.0)*scale, CGFloat(4.0)*scale)
        CGContextAddLineToPoint(context, CGFloat(15.0)*scale, CGFloat(15.0)*scale)
        CGContextAddLineToPoint(context, CGFloat(5.0)*scale, CGFloat(24.0)*scale)
    } else {
        CGContextMoveToPoint(context, CGFloat(15.0)*scale, CGFloat(4.0)*scale)
        CGContextAddLineToPoint(context, CGFloat(5.0)*scale, CGFloat(14.0)*scale)
        CGContextAddLineToPoint(context, CGFloat(15.0)*scale, CGFloat(24.0)*scale)
    }
    CGContextStrokePath(context);
    //CGContextClosePath(context)
    //CGContextFillPath(context)

    var theCGImage:CGImageRef = CGBitmapContextCreateImage(context)
    return UIImage(CGImage:theCGImage, scale:scale, orientation:UIImageOrientation.Up)!
  }


  // MARK: - Address bar
  func pushAddressBar() {
    var address:UITextField = self.navbar.viewWithTag(ADDRESSBAR_TAG) as UITextField
    address.becomeFirstResponder()
  }
  func textFieldDidBeginEditing(textField: UITextField) {
    if (textField.tag == ADDRESSBAR_TAG) {
      let tab:OBTab = self.tabs[self.currentTab]
      textField.text = tab.URL.absoluteString
      textField.selectAll(nil)
    }
  }
  func textFieldShouldReturn(textField: UITextField) -> Bool {
    if (textField.tag == ADDRESSBAR_TAG) {
      addressBarIsSubmitting = true
      textField.autocorrectionType = UITextAutocorrectionType.No
      textField.resignFirstResponder()
    }
    return true
  }

  func loadAddressBar(sender:AnyObject, event:UIEvent?) {
    let address:UITextField = self.navbar.viewWithTag(ADDRESSBAR_TAG) as UITextField
    let tab:OBTab = self.tabs[self.currentTab]

    if (addressBarIsSubmitting) {
      addressBarIsSubmitting = false
      tab.URL = NSURL(string: address.text)!
      if(tab.URL.scheme == nil) {
        let newUrl = String(format:"http://%@", address.text)
        tab.URL = NSURL(string: newUrl)!
        address.text = tab.URL.absoluteString
    }


      tab.webView.loadRequest(NSURLRequest(URL:tab.URL))
    } else {
      // actually, we're canceling
      address.text = tab.URL.absoluteString
    }
  }


  // MARK: - Menu
  func openToolMenu() {
    let tab:OBTab = self.tabs[self.currentTab]
    let activityViewController:UIActivityViewController = UIActivityViewController(activityItems: [tab.URL.absoluteString!], applicationActivities: nil)
    self.presentViewController(activityViewController, animated: true, completion: nil)
    if (activityViewController.respondsToSelector("popoverPresentationController")) {
      activityViewController.popoverPresentationController?.sourceView = self.view
    }
  }

  //MARK: - Progress
  func webViewDidStartLoad(webView: UIWebView) {
    UIApplication.sharedApplication().networkActivityIndicatorVisible = true;
  }
  func webViewDidFinishLoad(webView: UIWebView) {
    UIApplication.sharedApplication().networkActivityIndicatorVisible = false;
  }
  func webViewProgress(webViewProgress: NJKWebViewProgress!, updateProgress progress: Float) {
    progressView?.setProgress(progress, animated: true);
  }
}
