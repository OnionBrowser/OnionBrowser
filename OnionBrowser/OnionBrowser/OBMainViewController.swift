//  OnionBrowser
//  Copyright (c) 2014 Mike Tigas. All rights reserved; see LICENSE file.
//  https://mike.tig.as/onionbrowser/
//  https://github.com/mtigas/iOS-OnionBrowser

import UIKit
import WebKit

let TOOLBAR_HEIGHT:CGFloat = 44.0 // default size
let NAVBAR_HEIGHT:CGFloat = 64.0  // default size
let ADDRESSBAR_TAG:Int = 2001
let ADDRESSLABEL_TAG:Int = 2002



class OBTab {
  var webView : WKWebView
  var URL : NSURL

  required init(webView inWebView: WKWebView, URL inURL: NSURL) {
    self.webView = inWebView
    self.URL = inURL
  }
}



class OBMainViewController: UIViewController, UIScrollViewDelegate {
  var
    tabs:NSMutableArray = NSMutableArray(),
    navbar:UINavigationBar = UINavigationBar(),
    toolbar:UIToolbar = UIToolbar(),
    currentTab:Int = -1,

    previousScrollViewYOffset:CGFloat = 0.0
  ;

  override init() {
    super.init()
  }

  required init(coder aCoder: NSCoder) {
    super.init(coder: aCoder)
  }

