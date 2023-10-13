//
//  DownloadActivity.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 19.05.23.
//  Copyright © 2023 Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import MBProgressHUD

class DownloadActivity: UIActivity, URLSessionDownloadDelegate {

	private var url: URL?


	private lazy var hud: MBProgressHUD = {
		let hud = MBProgressHUD()
		hud.mode = .annularDeterminate

		if let view = vc?.view {
			hud.add(to: view)
		}

		hud.button.setTitle(NSLocalizedString("Cancel", comment: ""))
		hud.button.addTarget(self, action: #selector(cancel), for: .touchUpInside)

		return hud
	}()

	private lazy var vc: BrowsingViewController? = {
		guard let url = url else {
			return nil
		}

		let context = getVcAndTab(for: url)

		tab = context?.tab

		return context?.vc
	}()

	private lazy var tab: Tab? = {
		guard let url = url else {
			return nil
		}

		let context = getVcAndTab(for: url)

		vc = context?.vc

		return context?.tab
	}()

	private var task: URLSessionDownloadTask?


	override var activityType: UIActivity.ActivityType? {
		return ActivityType(String(describing: type(of: self)))
	}

	override var activityTitle: String? {
		return NSLocalizedString("Download", comment: "")
	}

	override var activityImage: UIImage? {
		return UIImage(systemName: "square.and.arrow.down")
	}

	override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
		guard activityItems.count == 1,
			  isGood(activityItems.first),
			  let url = activityItems.first as? URL,
			  let context = getVcAndTab(for: url),
			  !(context.tab.downloadedFile?.exists ?? false)
		else {
			return false
		}

		return true
	}

	override func prepare(withActivityItems activityItems: [Any]) {
		url = activityItems.first(where: { isGood($0) }) as? URL
	}

	override func perform() {
		guard let url = url,
			  let webView = tab?.webView
		else {
			return activityDidFinish(false)
		}

		hud.show(animated: true)

		webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in

			let conf = URLSessionConfiguration.ephemeral
			conf.httpCookieStorage?.setCookies(cookies, for: url, mainDocumentURL: nil)
			conf.waitsForConnectivity = true
			conf.allowsConstrainedNetworkAccess = true
			conf.allowsExpensiveNetworkAccess = true

			let session = URLSession(configuration: conf, delegate: self, delegateQueue: .main)

			self.task = session.downloadTask(with: URLRequest(url: url))
			self.task?.resume()

			session.finishTasksAndInvalidate()
		}
	}


	// MARK: URLSessionTaskDelegate

	func urlSession(_ session: URLSession, task: URLSessionTask,
					didReceive challenge: URLAuthenticationChallenge,
					completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
	{
		guard let tab = tab else {
			return completionHandler(.cancelAuthenticationChallenge, nil)
		}

		tab.handle(challenge: challenge, completionHandler)
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		showError(error)

		activityDidFinish(false)
	}


	// MARK: URLSessionDownloadDelegate

	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		guard let response = downloadTask.response as? HTTPURLResponse,
			  response.statusCode >= 200 && response.statusCode < 300,
			  let filename = response.suggestedFilename,
			  let destination = DownloadHelper.getDirectory()?.appendingPathComponent(filename),
			  let vc = vc,
			  let actionBt = vc.actionBt
		else {
			showError(nil)

			return activityDidFinish(false)
		}

		do {
			try FileManager.default.moveItem(at: location, to: destination)
		}
		catch {
			showError(error)

			return activityDidFinish(false)
		}

		tab?.downloadedFile = destination

		hud.hide(animated: true)

		vc.action(actionBt)

		activityDidFinish(true)
	}

	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
					didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
					totalBytesExpectedToWrite: Int64)
	{
		hud.progress = Float(totalBytesExpectedToWrite) / Float(totalBytesWritten)
	}


	// MARK: Private Methods

	@objc
	private func cancel() {
		task?.cancel()
	}

	private func isGood(_ value: Any?) -> Bool {
		guard let url = value as? URL,
			  !url.isSpecial,
			  // If this is a file URL, it is already downloaded and can be shared right away!
			  !url.isFileURL
		else {
			return false
		}

		return true
	}

	private func getVcAndTab(for url: URL) -> (vc: BrowsingViewController, tab: Tab)? {
		for vc in AppDelegate.shared?.browsingUis ?? [] {
			if let tab = vc.tabs.first(where: { $0.url == url }) {
				return (vc, tab)
			}
		}

		return nil
	}

	private func showError(_ error: Error?) {
		hud.mode = .customView
		hud.customView = UIImageView(image: UIImage(systemName: "exclamationmark.triangle"))

		if let error = error?.localizedDescription, !error.isEmpty {
			hud.label.text = error
		}

		hud.hide(animated: true, afterDelay: 3)
	}
}
