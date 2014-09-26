//  OnionBrowser
//  Copyright (c) 2014 Mike Tigas. All rights reserved; see LICENSE file.
//  https://mike.tig.as/onionbrowser/
//  https://github.com/mtigas/iOS-OnionBrowser

import UIKit
import WebKit

let TOOLBAR_HEIGHT : CGFloat = 44.0

class OBMainViewController: UIViewController {

    var tabs : NSMutableArray,
        toolbar : UIToolbar,
        pageTitle : UILabel,
        addressField: UITextField,
        currentURL : NSURL;

    required init(coder aDecoder: NSCoder) {
        self.tabs = NSMutableArray()
        self.toolbar = UIToolbar()
        self.pageTitle = UILabel()
        self.addressField = UITextField()
        self.currentURL = NSURL(string:"https://check.torproject.org/")

        super.init()
    }

    override func viewDidLoad() {
        var config = WKWebViewConfiguration()
        var firstWebView = WKWebView(frame:self.view.frame, configuration:config)

        self.toolbar.frame = CGRectMake(
            0, self.view.frame.height - TOOLBAR_HEIGHT,
            self.view.frame.width, TOOLBAR_HEIGHT
        )

        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue!, sender: AnyObject!) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
