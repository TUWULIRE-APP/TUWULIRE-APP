// ignore_for_file: prefer_const_constructors, await_only_futures, sort_child_properties_last

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../utils/settings.dart';

class CallPage extends StatefulWidget {
  final String? channelName;
  final ClientRoleType? role;
  const CallPage({
    Key? key,
    this.channelName,
    this.role,
  }) : super(key: key);

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  final _users = <int>[];
  final _infoStrings = <String>[];
  bool muted = false;
  late RtcEngine _engine;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void dispose() {
    _users.clear();
    _engine.leaveChannel();
    //_engine.destroy();
    super.dispose();
  }

  Future<void> initialize() async {
    if (appId.isEmpty) {
      setState(() {
        _infoStrings.add(
          'App_ID missing, please provide your App_ID in settings.dart',
        );
        _infoStrings.add('Agora Engine is not starting');
      });
      return;
    }
    //! _initAgoraRtcEngine
    _engine = createAgoraRtcEngine();
    await _engine.enableVideo();
    await _engine
        .setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);
    await _engine.setClientRole(role: widget.role!);

    //! _addAgoraEventHandlers
    _addAgoraEventHandlers();
    VideoEncoderConfiguration configuration = VideoEncoderConfiguration();
    configuration.dimensions = VideoDimensions(width: 1920, height: 1080);
    await _engine.setVideoEncoderConfiguration(configuration);
    await _engine.joinChannel(
      channelId: widget.channelName!,
      token: token,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  void _addAgoraEventHandlers() {
    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: ((connection, elapsed) {
        setState(() {
          final info = 'Join channel: $connection';
          _infoStrings.add(info);
        });
      }),
      onLeaveChannel: (connection, stats) {
        setState(() {
          _infoStrings.add('Leave Channel');
          _users.clear();
        });
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        setState(() {
          final info = 'User Joined: $remoteUid';
          _infoStrings.add(info);
          _users.add(remoteUid);
        });
      },
      onUserOffline: (connection, remoteUid, reason) {
        setState(() {
          final info = 'User Offline: $remoteUid';
          _infoStrings.add(info);
          _users.remove(remoteUid);
        });
      },
      onFirstRemoteVideoFrame: (connection, remoteUid, width, height, elapsed) {
        setState(() {
          final info = 'First Remote Video: $remoteUid ${width}x $height';
          _infoStrings.add(info);
        });
      },
    ));
  }

  Widget _viewRows() {
    final List<StatefulWidget> list = [];
    if (widget.role == ClientRoleType.clientRoleBroadcaster) {
      list.add(AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine, canvas: const VideoCanvas(uid: 0)
        ),
      ));
    }
    for (var remoteUid in _users) {
      list.add(AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine, 
          canvas: VideoCanvas(uid: remoteUid), 
          connection: const RtcConnection(channelId: channelName))
        )
      );
    }
    final views = list;
    return Column(
      children: List.generate(
        views.length,
        (index) => Expanded(
          child: views[index],
        ),
      ),
    );
  }

  Widget _toolbar() {
    if (widget.role == ClientRoleType.clientRoleAudience) return const SizedBox();
    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          RawMaterialButton(
            onPressed: () {
              setState(() {
                muted = !muted;
              });
              _engine.muteLocalAudioStream(muted);
            },
            child: Icon(
              muted ? Icons.mic_off : Icons.mic,
              color: muted ? Colors.white : Colors.blueAccent,
              size: 20.0,
            ),
            shape: const CircleBorder(),
            elevation: 2.0,
            fillColor: muted ? Colors.blueAccent : Colors.white,
            padding: const EdgeInsets.all(12.0),
            ),
            RawMaterialButton(
              onPressed: () => Navigator.pop(context),
              child: const Icon(
                Icons.call_end,
                color: Colors.white,
                size: 35.0,
              ),
              shape: const CircleBorder(),
              elevation: 2.0,
              fillColor: Colors.redAccent,
              padding: const EdgeInsets.all(15.0),
          ),
          RawMaterialButton(onPressed: () {
            _engine.switchCamera();
          },
          child: const Icon(
            Icons.switch_camera,
            color: Colors.blueAccent,
            size: 20.0,
          ),
          shape: const CircleBorder(),
          elevation: 2.0,
          fillColor: Colors.white,
          padding: const EdgeInsets.all(12.0),
          )
        ],
      ),
    );
  }

  Widget _panel() {
    return Visibility(
      visible: viewPanel,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 48),
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: ListView.builder(
              reverse: true,
              itemCount: _infoStrings.length,
              itemBuilder: (BuildContext context, int index) {
                if (_infoStrings.isEmpty) {
                  return const Text("null");
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 3,
                    horizontal: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 2,
                            horizontal: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            _infoStrings[index],
                            style: const TextStyle(
                              color: Colors.blueGrey,
                            ),
                          ),
                        ),
                        )
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tuwulire App'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                viewPanel = !viewPanel,
              });
            },
            icon: const Icon(Icons.info_outline),
          )
        ],
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Stack(
          _viewRows(),
          _panel(),
          _toolbar()
        ),
      ),
    );
  }
}
