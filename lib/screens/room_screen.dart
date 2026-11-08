import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'game_screen.dart';

class RoomScreen extends StatefulWidget {
  final String roomCode;
  const RoomScreen({super.key, required this.roomCode});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool _isPlaying = false;

  void _startGame() async {
    // تحديث حالة الغرفة لـ playing عشان تنقل اللاعبين
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .update({'status': 'playing'});
  }

  void _kickPlayer() async {
    // تفريغ خانة اللاعب التاني لطرد الخصم
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .update({'player2': ''});
  }

  void _leaveRoom() async {
    // خروج الضيف من الغرفة
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomCode)
        .update({'player2': ''});
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Room Lobby',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomCode)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Room closed or not found.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          var roomData = snapshot.data!.data() as Map<String, dynamic>;
          String player1 = roomData['player1'] ?? '';
          String player2 = roomData['player2'] ?? '';
          String status = roomData['status'] ?? 'waiting';

          bool isCreator = currentUserId == player1;
          //  لوجيك النقل التلقائي للاتنين في نفس اللحظة
          if (status == 'playing' && !_isPlaying) {
            _isPlaying = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GameScreen(roomCode: widget.roomCode),
                ),
              );
              // لما نرجع من اللعبة، بنرجع المتغير لأصله عشان لو لعبوا جيم تاني
              _isPlaying = false;
            });
          }
          // لوجيك الطرد للضيف (يرجعه للصفحة الرئيسية)
          if (!isCreator && player2 != currentUserId && status == 'waiting') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              //يرجع للصفحه بعد مايبني الشاشه الجديده
              if (mounted) Navigator.pop(context);
            });
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Room Code: ${widget.roomCode}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 40),

                // بيانات صاحب الغرفة
                const Text(
                  'Player 1 (Creator):',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const Text(
                  'Ready (X)',
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // بيانات الضيف
                const Text(
                  'Player 2 (Joiner):',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                player2.isEmpty
                    ? const Text(
                        'Waiting...',
                        style: TextStyle(
                          fontSize: 22,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    : const Text(
                        'Joined (O)',
                        style: TextStyle(
                          fontSize: 22,
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                const SizedBox(height: 50),

                // أزرار التحكم بناءً على صلاحية المستخدم
                if (isCreator) ...[
                  if (player2.isNotEmpty) ...[
                    ElevatedButton(
                      onPressed: _startGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                      ),
                      child: const Text(
                        'Start Game',
                        style: TextStyle(fontSize: 20, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: _kickPlayer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      child: const Text(
                        'Kick Player',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ] else ...[
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 15),
                    const Text(
                      'Waiting for opponent to join...',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ] else ...[
                  const Text(
                    'Waiting for creator to start...',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _leaveRoom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      'Leave Room',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
