import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
// هننشئ الملف ده في الخطوة الجاية
import 'room_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void _createRoom() async {
    String roomCode = (Random().nextInt(90000) + 10000).toString();

    await FirebaseFirestore.instance.collection('rooms').doc(roomCode).set({
      'player1': FirebaseAuth.instance.currentUser!.uid,
      'player2': '',
      'board': ['', '', '', '', '', '', '', '', ''],
      'turn': 'X',
      'status': 'waiting',
    });

    if (!mounted) return;
    // النقل لشاشة الانتظار (Lobby) بدل شاشة اللعب
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RoomScreen(roomCode: roomCode)),
    );
  }

  void _joinRoom(String roomCode) async {
    await FirebaseFirestore.instance.collection('rooms').doc(roomCode).update({
      //هنا مستخدمناش set عشان الاوضه كانت اصلا موجوده
      'player2': FirebaseAuth.instance.currentUser!.uid,
      // مش بنغير الحالة لـ playing هنا! صاحب الغرفة هو اللي بيعملها من الـ RoomScreen
    });

    if (!mounted) return;
    // النقل لشاشة الانتظار (Lobby)

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RoomScreen(roomCode: roomCode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Available Rooms',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
          ),
        ],
      ),

      // جلب الغرف المتاحة (اللي حالتها waiting)
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rooms')
            .where('status', isEqualTo: 'waiting')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No rooms available.\nCreate one!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Colors.white54),
              ),
            );
          }

          var rooms = snapshot.data!.docs;

          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              var roomData = rooms[index].data() as Map<String, dynamic>;
              String roomId = rooms[index].id;

              // بنخفي الغرفة لو المستخدم الحالي هو اللي عاملها (عشان ميدخلش ضد نفسه)
              if (roomData['player1'] ==
                  FirebaseAuth.instance.currentUser!.uid) {
                return const SizedBox();
              }

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                color: Colors.blueGrey.shade800,
                child: ListTile(
                  title: Text(
                    'Room: $roomId',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Waiting for player...',
                    style: TextStyle(color: Colors.white70),
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.shade700,
                    ),
                    onPressed: () => _joinRoom(roomId),
                    child: const Text(
                      'Join',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),

      // زرار إنشاء الغرفة (FAB) حسب المطلوب في الـ PDF
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRoom,
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Create Room',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