  override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: NSBundle!) {
    super.init(nibName:nibNameOrNil, bundle:nibBundleOrNil)
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }

  override func supportedInterfaceOrientations() -> Int {
    if (UIDevice.currentDevice().userInterfaceIdiom == .Pad) {
      return Int(UIInterfaceOrientationMask.All.toRaw())
    } else {
      return Int(UIInterfaceOrientationMask.AllButUpsideDown.toRaw())
    }
  }


  // MARK: -

  override func viewDidLoad() {
    /********** Set up initial web view **********/
    var firstTab = OBTab(
      webView: WKWebView(frame:self.view.frame),
      URL: NSURL(string:"https://check.torproject.org/")
    )
    self.tabs.addObject(firstTab)
    self.currentTab = 0
    firstTab.webView.autoresizingMask = UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleHeight
    firstTab.webView.scrollView.contentInset = UIEdgeInsetsMake(NAVBAR_HEIGHT, 0, TOOLBAR_HEIGHT, 0)
    firstTab.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(NAVBAR_HEIGHT, 0, TOOLBAR_HEIGHT, 0)
    firstTab.webView.scrollView.delegate = self
    self.view.addSubview(firstTab.webView)

    // Fire off request
    var firstReq = NSURLRequest(URL:firstTab.URL)
    firstTab.webView.loadRequest(firstReq)


    /********** Initialize Navbar **********/
    self.navbar.frame = CGRectMake(0, 0, self.view.frame.width, NAVBAR_HEIGHT)
    self.navbar.autoresizingMask = UIViewAutoresizing.FlexibleWidth

    var address:UITextField = UITextField(frame: CGRectMake(10, 25, self.view.frame.width-20, NAVBAR_HEIGHT-35))
    address.autoresizingMask = UIViewAutoresizing.FlexibleWidth
    address.borderStyle = UITextBorderStyle.RoundedRect
    address.backgroundColor = UIColor(white:0.9, alpha:1.0)
    address.font = UIFont.systemFontOfSize(17)
    address.keyboardType = UIKeyboardType.URL
    address.returnKeyType = UIReturnKeyType.Go
    address.autocorrectionType = UITextAutocorrectionType.No
    address.autocapitalizationType = UITextAutocapitalizationType.None
    address.clearButtonMode = UITextFieldViewMode.Never
    address.tag = ADDRESSBAR_TAG
    // TODO: Catch address event
    self.navbar.addSubview(address)
    address.enabled = true

    var addressLabel:UILabel = UILabel(frame: CGRectMake(10, 25, self.view.frame.width-20, NAVBAR_HEIGHT-35))
    addressLabel.font = UIFont.systemFontOfSize(17)
    addressLabel.tag = ADDRESSLABEL_TAG
    addressLabel.text = "check.torproject.org"
    addressLabel.textAlignment = NSTextAlignment.Center
    self.navbar.addSubview(addressLabel)


    self.view.addSubview(self.navbar)
    self.view.bringSubviewToFront(self.navbar)


    /********** Initialize Toolbar **********/
    self.toolbar.frame = CGRectMake(
      0, self.view.frame.height - TOOLBAR_HEIGHT,
      self.view.frame.width, TOOLBAR_HEIGHT
    )
    self.toolbar.autoresizingMask = UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleTopMargin
    self.view.addSubview(self.toolbar)
    self.view.bringSubviewToFront(self.toolbar)


    super.viewDidLoad()
  }

  // MARK: - Safari-like hiding navbar
  let STATUSBAR_SIZE:CGFloat = 20.0
  let COLLAPSED_SIZE:CGFloat = 20.0

  func scrollViewDidScroll(scrollView: UIScrollView) {
    var frame:CGRect = self.navbar.frame
    var size:CGFloat = frame.size.height - (STATUSBAR_SIZE + 1 + COLLAPSED_SIZE)
    var framePercentageHidden:CGFloat = ((STATUSBAR_SIZE - frame.origin.y) / (frame.size.height - 1))
    framePercentageHidden = (framePercentageHidden-(5/16))/(11/16)
    var scrollOffset:CGFloat = scrollView.contentOffset.y
    var scrollDiff:CGFloat = scrollOffset - self.previousScrollViewYOffset
    var scrollHeight:CGFloat = scrollView.frame.size.height
    var scrollContentSizeHeight:CGFloat = scrollView.contentSize.height + scrollView.contentInset.bottom

    var tab:OBTab = self.tabs.objectAtIndex(self.currentTab) as OBTab
    if (scrollOffset <= -scrollView.contentInset.top) {
      // we've pulled down far enough, this is the normal expanded state
      frame.origin.y = 0
      tab.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(NAVBAR_HEIGHT, 0, TOOLBAR_HEIGHT, 0)
    } else if ((scrollOffset + scrollHeight) >= scrollContentSizeHeight) {
      // opposite: hidden state
      frame.origin.y = -size
      tab.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(NAVBAR_HEIGHT+frame.origin.y, 0, TOOLBAR_HEIGHT, 0)
    } else {
      frame.origin.y = min(0, max(-size, frame.origin.y - scrollDiff))
      tab.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(NAVBAR_HEIGHT+frame.origin.y, 0, TOOLBAR_HEIGHT, 0)
    }

    self.navbar.frame = frame
    self.updateBarButtonItems(1 - framePercentageHidden)
    self.previousScrollViewYOffset = scrollOffset
  }
  func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
    self.stoppedScrolling()
  }
  func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if (!decelerate) { self.stoppedScrolling() }
  }
  func stoppedScrolling() {
    var frame:CGRect = self.navbar.frame
    if (frame.origin.y < 0) {
      self.animateNavBarTo(0 - (STATUSBAR_SIZE + 1 + COLLAPSED_SIZE))
    }
  }
  func updateBarButtonItems(scaleFactor:CGFloat) {
    var address:UITextField = self.navbar.viewWithTag(ADDRESSBAR_TAG) as UITextField
    var addressLabel:UILabel = self.navbar.viewWithTag(ADDRESSLABEL_TAG) as UILabel
    if (scaleFactor == 1) {
      address.hidden = false
      address.enabled = true
      address.frame = CGRectMake(10, 25, self.view.frame.width-20, NAVBAR_HEIGHT-35)
      address.alpha = 1

      addressLabel.hidden = false
      addressLabel.frame = CGRectMake(10, 25, self.view.frame.width-20, NAVBAR_HEIGHT-35)
    } else if (scaleFactor >= 0.5) {
      var height:CGFloat = (NAVBAR_HEIGHT-30)*scaleFactor
      var heightDiff:CGFloat = (NAVBAR_HEIGHT-30)-height
      var width:CGFloat = (self.view.frame.width-20)*scaleFactor
      var widthDiff:CGFloat = ((self.view.frame.width-20)-width)/2

      address.hidden = false
      address.enabled = true
      address.frame = CGRectMake(10+widthDiff, 25+heightDiff, width, height)
      address.alpha = (scaleFactor-0.5)/0.5

      addressLabel.hidden = false
      addressLabel.frame = CGRectMake(10+widthDiff, 25+heightDiff, width, height)
      addressLabel.font = UIFont.systemFontOfSize(round((17-9)*scaleFactor)+9)
    } else {
      var height:CGFloat = (NAVBAR_HEIGHT-30)*scaleFactor
      var heightDiff:CGFloat = (NAVBAR_HEIGHT-30)-height
      var width:CGFloat = (self.view.frame.width-20)*scaleFactor
      var widthDiff:CGFloat = ((self.view.frame.width-20)-width)/2

      address.hidden = true
      address.enabled = false

      addressLabel.hidden = false
      addressLabel.frame = CGRectMake(10+widthDiff, 25+heightDiff, width, height)
      addressLabel.font = UIFont.systemFontOfSize(round((17-9)*scaleFactor)+9)
    }
  }
  func animateNavBarTo(y:CGFloat) {
  /*
    UIView.animateWithDuration(0.2, animations:{() -> Void in
      var frame:CGRect = self.navbar.frame
      var scaleFactor:CGFloat = (frame.origin.y >= y ? 0 : 1)
      frame.origin.y = y
      self.navbar.frame = frame
      self.updateBarButtonItems(scaleFactor)
    })
  */
  }
}
