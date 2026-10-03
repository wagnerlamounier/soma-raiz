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
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00B37E),
          surface: Color(0xFF202024),
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

  // Posição inicial do toque (usada pelo Listener)
  Offset? _pointerStart;

  // Texto de diagnóstico mostrado na tela (pode remover depois)
  String _debugInfo = 'Aguardando gesto...';

  @override
  void initState() {
    super.initState();
    _resetBoard();
  }

  void _resetBoard() {
    board = List.generate(4, (_) => List<CellData?>.filled(4, null));
    score = 0;
    _addRandomTile();
    _addRandomTile();
  }

  void _restartGame() {
    setState(() {
      _resetBoard();
      _debugInfo = 'Jogo reiniciado';
    });
  }

  void _addRandomTile() {
    final List<Point<int>> emptyCells = [];
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        if (board[r][c] == null) {
          emptyCells.add(Point(r, c));
        }
      }
    }

    if (emptyCells.isNotEmpty) {
      final Point<int> pos = emptyCells[random.nextInt(emptyCells.length)];
      const List<String> ops = ['+', 'x'];
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
      final List<CellData> row = board[r].whereType<CellData>().toList();
      final List<CellData?> newRow = [];

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
        newRow.add(null);
      }

      for (int c = 0; c < 4; c++) {
        if (board[r][c]?.value != newRow[c]?.value ||
            board[r][c]?.operation != newRow[c]?.operation) {
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
    }
  }

  void _rotateBoardClockwise() {
    final List<List<CellData?>> temp =
        List.generate(4, (_) => List<CellData?>.filled(4, null));
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        temp[c][3 - r] = board[r][c];
      }
    }
    board = temp;
  }

  void _handleSwipe(double dx, double dy) {
    const double minDistance = 30;
    String direction = 'nenhuma (gesto curto)';

    try {
      if (dx.abs() > dy.abs()) {
        if (dx > minDistance) {
          direction = 'right';
          _move('right');
        } else if (dx < -minDistance) {
          direction = 'left';
          _move('left');
        }
      } else {
        if (dy > minDistance) {
          direction = 'down';
          _move('down');
        } else if (dy < -minDistance) {
          direction = 'up';
          _move('up');
        }
      }

      setState(() {
        _debugInfo =
            'Gesto: $direction | dx=${dx.toStringAsFixed(0)} dy=${dy.toStringAsFixed(0)}';
      });
    } catch (e, st) {
      debugPrint('Erro no movimento: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    }
  }

  Widget _buildCell(CellData? cell) {
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: cell.operation == '+'
                          ? Colors.green.shade800
                          : Colors.blue.shade800,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Soma-Raiz',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double boardSize = min(
              380.0,
              min(constraints.maxWidth * 0.9, constraints.maxHeight * 0.55),
            );

            return Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Painel de pontuação
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
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

                    // Tabuleiro com leitura direta dos toques (Listener)
                    Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e) => _pointerStart = e.position,
                      onPointerUp: (e) {
                        final start = _pointerStart;
                        _pointerStart = null;
                        if (start == null) return;
                        final d = e.position - start;
                        _handleSwipe(d.dx, d.dy);
                      },
                      onPointerCancel: (_) => _pointerStart = null,
                      child: Container(
                        width: boardSize,
                        height: boardSize,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF29292E),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(0, 0, 0, 0.4),
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: IgnorePointer(
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: 16,
                            itemBuilder: (context, index) {
                              final int r = index ~/ 4;
                              final int c = index % 4;
                              return _buildCell(board[r][c]);
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Texto de diagnóstico (temporário)
                    Text(
                      _debugInfo,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),

                    // Botões de seta para teste (temporários)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => _handleSwipe(-100, 0),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        IconButton(
                          onPressed: () => _handleSwipe(0, -100),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          onPressed: () => _handleSwipe(0, 100),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        IconButton(
                          onPressed: () => _handleSwipe(100, 0),
                          icon: const Icon(Icons.arrow_forward),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Botão de reiniciar
                    ElevatedButton.icon(
                      onPressed: _restartGame,
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'Reiniciar Jogo',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B37E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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