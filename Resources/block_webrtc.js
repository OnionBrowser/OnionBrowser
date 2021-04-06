/*
 * Note: This block of Javascript has been injected via Onion Browser and is
 * not a part of this website.
 *
 * Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */
// Replace native RTCPeerConnection implementations with no-op versions with the
// same object signature
/*
try { window.RTCPeerConnection = function(){} } catch(e) {}
try { window.webkitRTCPeerConnection = function(){} } catch(e) {}
try { window.RTCPeerConnection.prototype = function(){} } catch(e) {}
try { window.webkitRTCPeerConnection.prototype = function(){} } catch(e) {}
try { window.RTCPeerConnection.prototype.onicecandidate = function() {} } catch(e) {}
try { window.RTCPeerConnection.prototype.addicecandidate = function() {} } catch(e) {}
try { window.RTCPeerConnection.prototype.createOffer = function() {} } catch(e) {}
try { window.RTCPeerConnection.prototype.createAnswer = function() {} } catch(e) {}
try { window.RTCPeerConnection.prototype.setLocalDescription = function() {} } catch(e) {}
try { window.RTCPeerConnection.prototype.setRemoteDescription = function() {} } catch(e) {}
try { window.RTCPeerConnection.prototype.createDataChannel = function() {} } catch(e) {}
try { window.webkitRTCPeerConnection.prototype.onicecandidate = function() {} } catch(e) {}
try { window.webkitRTCPeerConnection.prototype.addicecandidate = function() {} } catch(e) {}
try { window.webkitRTCPeerConnection.prototype.createOffer = function() {} } catch(e) {}
try { window.webkitRTCPeerConnection.prototype.createAnswer = function() {} } catch(e) {}
try { window.webkitRTCPeerConnection.prototype.setLocalDescription = function() {} } catch(e) {}
try { window.webkitRTCPeerConnection.prototype.setRemoteDescription = function() {} } catch(e) {}
try { window.RTCPeerConnection.prototype.createDataChannel = function() {} } catch(e) {}
*/
try { RTCPeerConnection = function(){} } catch(e) {}
try { webkitRTCPeerConnection = function(){} } catch(e) {}
try { RTCPeerConnection.prototype = function(){} } catch(e) {}
try { webkitRTCPeerConnection.prototype = function(){} } catch(e) {}
try { window.RTCPeerConnection = function(){} } catch(e) {}
try { window.webkitRTCPeerConnection = function(){} } catch(e) {}
try { window.RTCPeerConnection.prototype = function(){} } catch(e) {}
try { window.webkitRTCPeerConnection.prototype = function(){} } catch(e) {}

function noopMethod (methodName) {
  try { RTCPeerConnection.prototype[methodName] = function() {} } catch(e) {}
  try { webkitRTCPeerConnection.prototype[methodName] = function() {} } catch(e) {}
  try { window.RTCPeerConnection.prototype[methodName] = function() {} } catch(e) {}
  try { window.webkitRTCPeerConnection.prototype[methodName] = function() {} } catch(e) {}
}
var methods = ['addIceCandidate', 'addStream', 'addTrack', 'close', 'createAnswer', 'createDTMFSender', 'createDataChannel', 'createOffer', 'getLocalStreams', 'getReceivers', 'getRemoteStreams', 'getSenders', 'getStats', 'iceConnectionState', 'iceGatheringState', 'localDescription', 'onaddstream', 'ondatachannel', 'onicecandidate', 'oniceconnectionstatechange', 'onicegatheringstatechange', 'onnegotiationneeded', 'onremovestream', 'onsignalingstatechange', 'ontrack', 'remoteDescription', 'removeStream', 'removeTrack', 'setConfiguration', 'setLocalDescription', 'setRemoteDescription', 'signalingState'];
methods.forEach(noopMethod);
