//  OnionBrowser
//  Copyright (c) 2014 Mike Tigas. All rights reserved; see LICENSE file.
//  https://mike.tig.as/onionbrowser/
//  https://github.com/mtigas/iOS-OnionBrowser

import UIKit
import WebKit

// UI
let TOOLBAR_HEIGHT:CGFloat = 44.0 // default size
let NAVBAR_HEIGHT:CGFloat = 64.0  // default size

// UI: Toolbar
let ADDRESSBAR_TAG:Int = 2001
let ADDRESSLABEL_TAG:Int = 2002
let FORWARDBUTTON_TAG:Int = 2003
let BACKWARDBUTTON_TAG:Int = 2004


// Container for info associated with an open tab.
class OBTab {
  var webView : WKWebView
  var URL : NSURL

  required init(webView inWebView: WKWebView, URL inURL: NSURL) {
    self.webView = inWebView
    self.URL = inURL
  }
}



class OBMainViewController: UIViewController, UIScrollViewDelegate, UITextFieldDelegate {
  var tabs = Array<OBTab>()
  var navbar = UINavigationBar()
  var toolbar = UIToolbar()
  var currentTab = -1
  var lastTypedAddress = ""
  var previousScrollViewYOffset:CGFloat = 0.0

  func initNewTab(tab:OBTab) {
    self.currentTab += 1
    tab.webView.autoresizingMask = UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleHeight
    tab.webView.scrollView.contentInset = UIEdgeInsetsMake(NAVBAR_HEIGHT, 0, TOOLBAR_HEIGHT, 0)
    tab.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(NAVBAR_HEIGHT, 0, TOOLBAR_HEIGHT, 0)
    tab.webView.scrollView.delegate = self
    self.tabs.append(tab)
  }

  override func viewDidLoad() {
    /********** Set up initial web view **********/
    self.lastTypedAddress = "https://check.torproject.org/"
    let firstTab:OBTab = OBTab(
      webView: WKWebView(frame:self.view.frame),
      URL: NSURL(string:self.lastTypedAddress)!
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
    address.clearButtonMode = .Never
    address.tag = ADDRESSBAR_TAG
    address.delegate = self

    address .addTarget(self, action: "loadAddress:event:", forControlEvents: UIControlEvents.EditingDidEndOnExit|UIControlEvents.EditingDidEnd)
    self.navbar.addSubview(address)
    address.enabled = true

    var addressLabel:UILabel = UILabel(frame: CGRectMake(10, 25, self.view.frame.width-20, NAVBAR_HEIGHT-35))
    addressLabel.font = UIFont.systemFontOfSize(17)
    addressLabel.tag = ADDRESSLABEL_TAG
    addressLabel.text = firstTab.URL.host
    addressLabel.textAlignment = NSTextAlignment.Center
    addressLabel.userInteractionEnabled = true
    addressLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "pushAddressBar"))
    self.navbar.addSubview(addressLabel)

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
    var addressLabel:UILabel = self.navbar.viewWithTag(ADDRESSLABEL_TAG) as UILabel

    if ((!addressLabel.hidden) && (addressLabel.alpha == 1.0)) {
      UIView.animateWithDuration(
        0.1,
        animations:{() -> Void in
          addressLabel.alpha = 0.0},
        completion:{(success:Bool) -> Void in
          addressLabel.hidden = true
      })
    }
    address.becomeFirstResponder()
  }
  func textFieldDidBeginEditing(textField: UITextField) {
    if (textField.tag == ADDRESSBAR_TAG) {
      let addressLabel:UILabel = self.navbar.viewWithTag(ADDRESSLABEL_TAG) as UILabel
      if ((!addressLabel.hidden) && (addressLabel.alpha == 1.0)) {
        UIView.animateWithDuration(
          0.1,
          animations:{() -> Void in
            addressLabel.alpha = 0.0},
          completion:{(success:Bool) -> Void in
            addressLabel.hidden = true
        })
      }

      let tab:OBTab = self.tabs[self.currentTab]
      textField.text = tab.URL.absoluteString
      textField.selectAll(nil)
    }
  }
  func textFieldShouldEndEditing(textField: UITextField) -> Bool {
    if (textField.tag == ADDRESSBAR_TAG) {
      var addressLabel:UILabel = self.navbar.viewWithTag(ADDRESSLABEL_TAG) as UILabel
      self.lastTypedAddress = textField.text
      textField.text = ""
      addressLabel.hidden = false
      if ((addressLabel.hidden) || (addressLabel.alpha != 1.0)) {
        UIView.animateWithDuration(
          0.1,
          animations:{() -> Void in
            addressLabel.alpha = 1.0
        })
      }
    }
    return true
  }
  func textFieldShouldReturn(textField: UITextField) -> Bool {
    if (textField.tag == ADDRESSBAR_TAG) {
      textField.autocorrectionType = UITextAutocorrectionType.No
      textField.resignFirstResponder()
    }
    return true
  }

  func loadAddress(sender:AnyObject, event:UIEvent?) {
    let address:UITextField = self.navbar.viewWithTag(ADDRESSBAR_TAG) as UITextField
    let addressLabel:UILabel = self.navbar.viewWithTag(ADDRESSLABEL_TAG) as UILabel
    let tab:OBTab = self.tabs[self.currentTab]

    tab.URL = NSURL(string: self.lastTypedAddress)!
    tab.webView.loadRequest(NSURLRequest(URL:tab.URL))
    addressLabel.text = tab.URL.host
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

    let tab:OBTab = self.tabs[self.currentTab]
    if (scrollOffset <= -scrollView.contentInset.top) {
      // we've pulled down far enough, this is the normal expanded state
      //NSLog("a: scrollOffset:%@ -- scrollView.contentInset.top:%@ -- scrollHeight:%@ -- scrollContentSizeHeight:%@", scrollOffset, scrollView.contentInset.top, scrollHeight, scrollContentSizeHeight)
      frame.origin.y = 0
      tab.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(NAVBAR_HEIGHT, 0, TOOLBAR_HEIGHT, 0)
    } else if ((scrollOffset + scrollHeight) >= scrollContentSizeHeight) {
      // opposite: hidden state
      //NSLog("b: scrollOffset:%@ -- scrollView.contentInset.top:%@ -- scrollHeight:%@ -- scrollContentSizeHeight:%@", scrollOffset, scrollView.contentInset.top, scrollHeight, scrollContentSizeHeight)
      frame.origin.y = -size
      tab.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(NAVBAR_HEIGHT+frame.origin.y, 0, TOOLBAR_HEIGHT, 0)
    } else {
      //NSLog("c: scrollOffset:%@ -- scrollView.contentInset.top:%@ -- scrollHeight:%@ -- scrollContentSizeHeight:%@", scrollOffset, scrollView.contentInset.top, scrollHeight, scrollContentSizeHeight)
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
    if (!decelerate) {
      self.stoppedScrolling()
    }
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
