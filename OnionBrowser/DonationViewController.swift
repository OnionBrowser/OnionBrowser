/*
* Onion Browser
* Copyright (c) 2012-2019 Mike Tigas
*
* This file is part of Onion Browser. See LICENSE file for redistribution terms.
*/

import UIKit
import StoreKit

@objc public class DonationViewController: UITableViewController, SKProductsRequestDelegate, SKPaymentTransactionObserver
{
	
	/* Variables */
	let TIER_0_99 = "com.miketigas.onionbrowser.tip0_99"
	let TIER_4_99 = "com.miketigas.onionbrowser.tip4_99"
	let TIER_9_99 = "com.miketigas.onionbrowser.tip9_99"
	
	var product_to_pay:SKProduct?
	var productsRequest = SKProductsRequest()
	var iapProducts = [SKProduct]()
	
	
	convenience init() {
		self.init(style: UITableView.Style.grouped)
	}
	
	override public func viewDidLoad() {
		super.viewDidLoad()
		
		self.title = "Donate"
		self.navigationItem.leftBarButtonItem = UIBarButtonItem.init(title: "Done", style: .done, target: self, action: #selector(self.dismissView))
		
		fetchAvailableProducts()
	}

	override public func numberOfSections(in tableView: UITableView) -> Int {
		if (iapProducts.isEmpty) {
			return 1
		} else {
			return 4
		}
	}
	
	override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if (section == 1 || section == 2 || section == 3) {
			return 1
		} else {
			return 0
		}
	}
	
	override public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String {
		var msg:String
		if (section == 0) {
			msg = "SUPPORT ONION BROWSER DEVELOPMENT"
		} else {
			msg = ""
		}
		return msg
	}
	override public func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String {
		var msg:String
		if (section == 0) {
			msg = "Onion Browser is a free app, but it takes time and resources to develop and maintain.\n\nYou can support the app by sending a small tip through an in-app purchase, below. This is a one-time, non-recurring transaction, but you can come back any time to send another. No information about your in-app purchase is collected or stored by the Onion Browser developers.\n\nYou can learn about other ways to help (including Patreon, PayPal, Bitcoin, or Zcash) in the 'About' section of the 'Global Settings' page."
			if (iapProducts.isEmpty) {
				msg += "\n\nLoading in-app purchase data..."
			}
		} else {
			msg = ""
		}
		
		if (!iapProducts.isEmpty && section == 3) {
			let prevDonationDate = UserDefaults.standard.object(forKey: "previous_donation_date") as? Date
			let prevDonationAmount = UserDefaults.standard.string(forKey: "previous_donation")
			if (prevDonationDate != nil && prevDonationAmount != nil) {
				let dateFormatter = DateFormatter()
				dateFormatter.dateStyle = DateFormatter.Style.medium
				let convertedDate = dateFormatter.string(from: prevDonationDate!)
				msg += "You most recently donated \(prevDonationAmount!) on \(convertedDate)."
			}
		}
		
		
		return msg
	}
	
	override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		var cell = tableView.dequeueReusableCell(withIdentifier:"cell")
		if (cell == nil) {
			cell = UITableViewCell(style: UITableViewCell.CellStyle.default, reuseIdentifier: "cell")
		}
		
		if (!iapProducts.isEmpty) {
			let product = iapProducts[indexPath.section-1] as SKProduct
			
			// Get its price from iTunes Connect
			let numberFormatter = NumberFormatter()
			numberFormatter.formatterBehavior = .behavior10_4
			numberFormatter.numberStyle = .currency
			numberFormatter.locale = product.priceLocale
			let priceStr = numberFormatter.string(from: product.price)
			cell!.textLabel?.text = "Tip: \(priceStr!)"
		} else {
			if (indexPath.section == 1) {
				cell!.textLabel?.text = "Tip: $0.99"
			} else if (indexPath.section == 2) {
				cell!.textLabel?.text = "Tip: $4.99"
			} else if (indexPath.section == 3) {
				cell!.textLabel?.text = "Tip: $9.99"
			}
		}
		
