import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tanpura_model.dart';

class TanpuraPlayerScreen extends StatefulWidget {
  @override
  _TanpuraPlayerScreenState createState() => _TanpuraPlayerScreenState();
}

class _TanpuraPlayerScreenState extends State<TanpuraPlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<TanpuraModel> _tanpuraList = [];
  TanpuraModel? _currentTanpura;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _isBuffering = false;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
    _fetchTanpuraList();
  }

  void _initializeAudio() {
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          _isBuffering = state.processingState == ProcessingState.buffering ||
              state.processingState == ProcessingState.loading;
        });
      }
    });
  }

  Future<void> _fetchTanpuraList() async {
    try {
      final querySnapshot = await _firestore
          .collection('tanpura')
          .orderBy('order')
          .get();

      final tanpuraList = querySnapshot.docs
          .map((doc) => TanpuraModel.fromFirestore(doc.data()))
          .toList();

      if (mounted) {
        setState(() {
          _tanpuraList = tanpuraList;
          if (_tanpuraList.isNotEmpty && _currentTanpura == null) {
            _currentTanpura = _tanpuraList.first;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('Error fetching tanpura list: $e');
    }
  }

  Future<void> _selectTanpura(TanpuraModel tanpura) async {
    if (_currentTanpura?.filePath == tanpura.filePath) return;

    try {
      await _audioPlayer.stop();
      setState(() {
        _currentTanpura = tanpura;
      });

      await _audioPlayer.setUrl(tanpura.filePath);
      await _audioPlayer.setLoopMode(LoopMode.one);
    } catch (e) {
      print('Error selecting tanpura: $e');
    }
  }

  Future<void> _playPause() async {
    try {
      if (_currentTanpura == null) return;

      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        setState(() {
          _isBuffering = true;
        });

        if (_audioPlayer.processingState == ProcessingState.idle) {
          await _audioPlayer.setUrl(_currentTanpura!.filePath);
          await _audioPlayer.setLoopMode(LoopMode.one);
        }

        await _audioPlayer.play();

        await _audioPlayer.processingStateStream
            .firstWhere((state) =>
        state == ProcessingState.ready ||
            state == ProcessingState.completed);

        setState(() {
          _isBuffering = false;
        });
      }
    } catch (e) {
      setState(() {
        _isBuffering = false;
      });
      print('Error playing/pausing: $e');
    }
  }

  Future<void> _stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('Error stopping: $e');
    }
  }

  void _showVolumeControl() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        double currentVolume = _audioPlayer.volume;
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Volume Control',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                  SizedBox(height: 30),
                  Row(
                    children: [
                      Icon(Icons.volume_down, color: Color(0xFFFF6B35)),
                      Expanded(
                        child: Slider(
                          value: currentVolume,
                          min: 0.0,
                          max: 1.0,
                          activeColor: Color(0xFFFF6B35),
                          inactiveColor: Color(0xFFFF8A50).withOpacity(0.3),
                          onChanged: (value) {
                            setState(() {
                              currentVolume = value;
                            });
                            _audioPlayer.setVolume(value);
                          },
                        ),
                      ),
                      Icon(Icons.volume_up, color: Color(0xFFFF6B35)),
                    ],
                  ),
                  Text(
                    '${(currentVolume * 100).round()}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F3E9),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Tanpura',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF6B35),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFFFF6B35)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20.0, 100.0, 20.0, 20.0),
        child: Column(
          children: [
            // Simple Radio Icon
            _buildSimpleRadioIcon(),
            SizedBox(height: 40),

            // Current Playing Info
            _buildCurrentPlayingInfo(),
            SizedBox(height: 40),

            // Pitch Selection
            _buildPitchSelection(),
            SizedBox(height: 40),

            // Controls
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleRadioIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
        border: _isPlaying
            ? Border.all(color: Color(0xFFFF6B35), width: 3)
            : null,
      ),
      child: Icon(
        Icons.radio,
        size: 60,
        color: _isPlaying ? Color(0xFFFF6B35) : Colors.grey[600],
      ),
    );
  }

  Widget _buildCurrentPlayingInfo() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Currently Playing',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            _currentTanpura?.name ?? 'Select a pitch',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF6B35),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPitchSelection() {
    if (_isLoading) {
      return CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Pitch',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF6B35),
          ),
        ),
        SizedBox(height: 15),
        Container(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _tanpuraList.length,
            itemBuilder: (context, index) {
              final tanpura = _tanpuraList[index];
              final isSelected = _currentTanpura?.filePath == tanpura.filePath;

              return Padding(
                padding: EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => _selectTanpura(tanpura),
                  child: Container(
                    width: 80,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFFF8A50)],
                      )
                          : null,
                      color: isSelected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        tanpura.name.split(' ').last,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Stop Button
        _buildControlButton(
          icon: Icons.stop,
          onPressed: _stop,
          isSecondary: true,
        ),

        // Play/Pause Button
        _buildControlButton(
          icon: _isBuffering
              ? null
              : (_isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: _playPause,
          isLarge: true,
          isLoading: _isBuffering,
        ),

        // Volume Button
        _buildControlButton(
          icon: Icons.volume_up,
          onPressed: _showVolumeControl,
          isSecondary: true,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    IconData? icon,
    required VoidCallback onPressed,
    bool isLarge = false,
    bool isSecondary = false,
    bool isLoading = false,
  }) {
    final size = isLarge ? 80.0 : 60.0;
    final iconSize = isLarge ? 40.0 : 30.0;

    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: !isSecondary
              ? LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF8A50)],
          )
              : null,
          color: isSecondary ? Colors.white : null,
          shape: BoxShape.circle,
          border: isSecondary
              ? Border.all(color: Color(0xFFFF6B35), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: isLoading
            ? CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          strokeWidth: 3,
        )
            : Icon(
          icon,
          color: isSecondary ? Color(0xFFFF6B35) : Colors.white,
          size: iconSize,
        ),
      ),
    );
  }
}
