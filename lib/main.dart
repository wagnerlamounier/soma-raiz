import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _bestScoreKey = 'best_score';

  late List<List<CellData?>> board;
  int score = 0;
  int bestScore = 0;
  bool _gameOver = false;
  final Random random = Random();

  // Posição inicial do toque (usada pelo Listener)
  Offset? _pointerStart;

  @override
  void initState() {
    super.initState();
    _resetBoard();
    _loadBestScore();
  }

  Future<void> _loadBestScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_bestScoreKey) ?? 0;
      if (!mounted) return;
      setState(() => bestScore = saved);
    } catch (e) {
      debugPrint('Erro ao carregar recorde: $e');
    }
  }

  Future<void> _saveBestScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestScoreKey, bestScore);
    } catch (e) {
      debugPrint('Erro ao salvar recorde: $e');
    }
  }

  void _resetBoard() {
    board = List.generate(4, (_) => List<CellData?>.filled(4, null));
    score = 0;
    _gameOver = false;
    _addRandomTile();
    _addRandomTile();
  }

  void _restartGame() {
    setState(_resetBoard);
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

  /// Executa o movimento e retorna true se algo mudou no tabuleiro.
  bool _move(String direction) {
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
    return moved;
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

  /// Fim de jogo: tabuleiro cheio e nenhum par de vizinhos com o mesmo valor.
  bool _isGameOver() {
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        final cell = board[r][c];
        if (cell == null) return false;
        if (c + 1 < 4 && board[r][c + 1]?.value == cell.value) return false;
        if (r + 1 < 4 && board[r + 1][c]?.value == cell.value) return false;
      }
    }
    return true;
  }

  void _handleSwipe(double dx, double dy) {
    if (_gameOver) return;

    const double minDistance = 30;
    String? direction;

    if (dx.abs() > dy.abs()) {
      if (dx > minDistance) {
        direction = 'right';
      } else if (dx < -minDistance) {
        direction = 'left';
      }
    } else {
      if (dy > minDistance) {
        direction = 'down';
      } else if (dy < -minDistance) {
        direction = 'up';
      }
    }

    if (direction == null) return;

    try {
      final bool moved = _move(direction);
      if (!moved) return;

      final bool newRecord = score > bestScore;
      setState(() {
        if (newRecord) bestScore = score;
        if (_isGameOver()) _gameOver = true;
      });

      if (newRecord) _saveBestScore();
    } catch (e, st) {
      debugPrint('Erro no movimento: $e\n$st');
    }
  }

  Widget _buildScoreBox(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF202024),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00B37E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrowButton(IconData icon, double dx, double dy) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: 64,
        height: 64,
        child: IconButton(
          onPressed: () => _handleSwipe(dx, dy),
          icon: Icon(icon, size: 32),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF202024),
            foregroundColor: const Color(0xFF00B37E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
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

  Widget _buildGameOverOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromRGBO(0, 0, 0, 0.75),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'FIM DE JOGO',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pontos: $score',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00B37E),
              ),
            ),
            if (score > 0 && score >= bestScore)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Novo recorde!',
                  style: TextStyle(fontSize: 16, color: Colors.amber),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _restartGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B37E),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Jogar novamente',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
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
            // Reserva espaço para pontuação, setas e botão de reiniciar
            final double boardSize = max(
              200.0,
              min(
                380.0,
                min(constraints.maxWidth * 0.9, constraints.maxHeight - 260),
              ),
            );

            return Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Pontuação e recorde
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildScoreBox('PONTOS', score),
                        const SizedBox(width: 12),
                        _buildScoreBox('RECORDE', bestScore),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tabuleiro com leitura direta dos toques (Listener)
                    Stack(
                      children: [
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
                        if (_gameOver) _buildGameOverOverlay(),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Botões de seta (alternativa ao deslize)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildArrowButton(Icons.arrow_back, -100, 0),
                        _buildArrowButton(Icons.arrow_upward, 0, -100),
                        _buildArrowButton(Icons.arrow_downward, 0, 100),
                        _buildArrowButton(Icons.arrow_forward, 100, 0),
                      ],
                    ),

                    const SizedBox(height: 16),

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
                    const SizedBox(height: 12),
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