		return cell!
	}
	
	override public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if (indexPath.section == 1 || indexPath.section == 2 || indexPath.section == 3) {
			if !SKPaymentQueue.canMakePayments() {
				let alert = UIAlertController(title: "Purchase Failure",
											  message: "Sorry, in-app purchase is disabled on your device!",
											  preferredStyle: UIAlertController.Style.alert)
				let cancelAction = UIAlertAction(title: "OK", style: .cancel) { action in
					// nothing
				}
				alert.addAction(cancelAction)
				self.present(alert, animated: true)
				return
			} else {
				let product = iapProducts[indexPath.section-1] as SKProduct
				
				// Get its price from iTunes Connect
				let numberFormatter = NumberFormatter()
				numberFormatter.formatterBehavior = .behavior10_4
				numberFormatter.numberStyle = .currency
				numberFormatter.locale = product.priceLocale
				let priceStr = numberFormatter.string(from: product.price)
				
				let alert = UIAlertController(title: "Confirm Purchase",
											  message: "Are you sure you want to send a \(priceStr!) tip?",
					preferredStyle: UIAlertController.Style.alert)
				let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { action in
					// nothing
				}
				alert.addAction(cancelAction)
				let okAction = UIAlertAction(title: "Confirm \(priceStr!)", style: .default) { action in
					self.makeDonation(product: product)
				}
				alert.addAction(okAction)
				self.present(alert, animated: true)
			}
		}
	}
	
	// MARK: - FETCH AVAILABLE IAP PRODUCTS
	public func fetchAvailableProducts()  {
		
		let productIdentifiers = NSSet(objects:
			TIER_0_99, TIER_4_99, TIER_9_99
		)
		
		productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers as! Set<String>)
		productsRequest.delegate = self
		productsRequest.start()
	}
	
	// MARK: - REQUEST IAP PRODUCTS
	public func productsRequest (_ request:SKProductsRequest, didReceive response:SKProductsResponse) {
		if (response.products.count > 0) {
			iapProducts = response.products
			
			self.tableView.reloadData()
		}
	}
	
	// MARK: - MAKE PURCHASE OF A PRODUCT
	func makeDonation(product: SKProduct) {
		if SKPaymentQueue.canMakePayments() {
			let payment = SKPayment(product: product)
			SKPaymentQueue.default().add(self)
			SKPaymentQueue.default().add(payment)
			
			print("PRODUCT TO PURCHASE: \(product.productIdentifier)")
			product_to_pay = product
			
		} else {
			let alert = UIAlertController(title: "Purchase Failure",
										  message: "Sorry, in-app purchase is disabled on your device!",
										  preferredStyle: UIAlertController.Style.alert)
			let cancelAction = UIAlertAction(title: "OK", style: .cancel) { action in
				// nothing
			}
			alert.addAction(cancelAction)
			self.present(alert, animated: true)
		}
	}
	
	
	
	// MARK:- IAP PAYMENT QUEUE
	public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
		for transaction:AnyObject in transactions {
			if let trans = transaction as? SKPaymentTransaction {
				switch trans.transactionState {
					
				case .purchased:
					SKPaymentQueue.default().finishTransaction(transaction as! SKPaymentTransaction)
					
					
					print(product_to_pay!.productIdentifier)
					
					// Get its price from iTunes Connect
					let numberFormatter = NumberFormatter()
					numberFormatter.formatterBehavior = .behavior10_4
					numberFormatter.numberStyle = .currency
					numberFormatter.locale = product_to_pay!.priceLocale
					let priceStr = numberFormatter.string(from: product_to_pay!.price)
					
					let alert = UIAlertController(title: "Payment Sent",
												  message: "Thank you! Every little bit helps! Your payment of \(priceStr!) helps ensure continuing development on Onion Browser and tools that make Tor easier to integrate into other iOS apps.",
						preferredStyle: UIAlertController.Style.alert)
					let cancelAction = UIAlertAction(title: "OK", style: .cancel) { action in
						// nothing
					}
					alert.addAction(cancelAction)
					self.present(alert, animated: true)
					
					
					let t = transaction as! SKPaymentTransaction
					UserDefaults.standard.set(t.transactionDate!, forKey: "previous_donation_date")
					UserDefaults.standard.set(priceStr!, forKey: "previous_donation")
					
					break
					
				case .failed:
					SKPaymentQueue.default().finishTransaction(transaction as! SKPaymentTransaction)
					break
				case .restored:
					SKPaymentQueue.default().finishTransaction(transaction as! SKPaymentTransaction)
					break
					
				default: break
				}}}
	}
	
	
	@objc private func dismissView() {
		dismiss(animated: true, completion: nil)
	}

	override public func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
}
