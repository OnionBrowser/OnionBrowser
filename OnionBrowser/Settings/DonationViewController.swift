//
//  DonationViewController.swift
//  OnionBrowser2
//
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import StoreKit
import IPtProxyUI

@objc public class DonationViewController: UITableViewController, SKProductsRequestDelegate,
	SKPaymentTransactionObserver {
	
	/* Variables */
	private static let TIER_0_99 = "com.miketigas.onionbrowser.tip0_99"
	private static let TIER_4_99 = "com.miketigas.onionbrowser.tip4_99"
	private static let TIER_9_99 = "com.miketigas.onionbrowser.tip9_99"
	
	private var productToPay: SKProduct!
	private var productsRequest = SKProductsRequest()
	private var iapProducts = [SKProduct]()
	
	private lazy var dateFormatter: DateFormatter = {
		let df = DateFormatter()
		df.dateStyle = DateFormatter.Style.medium

		return df
	}()

	private lazy var numberFormatter: NumberFormatter = {
		let nf = NumberFormatter()
		nf.formatterBehavior = .behavior10_4
		nf.numberStyle = .currency

		return nf
	}()


	convenience init() {
		self.init(style: .grouped)
	}
	
	override public func viewDidLoad() {
		super.viewDidLoad()
		
		title = NSLocalizedString("Donate", comment: "")

		fetchAvailableProducts()
	}


	// MARK: UITableViewSource

	override public func numberOfSections(in tableView: UITableView) -> Int {
		return iapProducts.isEmpty ? 1 : 4
	}
	
	override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch section {
		case 1, 2, 3:
			return 1
		default:
			return 0
		}
	}
	
	override public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String {
		return section == 0
			? NSLocalizedString("Support Onion Browser Development", comment: "").uppercased()
			: ""
	}

	override public func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String {
		var msg = ""

		if section == 0 {
			msg = NSLocalizedString("__DONATE_EXPLANATION_PARAGRAPH1__", comment: "")
				+ "\n\n"
				+ NSLocalizedString("__DONATE_EXPLANATION_PARAGRAPH2__", comment: "")
				+ "\n\n"
				+ NSLocalizedString("__DONATE_EXPLANATION_PARAGRAPH3__", comment: "")

			if iapProducts.isEmpty {
				msg += "\n\n"
					+ NSLocalizedString("Loading in-app purchase data…", comment: "")
			}
		}
		
		if !iapProducts.isEmpty && section == 3 {
			let ud = UserDefaults.standard

			if let prevDonationDate = ud.object(forKey: "previous_donation_date") as? Date,
				let prevDonationAmount = ud.string(forKey: "previous_donation") {

				msg += String(format: NSLocalizedString("You most recently donated %1$@ on %2$@.", comment: ""),
							  prevDonationAmount,
							  dateFormatter.string(from: prevDonationDate))

			}
		}

		return msg
	}
	
	override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier:"cell")
			?? UITableViewCell(style: .default, reuseIdentifier: "cell")

		let text = NSLocalizedString("Tip: %@", comment: "")

		if !iapProducts.isEmpty {
			let product = iapProducts[indexPath.section - 1] as SKProduct
			
			// Get its price from iTunes Connect
			numberFormatter.locale = product.priceLocale

			if let price = numberFormatter.string(from: product.price) {
				cell.textLabel?.text = String(format: text, price)
			}
			else {
				cell.textLabel?.text = ""
			}
		}
		else {
			switch indexPath.section {
			case 1:
				cell.textLabel?.text = String(format: text, numberFormatter.string(from: 0.99)!)
			case 2:
				cell.textLabel?.text = String(format: text, numberFormatter.string(from: 4.99)!)
			case 3:
				cell.textLabel?.text = String(format: text, numberFormatter.string(from: 9.99)!)
			default:
				break
			}
		}
		
		return cell
	}


	// MARK: UITableViewDelegate
	
	override public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if !(indexPath.section == 1 || indexPath.section == 2 || indexPath.section == 3) {
			return
		}

		if !SKPaymentQueue.canMakePayments() {
			return showError()
		}
		else {
			let product = iapProducts[indexPath.section - 1] as SKProduct

			// Get its price from iTunes Connect
			numberFormatter.locale = product.priceLocale
			let priceStr = numberFormatter.string(from: product.price) ?? ""

			AlertHelper.present(
				self,
				message: String(format: NSLocalizedString("Are you sure you want to send a %@ tip?", comment: ""), priceStr),
				title: NSLocalizedString("Confirm Purchase", comment: ""),
				actions: [
					AlertHelper.cancelAction(),
					AlertHelper.defaultAction(
						String(format: NSLocalizedString("Confirm %@", comment: ""), priceStr),
						handler: { _ in self.makeDonation(product: product) })])
		}
	}


	// MARK: SKProductsRequestDelegate
	
	/**
	Request IAP products
	*/
	public func productsRequest(_ request:SKProductsRequest, didReceive response: SKProductsResponse) {
		if response.products.count > 0 {
			iapProducts = response.products
			
			tableView.reloadData()
		}
	}
	

	// MARK: SKPaymentTransactionObserver
	
	/**
	IAP payment queue
	*/
	public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
		for transaction in transactions {
			let paymentQueue = SKPaymentQueue.default()

			switch transaction.transactionState {

			case .purchased:
				paymentQueue.finishTransaction(transaction)


				print(productToPay.productIdentifier)

				// Get its price from iTunes Connect
				numberFormatter.locale = productToPay.priceLocale
				let priceStr = numberFormatter.string(from: productToPay.price) ?? ""

				AlertHelper.present(
					self,
					message: String(format: NSLocalizedString("__DONATE_THANKS__", comment: ""), priceStr),
					title: NSLocalizedString("Payment Sent", comment: ""))

				if let date = transaction.transactionDate {
					UserDefaults.standard.set(date, forKey: "previous_donation_date")
				}

				UserDefaults.standard.set(priceStr, forKey: "previous_donation")

				break

			case .failed, .restored:
				paymentQueue.finishTransaction(transaction)
				break

			default:
				break
			}
		}
	}


	// MARK: Private Methods

	/**
	Fetch available IAP products
	*/
	private func fetchAvailableProducts()  {

		let productIdentifiers = Set(arrayLiteral: DonationViewController.TIER_0_99,
									 DonationViewController.TIER_4_99,
									 DonationViewController.TIER_9_99)

		productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
		productsRequest.delegate = self
		productsRequest.start()
	}

	/**
	Make purchase of a product.
	*/
	private func makeDonation(product: SKProduct) {
		if SKPaymentQueue.canMakePayments() {
			let payment = SKPayment(product: product)
			SKPaymentQueue.default().add(self)
			SKPaymentQueue.default().add(payment)

			print("PRODUCT TO PURCHASE: \(product.productIdentifier)")
			productToPay = product
		}
		else {
			showError()
		}
	}

	private func showError() {
		AlertHelper.present(
			self,
			message: NSLocalizedString("Sorry, in-app purchase is disabled on your device!", comment: ""),
			title: NSLocalizedString("Purchase Failure", comment: ""))
	}
}
