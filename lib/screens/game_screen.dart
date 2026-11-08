import 'dart:async'; //   المكتبة دي عشان التايمر
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GameScreen extends StatefulWidget {
  final String roomCode;
  const GameScreen({super.key, required this.roomCode});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  //  متغيرات التايمر والتحكم في الشاشة
  Timer? _timer;
  int _secondsLeft = 30;
  String _lastTurn = '';
  bool _isNavigating = false; // عشان نمنع الشاشة ترجع مرتين

  // دالة تشغيل التايمر
  void _startTimer(String currentTurn) {
    _timer?.cancel(); // بنقفل أي تايمر قديم
    setState(() {
      _secondsLeft = 30;
    }); // بنبدأ من 30 ثانية

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        // الوقت خلص! نعكس الدور ونحدث الفايربيس
        _timer?.cancel();
        String nextTurn = currentTurn == 'X' ? 'O' : 'X';
        FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomCode)
            .update({'turn': nextTurn});
      }
    });
  }

  // تنظيف التايمر لما نخرج من الشاشة عشان التطبيق ميهنجش
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _checkWinner(List<dynamic> board) {
    List<List<int>> winLines = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];

    for (var line in winLines) {
      if (board[line[0]] != '' &&
          board[line[0]] == board[line[1]] &&
          board[line[0]] == board[line[2]]) {
        return board[line[0]]; // هترجع X أو O
      }
    }
    if (!board.contains('')) return 'Draw';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Room: ${widget.roomCode}',
          style: const TextStyle(letterSpacing: 2),
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
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Room not found!',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          var roomData = snapshot.data!.data() as Map<String, dynamic>;
          String status = roomData['status'];

          if (status == 'waiting') {
            //الشرط ده بيجمد الشاشه لغايه ما الاتنين لاعيبه يخشو الروم
            return const Center(
              child: Text(
                'Waiting for player 2...',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            );
          }

          List<dynamic> board = roomData['board'];
          String winner =
              roomData.containsKey(
                'winner',
              ) //استخدمنا containkey عشان نسال هل فيه winner ولا لسه
              ? roomData['winner']
              : '';
          String currentTurn = roomData['turn'];

          //  تشغيل التايمر أوتوماتيك لما الدور يتغير
          if (currentTurn != _lastTurn && winner == '') {
            _lastTurn = currentTurn;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _startTimer(currentTurn);
            });
          }

          //  إنهاء اللعبة والرجوع للغرفة تلقائياً
          if (winner != '' && !_isNavigating) {
            _isNavigating = true; // عشان نمنع انه يعمل navigate.pop اكتر من مره
            _timer?.cancel();

            Future.delayed(const Duration(seconds: 3), () async {
              // صاحب الغرفة بس هو اللي بيصفر الداتا عشان ميحصلش تعارض مع السيرفر
              if (FirebaseAuth.instance.currentUser!.uid ==
                  roomData['player1']) {
                await FirebaseFirestore.instance
                    .collection('rooms')
                    .doc(widget.roomCode)
                    .update({
                      'board': ['', '', '', '', '', '', '', '', ''],
                      'turn': 'X',
                      'winner': '',
                      'status': 'waiting',
                    });
              }
              if (mounted) Navigator.pop(context);
            });
          }
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              //  عرض التايمر والدور
              Text(
                winner == '' ? "Turn: $currentTurn" : "Game Over!",
                style: const TextStyle(
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              if (winner == '')
                Text(
                  "Time Left: $_secondsLeft",
                  style: TextStyle(
                    fontSize: 22,
                    color: _secondsLeft <= 5
                        ? Colors.red
                        : Colors.yellow, // بيحمر في آخر 5 ثواني
                  ),
                ),

              //  شبكة اللعب
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: 9,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                  ),
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () async {
                        //  تحديد مين اللي ماسك الموبايل دلوقتي ومين اللاعبين
                        String currentUserId =
                            FirebaseAuth.instance.currentUser!.uid;
                        String player1 = roomData['player1']; // صاحب الغرفة (X)
                        String player2 = roomData['player2']; // الضيف (O)

                        //   هل ده دور اللاعب اللي ماسك الموبايل؟
                        bool isMyTurn =
                            (currentTurn == 'X' && currentUserId == player1) ||
                            (currentTurn == 'O' && currentUserId == player2);

                        //  بنسمح باللعب بس لو كان دورك فعلاً، والمربع فاضي
                        if (isMyTurn && board[index] == '' && winner == '') {
                          board[index] = currentTurn;
                          String newWinner = _checkWinner(board);
                          String nextTurn = currentTurn == 'X' ? 'O' : 'X';

                          //  رفع الإحصائيات بالحل الجديد
                          if (newWinner != '') {
                            var addWin = {'Wins': FieldValue.increment(1)};
                            var addLoss = {'Losses': FieldValue.increment(1)};
                            var addDraw = {'Draws': FieldValue.increment(1)};
                            var mergeOpt = SetOptions(merge: true);

                            if (newWinner == 'Draw') {
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(player1)
                                  .set(addDraw, mergeOpt);
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(player2)
                                  .set(addDraw, mergeOpt);
                            } else if (newWinner == 'X') {
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(player1)
                                  .set(addWin, mergeOpt);
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(player2)
                                  .set(addLoss, mergeOpt);
                            } else if (newWinner == 'O') {
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(player2)
                                  .set(addWin, mergeOpt);
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(player1)
                                  .set(addLoss, mergeOpt);
                            }
                          }

                          //  تحديث السيرفر باللعبه الجديدة اللعبتها
                          await FirebaseFirestore.instance
                              .collection('rooms')
                              .doc(widget.roomCode)
                              .update({
                                'board': board,
                                'turn': nextTurn,
                                'winner': newWinner,
                              });
                        } else if (!isMyTurn &&
                            winner == '' &&
                            board[index] == '') {
                          // تنبيه سريع لو دوست في غير دورك
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Wait for your opponent's move!"),
                              duration: Duration(milliseconds: 500),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.all(5),
                        color: Colors.blueGrey,
                        child: Center(
                          child: Text(
                            board[index],
                            style: const TextStyle(
                              fontSize: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              //  إعلان النتيجة
              if (winner != '') ...[
                const SizedBox(height: 20),
                Text(
                  winner == 'Draw' ? "It's a Draw! " : "Player $winner Won! ",
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Returning to room...",
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
