import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const SomaRaizApp());
}

class SomaRaizApp extends StatelessWidget {
  const SomaRaizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soma-Raiz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121214),
        primaryColor: const Color(0xFF00B37E),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00B37E),
          surface: const Color(0xFF202024),
        ),
      ),
      home: const GameScreen(),
    );
  }
}

class CellData {
  int value;
  String operation; // '+' ou 'x'

  CellData({required this.value, required this.operation});
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late List<List<CellData?>> board;
  int score = 0;
  final Random random = Random();

  Offset? _pointerDownPos;

  @override
  void initState() {
    super.initState();
    _initializeBoard();
  }

  void _initializeBoard() {
    board = List.generate(4, (_) => List.filled(4, null));
    score = 0;
    _addRandomTile();
    _addRandomTile();
    setState(() {});
  }

  void _addRandomTile() {
    List<Point<int>> emptyCells = [];
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        if (board[r][c] == null) {
          emptyCells.add(Point(r, c));
        }
      }
    }

    if (emptyCells.isNotEmpty) {
      Point<int> pos = emptyCells[random.nextInt(emptyCells.length)];
      List<String> ops = ['+', 'x'];
      board[pos.x][pos.y] = CellData(
        value: random.nextDouble() < 0.8 ? 2 : 4,
        operation: ops[random.nextInt(ops.length)],
      );
    }
  }

  CellData _calculateCollision(CellData a, CellData b) {
    int res = (a.operation == '+') ? (a.value + b.value) : (a.value * b.value);
    score += res;
    
    if (res > 99) {
      res = sqrt(res).round();
    }
    return CellData(value: res, operation: a.operation);
  }

  void _move(String direction) {
    bool moved = false;

    int rotations = 0;
    if (direction == 'up') rotations = 3;
    if (direction == 'right') rotations = 2;
    if (direction == 'down') rotations = 1;

    for (int i = 0; i < rotations; i++) {
      _rotateBoardClockwise();
    }

    for (int r = 0; r < 4; r++) {
      List<CellData> row = board[r].where((cell) => cell != null).cast<CellData>().toList();
      List<CellData> newRow = [];
      
      int i = 0;
      while (i < row.length) {
        if (i + 1 < row.length && row[i].value == row[i + 1].value) {
          newRow.add(_calculateCollision(row[i], row[i + 1]));
          i += 2;
          moved = true;
        } else {
          newRow.add(row[i]);
          i++;
        }
      }

      while (newRow.length < 4) {
        newRow.add(null as CellData);
      }

      for (int c = 0; c < 4; c++) {
        if (board[r][c]?.value != newRow[c]?.value || board[r][c]?.operation != newRow[c]?.operation) {
          moved = true;
        }
        board[r][c] = newRow[c];
      }
    }

    for (int i = 0; i < (4 - rotations) % 4; i++) {
      _rotateBoardClockwise();
    }

    if (moved) {
      _addRandomTile();
      setState(() {});
    }
  }

  void _rotateBoardClockwise() {
    List<List<CellData?>> temp = List.generate(4, (_) => List.filled(4, null));
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        temp[c][3 - r] = board[r][c];
      }
    }
    board = temp;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soma-Raiz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            double boardSize = constraints.maxWidth > 400 ? 380 : constraints.maxWidth * 0.9;

            return Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Painel de Pontuação
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF202024),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'PONTOS: $score',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00B37E),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Tabuleiro com Listener de Toque Direto (Cru)
                    Center(
                      child: Listener(
                        onPointerDown: (event) {
                          _pointerDownPos = event.position;
                        },
                        onPointerUp: (event) {
                          if (_pointerDownPos == null) return;
                          
                          Offset pointerUpPos = event.position;
                          double dx = pointerUpPos.dx - _pointerDownPos!.dx;
                          double dy = pointerUpPos.dy - _pointerDownPos!.dy;
                          
                          _pointerDownPos = null;

                          // Limite mínimo de 25 pixels para registrar o deslize
                          if (dx.abs() > dy.abs()) {
                            if (dx > 25) {
                              _move('right');
                            } else if (dx < -25) {
                              _move('left');
                            }
                          } else {
                            if (dy > 25) {
                              _move('down');
                            } else if (dy < -25) {
                              _move('up');
                            }
                          }
                        },
                        child: Container(
                          width: boardSize,
                          height: boardSize,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF29292E),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: 16,
                            itemBuilder: (context, index) {
                              int r = index ~/ 4;
                              int c = index % 4;
                              CellData? cell = board[r][c];

                              return Container(
                                decoration: BoxDecoration(
                                  color: cell != null ? const Color(0xFF3C3C43) : const Color(0xFF323238),
                                  borderRadius: BorderRadius.circular(10),
                                  border: cell != null 
                                      ? Border.all(color: const Color(0xFF00B37E), width: 2) 
                                      : null,
                                ),
                                child: cell != null
                                    ? Stack(
                                        children: [
                                          Positioned(
                                            top: 4,
                                            left: 6,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: cell.operation == '+' ? Colors.green.shade800 : Colors.blue.shade800,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                cell.operation,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Center(
                                            child: Padding(
                                              padding: const EdgeInsets.only(top: 10.0),
                                              child: Text(
                                                '${cell.value}',
                                                style: TextStyle(
                                                  fontSize: cell.value.toString().length > 3 ? 20 : 24,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : const SizedBox.expand(),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    // Botão de Reiniciar
                    ElevatedButton.icon(
                      onPressed: _initializeBoard,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reiniciar Jogo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B37E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}