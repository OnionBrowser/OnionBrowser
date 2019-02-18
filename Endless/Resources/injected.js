/*
 * Note: This block of Javascript has been injected via the Endless browser and is
 * not a part of this website.
 *
 * Endless
 * Copyright (c) 2014-2017 joshua stein <jcs@jcs.org>
 * See LICENSE file for redistribution terms.
 */

if (typeof __endless == "undefined") {
var __endless = {
	openedTabs: {},

	ipcTimeoutMS: 2000,

	ipc: function(url) {
		var iframe = document.createElement("iframe");
		iframe.setAttribute("src", "endlessipc://" + url);
		iframe.setAttribute("height", "1px");
		iframe.setAttribute("width", "1px");
		document.documentElement.appendChild(iframe);
		iframe.parentNode.removeChild(iframe);
		iframe = null;
	},

	ipcDone: null,
	ipcAndWaitForReply: function(url) {
		this.ipcDone = null;

		var start = (new Date()).getTime();
		this.ipc(url);

		while (this.ipcDone == null) {
			if ((new Date()).getTime() - start > this.ipcTimeoutMS) {
				console.log("took too long waiting for IPC reply");
				break;
			}
		}

		return;
	},

	randID: function() {
		var a = new Uint32Array(5);
		window.crypto.getRandomValues(a);
		return a.join("-");
	},

	hookIntoBlankAs: function() {
		if (!document.body)
			return;
		
		document.body.addEventListener("click", function() {
			if (event.target.tagName == "A" && event.target.target == "_blank") {
				if (event.type == "click") {
					event.preventDefault();
					if (window.open(event.target.href) == null)
						window.location = event.target.href;
					return false;
				}
				else {
					console.log("not opening _blank a from " + event.type + " event");
				}
			}
		}, false);
	},
	
	elementsAtPoint: function(x, y) {
		var tags = [];
		var e = document.elementFromPoint(x,y);
		while (e) {
			if (e.tagName) {
				var name = e.tagName.toLowerCase();
				if (name == "a")
					tags.push({ "a": { "href" : e.href, "title" : e.title } });
				else if (name == "img")
					tags.push({ "img": { "src" : e.src, "title" : e.title, "alt" : e.alt } });
			}
			e = e.parentNode;
		}
		return tags;
	},
	
	scrollingLoop: null,
	scrollingDistanceX: 0,
	scrollingDistanceY: 0,
	scrollingPercent: 0,
	scrollingStart: 0,
	scrollingDuration: 0,
	scrollingStartX: 0,
	scrollingStartY: 0,
	smoothScroll: function(x, y, top, bottom) {
		var duration = 250; /* ms */
		
		if (this.scrollingStart && !top && !bottom) {
			/* extend scroll */
			this.scrollingDistanceX += x / 2;
			this.scrollingDistanceY += y / 2;
			duration *= 2;
		} else {
			this.scrollingStartX = window.scrollX;
			this.scrollingStartY = window.scrollY;
		
			this.scrollingDistanceX = 0;
			this.scrollingDistanceY = 0;

			if (top)
				this.scrollingDistanceY = -this.scrollingStartY;
			else if (bottom)
				this.scrollingDistanceY = document.documentElement.scrollHeight - this.scrollingStartY;
			else {
				this.scrollingDistanceX = x;
				this.scrollingDistanceY = y;
			}
			
			this.scrollingStart = new Date().getTime();
		}

		if (!this.scrollingDistanceX && !this.scrollingDistanceY)
			return;
		
		var _this = this;
		this.scrollingLoop = function loopScroll() {
			_this.scrollingPercent = Math.min((new Date().getTime() - _this.scrollingStart) / duration, 1);
			var x = Math.max(Math.floor(_this.scrollingStartX + (_this.scrollingDistanceX * (_this.scrollingPercent < 0.5 ? (2 * _this.scrollingPercent * _this.scrollingPercent) : (_this.scrollingPercent * (4 - (_this.scrollingPercent * 2)) - 1)))), 0);
			var y = Math.max(Math.floor(_this.scrollingStartY + (_this.scrollingDistanceY * (_this.scrollingPercent < 0.5 ? (2 * _this.scrollingPercent * _this.scrollingPercent) : (_this.scrollingPercent * (4 - (_this.scrollingPercent * 2)) - 1)))), 0);
			window.scrollTo(x, y);
			if (_this.scrollingPercent < 1 && _this.scrollingLoop)
				requestAnimationFrame(_this.scrollingLoop);
			else {
				_this.scrollingLoop = null;
				_this.scrollingStart = 0;
			}
		};
		this.scrollingLoop();
	},
	
	injectKey: function(keycode, keypress_keycode, ctrl, alt, shift, meta, action) {
		[ "keydown", "keypress", "keyup" ].forEach(function(kind) {
			if (kind == "keypress" && !keypress_keycode)
				return;
							   
			var e = document.createEvent("KeyboardEvent");
			e.initKeyboardEvent(kind, false, true, document.body, "", 0, !!ctrl, !!alt, !!shift, !!meta, false);
			Object.defineProperty(e, "keyCode", { writable: false, value: (kind == "keypress" ? keypress_keycode : keycode) } );
			Object.defineProperty(e, "which", { writable: false, value: (kind == "keypress" ? keypress_keycode : keycode) } );
			Object.defineProperty(e, "charCode", { writable: false, value: (kind == "keypress" ? keypress_keycode : 0) } );
			Object.defineProperty(e, "target", { writable: false, value: document.body } );
			var ret = document.dispatchEvent(e);
			
			if ((kind == "keypress" || (kind == "keydown" && !keypress_keycode)) && ret && action)
				action();
		});
	},

	onLoad: function() {
		/* supress default long-press menu */
		if (document && document.body)
			document.body.style.webkitTouchCallout = "none";
		
		__endless.hookIntoBlankAs();
	},

	FakeLocation: function(real) {
		this.id = null;

		for (var prop in real) {
			this["_" + prop] = real[prop];
		}

		this.toString = function() {
			return this._href;
		};
	},

	FakeWindow: function(id) {
		this.id = id;
		this.opened = false;
		this._location = null;
		this._name = null;
	},

	absoluteURL: function(url) {
	    var a = document.createElement("a");
		a.href = url; /* browser will make this absolute for us */
		return a.href;
	},
};

(function () {
	"use strict";

	__endless.FakeLocation.prototype = {
		constructor: __endless.FakeLocation,
	};

	[ "hash", "hostname", "href", "pathname", "port", "protocol", "search", "username", "password", "origin" ].forEach(function(property) {
		Object.defineProperty(__endless.FakeLocation.prototype, property, {
			set: function(v) {
				eval("this._" + property + " = null;");
				__endless.ipcAndWaitForReply("fakeWindow.setLocationParam/" + this.id + "/" + property + "?" + encodeURIComponent(v));
			},
			get: function() {
				throw "security error trying to access location." + property + " of other window";
			},
		});
	});

	__endless.FakeWindow.prototype = {
		constructor: __endless.FakeWindow,
 
		set location(loc) {
			this._location = new __endless.FakeLocation();
			__endless.ipcAndWaitForReply("fakeWindow.setLocation/" + this.id + "?" + encodeURIComponent(loc));
			this._location.id = this.id;
		},
		set name(n) {
			this._name = null;
			__endless.ipcAndWaitForReply("fakeWindow.setName/" + this.id + "?" + encodeURIComponent(n));
		},
		set opener(o) {
		},

		get location() {
			throw "security error trying to access window.location of other window";
		},
		get name() {
			throw "security error trying to access window.name of other window";
		},
		get title() {
			throw "security error trying to access window.title of other window";
		},
		get opener() {
		},

		close: function() {
			__endless.ipcAndWaitForReply("fakeWindow.close/" + this.id);
		},
 
		toString: function() {
			return "[object FakeWindow]";
		},
	};

	window.onerror = function(msg, url, line) {
		console.error("[on " + url + ":" + line + "] " + msg);
	}

	window.open = function (url, name, specs, replace) {
		var id = __endless.randID();

		__endless.openedTabs[id] = new __endless.FakeWindow(id);

		/*
		 * Fake a mouse event clicking on a link, so that our webview sees the
		 * navigation type as a mouse event.  This prevents popup spam since
		 * dispatchEvent() won't do anything if we're not in a mouse event
		 * already.
		 */
		var l = document.createElement("a");
		l.setAttribute("href", "endlessipc://window.open/" + id);
		l.setAttribute("target", "_blank");
		var e = document.createEvent("MouseEvents");
		e.initMouseEvent("click", true, true, window, 0, 0, 0, 0, 0, false,
			false, false, false, 0, null);
		l.dispatchEvent(e);

		__endless.ipcAndWaitForReply("noop");

		if (!__endless.openedTabs[id].opened) {
			console.error("window failed to open");
			/* TODO: send url to ipc anyway to show popup blocker notice */
			return null;
		}

		if (name !== undefined && name != '')
			__endless.openedTabs[id].name = name;
		if (url !== undefined && url != '')
			__endless.openedTabs[id].location = __endless.absoluteURL(url);

		window.event.preventDefault();
		window.event.stopImmediatePropagation();

		return __endless.openedTabs[id];
	};

	window.close = function () {
		__endless.ipcAndWaitForReply("window.close");
	};

	/* pipe back to app */
	console._log = function(urg, args) {
		if (args.length == 1)
			args = args[0];
		__endless.ipc("console.log/" + urg + "?" + encodeURIComponent(JSON.stringify(args)));
	};
	console.log = function() { console._log("log", arguments); };
	console.debug = function() { console._log("debug", arguments); };
	console.info = function() { console._log("info", arguments); };
	console.warn = function() { console._log("warn", arguments); };
	console.error = function() { console._log("error", arguments); };

	if ("##BLOCK_WEBRTC##") {
 		navigator.mediaDevices = null;
 		navigator.getUserMedia = null;
		window.RTCPeerConnection = null;
		window.webkitRTCPeerConnection = null;
	}
 
	if (document.readyState == "complete" || document.readyState == "interactive")
		__endless.onLoad();
	else
		document.addEventListener("DOMContentLoaded", __endless.onLoad, false);
}());
}
