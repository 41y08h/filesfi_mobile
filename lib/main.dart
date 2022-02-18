import 'package:filesfi/configs.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import "package:flutter_webrtc/flutter_webrtc.dart";
import 'package:fluttertoast/fluttertoast.dart';

void main() {
  runApp(
    MaterialApp(
      title: "FilesFi",
      theme: ThemeData.dark(),
      home: const App(),
    ),
  );
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

  late RTCPeerConnection connection;
  late RTCPeerConnection callerConnection;
  late RTCPeerConnection calleeConnection;
  late RTCDataChannel dataChannel;

  @override
  void initState() {
    super.initState();

    socket = IO.io('http://c2f4-103-152-158-178.ngrok.io', <String, dynamic>{
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

    socket.on("callAnswered", (answer) async {
      final description = RTCSessionDescription(answer['sdp'], answer['type']);
      await callerConnection.setRemoteDescription(description);
    });

    socket.on("peerIsCalling", (call) async {
      // If we already are trying to connect to someone
      if (signalingState != SignalingState.idle) {
        return socket.emit("exception/peerIsCalling", {
          'type': "busy",
          'payload': {'callerId': call['callerId']},
        });
      }

      calleeConnection = await createPeerConnection(rtcConfig);

      calleeConnection.onConnectionState = (state) {
        if (state != RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          return;
        }

        setState(() {
          signalingState = SignalingState.connected;
          connection = calleeConnection;
        });
      };

      // Set received remote description
      final signal = call['signal'];
      final description = RTCSessionDescription(signal['sdp'], signal['type']);
      await calleeConnection.setRemoteDescription(description);

      // Answer the caller
      final answerDescription = await calleeConnection.createAnswer();
      await calleeConnection.setLocalDescription(answerDescription);

      //  wait 2 seconds
      await Future.delayed(Duration(seconds: 2));

      // Emit our local description to the signaling server
      socket.emit("answerCall", {
        "callerId": call['callerId'],
        "signal": {
          "type": answerDescription.type,
          "sdp": answerDescription.sdp,
        }
      });
    });

    socket.on("exception/callPeer", (error) {
      if (error['type'] == "deviceBusy") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Device is busy"),
          ),
        );
      } else if (error['type'] == "callingSelf") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You can't call yourself"),
          ),
        );
      } else if (error['type'] == "deviceNotFound") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Requested device not found"),
          ),
        );
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

    callerConnection = await createPeerConnection(rtcConfig);

    callerConnection.onConnectionState = (state) {
      if (state != RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        return;
      }

      setState(() {
        signalingState = SignalingState.connected;
        connection = callerConnection;
      });
    };

    // Create a data channel for transfering files
    RTCDataChannelInit dataChannelDict = RTCDataChannelInit()
      ..maxRetransmits = 30;
    dataChannel = await callerConnection.createDataChannel(
      "fileTransfer",
      dataChannelDict,
    );

    RTCSessionDescription offer = await callerConnection.createOffer();
    await callerConnection.setLocalDescription(offer);

    await Future.delayed(Duration(seconds: 2));

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('FilesFi'),
        centerTitle: true,
        elevation: 0,
      ),
      body: isConnecting
          ? const Center(
              child: Text("Connecting..."),
            )
          : signalingState == SignalingState.connected
              ? Text("Connected")
              : Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Your ID",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        id.toString(),
                        style: const TextStyle(
                          fontSize: 24,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        onChanged: (value) {
                          peerId = value;
                        },
                        decoration: const InputDecoration(
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
                        child: const Text("Connect"),
                      )
                    ],
                  ),
                ),
    );
  }
}
