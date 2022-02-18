final rtcConfig = {
  "bundlePolicy": "balanced",
  "encodedInsertableStreams": false,
  "iceCandidatePoolSize": 0,
  "iceServers": [
    {
      "credential": "",
      "urls": ["stun:stun.l.google.com:19302"],
      "username": ""
    },
    {
      "credential": "",
      "urls": ["stun:global.stun.twilio.com:3478"],
      "username": ""
    }
  ],
  "iceTransportPolicy": "all",
  "rtcpMuxPolicy": "require",
  "sdpSemantics": "unified-plan"
};
