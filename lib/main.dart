import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import "package:flutter_webrtc/flutter_webrtc.dart";
import 'package:fluttertoast/fluttertoast.dart';

void main() {
  runApp(const App());
}

class App extends StatefulWidget {
  const App({Key? key}) : super(key: key);

  @override
  State<App> createState() => _AppState();
}

enum SignalingState { idle, connecting, connected }

class _AppState extends State<App> {
  late IO.Socket socket;
  late int id;
  bool isConnecting = true;
  SignalingState signalingState = SignalingState.idle;
  String peerId = "";
  late RTCPeerConnection callerConnection;

  @override
  void initState() {
    super.initState();

    socket = IO.io('http://192.168.0.104:5000', <String, dynamic>{
      'transports': ['websocket'],
    });

    socket.onConnect((_) {
      print('Connected');
      socket.emit("join");
    });

    socket.on("join/callback", (id) {
      setState(() {
        this.id = id;
        isConnecting = false;
      });
    });

    socket.on("exception/callPeer", (error) {
      if (error['type'] == "deviceBusy") {
        Fluttertoast.showToast(msg: "Requested device is busy");
      } else if (error['type'] == "callingSelf") {
        Fluttertoast.showToast(msg: "Calling self is not allowed");
      } else if (error['type'] == "deviceNotFound") {
        Fluttertoast.showToast(msg: "Device not found");
      }

      setState(() {
        callerConnection.dispose();
        signalingState = SignalingState.idle;
      });
    });
  }

  onConnectButtonPressed() async {
    // Dismiss keyboard
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      signalingState = SignalingState.connecting;
    });

    callerConnection = await createPeerConnection({
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
        {'url': 'stun:global.stun.twilio.com:3478'},
      ],
      'sdpSemantics': 'unified-plan'
    });

    RTCSessionDescription offer = await callerConnection.createOffer();
    await callerConnection.setLocalDescription(offer);
    // Send it to the signaling server

    socket.emit("callPeer", {
      'peerId': peerId,
      'signal': {
        'type': offer.type,
        'sdp': offer.sdp,
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('FilesFi'),
          centerTitle: true,
          elevation: 0,
        ),
        body: isConnecting
            ? Center(
                child: Text("Connecting..."),
              )
            : Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Your ID",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(
                      height: 4,
                    ),
                    Text(
                      id.toString(),
                      style: TextStyle(
                        fontSize: 24,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    TextField(
                      onChanged: (value) {
                        peerId = value;
                      },
                      decoration: InputDecoration(
                        hintText: "Connect to ID",
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white,
                            width: 20,
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),
                    TextButton(
                      onPressed: signalingState == SignalingState.idle
                          ? onConnectButtonPressed
                          : null,
                      child: Text("Connect"),
                    )
                  ],
                ),
              ),
      ),
    );
  }
}
