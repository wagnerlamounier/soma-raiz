import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// O que aconteceu com a peça na última jogada (usado para animar).
enum TileEvent { none, spawned, merged, collapsed }

class CellData {
  static int _nextId = 0;

  /// Identificador único: quando muda, a animação da célula é reiniciada.
  final int id = _nextId++;

  int value;
  String operation; // '+' ou 'x'
  TileEvent event;

  CellData({
    required this.value,
    required this.operation,
    this.event = TileEvent.none,
  });
}

// ---------------------------------------------------------------------------
// TELA DE INSTRUÇÕES (COMO JOGAR)
// ---------------------------------------------------------------------------

/// Abre o modal de instruções.
void showHowToPlay(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const HowToPlaySheet(),
  );
}

class HowToPlaySheet extends StatelessWidget {
  const HowToPlaySheet({super.key});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF121214),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Alça visual do modal
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFF323238),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),

            // Título
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.help_outline, color: Color(0xFF00B37E), size: 28),
                SizedBox(width: 10),
                Text(
                  'Como Jogar',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Conteúdo rolável
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: const [
                  _RuleCard(
                    icon: Icons.swipe,
                    accent: Color(0xFF00B37E),
                    title: 'Objetivo',
                    text:
                        'Deslize o dedo sobre o tabuleiro 4x4 (ou use as setas) '
                        'para mover todas as peças na mesma direção. Quando duas '
                        'peças com o mesmo valor se encostam, elas se fundem em '
                        'uma só. Combine o máximo que conseguir para fazer '
                        'pontos e bater o seu recorde.',
                  ),
                  _RuleCard(
                    icon: Icons.calculate_outlined,
                    accent: Color(0xFF2E7D32),
                    title: 'Operações: + e x',
                    text:
                        'Cada peça tem uma operação no canto superior. Ao fundir '
                        'duas peças de mesmo valor, o resultado depende da '
                        'operação da peça que está na frente, no sentido do '
                        'movimento: se for "+", os valores são somados; se for '
                        '"x", são multiplicados. A nova peça mantém essa '
                        'operação.',
                    example: '4 +  4  =  8          3 x 3  =  9',
                    exampleNote: 'Só o valor precisa ser igual; as operações '
                        'das duas peças podem ser diferentes.',
                  ),
                  _RuleCard(
                    icon: Icons.functions,
                    accent: Color(0xFF1565C0),
                    title: 'Raiz Quadrada',
                    text:
                        'Se o resultado de uma fusão for maior que 99, o valor '
                        'sofre um colapso e vira a sua raiz quadrada, '
                        'arredondada. Isso mantém os números pequenos e o jogo '
                        'em andamento. Os pontos da jogada contam o resultado '
                        'antes do colapso.',
                    example: '64 + 64 = 128   →   √128 ≈ 11',
                  ),
                  _RuleCard(
                    icon: Icons.block,
                    accent: Color(0xFFC62828),
                    title: 'Fim de Jogo',
                    text:
                        'A partida termina quando o tabuleiro estiver cheio e '
                        'não houver mais nenhum movimento possível, ou seja, '
                        'nenhuma peça vizinha com o mesmo valor. Aí é só '
                        'tocar em "Tentar Novamente" e superar o recorde.',
                  ),
                  SizedBox(height: 8),
                ],
              ),
            ),

            // Rodapé com o botão
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text(
                      'Entendi / Voltar ao Jogo',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B37E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String text;
  final String? example;
  final String? exampleNote;

  const _RuleCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.text,
    this.example,
    this.exampleNote,
  });

  @override
  Widget build(BuildContext context) {
    const Color cardColor = Color(0xFF202024);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF29292E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(accent.withAlpha(60), cardColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00B37E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              color: Color(0xFFE1E1E6),
            ),
          ),
          if (example != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF121214),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                example!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
          if (exampleNote != null) ...[
            const SizedBox(height: 8),
            Text(
              exampleNote!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TELA DE FIM DE JOGO (OVERLAY)
// ---------------------------------------------------------------------------

class GameOverOverlay extends StatelessWidget {
  final int score;
  final int bestScore;
  final bool isNewRecord;
  final VoidCallback onRetry;

  const GameOverOverlay({
    super.key,
    required this.score,
    required this.bestScore,
    required this.isNewRecord,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    const Color green = Color(0xFF00B37E);

    final Widget card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF202024),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: green, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 179, 126, 0.25),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone de destaque
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color.fromRGBO(0, 179, 126, 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.flag_rounded, color: green, size: 34),
            ),
            const SizedBox(height: 16),

            // Título
            const Text(
              'FIM DE JOGO',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Não há mais movimentos possíveis',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),

            const SizedBox(height: 20),
            const Divider(color: Color(0xFF323238), height: 1),
            const SizedBox(height: 20),

            // Pontuação final
            const Text(
              'PONTUAÇÃO FINAL',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$score',
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                color: green,
                height: 1.1,
              ),
            ),

            const SizedBox(height: 14),

            // Selo de novo recorde
            if (isNewRecord) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events, color: Colors.white, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'NOVO RECORDE!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Recorde pessoal
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF121214),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'RECORDE PESSOAL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '$bestScore',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Botão
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  'Tentar Novamente',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        child: card,
        builder: (context, t, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: Color.fromRGBO(0, 0, 0, 0.8 * t),
            alignment: Alignment.center,
            child: SafeArea(
              child: SingleChildScrollView(
                child: Opacity(
                  opacity: t,
                  child: Transform.scale(
                    scale: 0.9 + 0.1 * t,
                    child: child,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TELA DO JOGO
// ---------------------------------------------------------------------------

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

  // Recorde que existia quando a partida atual começou.
  int _recordAtStart = 0;

  bool _gameOver = false;
  final Random random = Random();

  // O que aconteceu na última jogada (usado para a vibração).
  bool _mergedThisMove = false;
  bool _collapsedThisMove = false;

  // Posição inicial do toque (usada pelo Listener)
  Offset? _pointerStart;

  bool get _isNewRecord => score > 0 && score > _recordAtStart;

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
      setState(() {
        bestScore = saved;
        _recordAtStart = saved;
      });
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
    _recordAtStart = bestScore;
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
        event: TileEvent.spawned,
      );
    }
  }

  CellData _calculateCollision(CellData a, CellData b) {
    int res = (a.operation == '+') ? (a.value + b.value) : (a.value * b.value);
    score += res;

    final bool collapsed = res > 99;
    if (collapsed) {
      res = sqrt(res).round();
    }

    _mergedThisMove = true;
    if (collapsed) _collapsedThisMove = true;

    return CellData(
      value: res,
      operation: a.operation,
      event: collapsed ? TileEvent.collapsed : TileEvent.merged,
    );
  }

  /// Executa o movimento e retorna true se algo mudou no tabuleiro.
  bool _move(String direction) {
    bool moved = false;

    // Zera os marcadores da jogada anterior.
    _mergedThisMove = false;
    _collapsedThisMove = false;
    for (final List<CellData?> line in board) {
      for (final CellData? cell in line) {
        cell?.event = TileEvent.none;
      }
    }

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

  /// Vibração: leve para um movimento, média para fusão,
  /// e dois toques médios seguidos para um colapso (raiz quadrada).
  void _playFeedback() {
    if (_collapsedThisMove) {
      HapticFeedback.mediumImpact();
      Future.delayed(
        const Duration(milliseconds: 90),
        () => HapticFeedback.mediumImpact(),
      );
    } else if (_mergedThisMove) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
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

      _playFeedback();

      final bool beatBest = score > bestScore;
      setState(() {
        if (beatBest) bestScore = score;
        if (_isGameOver()) _gameOver = true;
      });

      if (beatBest) _saveBestScore();
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

  Widget _buildEmptyCell() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF323238),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildTileBody(CellData cell) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3C3C43),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00B37E), width: 2),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 4,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
      ),
    );
  }

  /// Aplica um "pop" de escala. A chave com o id da peça faz a animação
  /// reiniciar sempre que uma peça nova ocupa a posição.
  Widget _buildPop(
    CellData cell,
    Widget child, {
    required double begin,
    required Duration duration,
    required Curve curve,
  }) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(cell.id),
      tween: Tween<double>(begin: begin, end: 1.0),
      duration: duration,
      curve: curve,
      child: child,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
    );
  }

  Widget _buildCell(CellData? cell) {
    if (cell == null) return _buildEmptyCell();

    final Widget tile = _buildTileBody(cell);

    switch (cell.event) {
      case TileEvent.spawned:
        // Peça nova: cresce a partir do centro.
        return _buildPop(
          cell,
          tile,
          begin: 0.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
        );
      case TileEvent.merged:
        // Fusão: leve "batida" elástica.
        return _buildPop(
          cell,
          tile,
          begin: 0.75,
          duration: const Duration(milliseconds: 350),
          curve: Curves.elasticOut,
        );
      case TileEvent.collapsed:
        // Colapso: batida mais forte, para dar destaque.
        return _buildPop(
          cell,
          tile,
          begin: 0.4,
          duration: const Duration(milliseconds: 450),
          curve: Curves.elasticOut,
        );
      case TileEvent.none:
        return tile;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text(
              'Soma-Raiz',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Como jogar',
                icon: const Icon(Icons.help_outline, size: 28),
                color: const Color(0xFF00B37E),
                onPressed: () => showHowToPlay(context),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Reserva espaço para pontuação, setas e botão de reiniciar
                final double boardSize = max(
                  200.0,
                  min(
                    380.0,
                    min(constraints.maxWidth * 0.9,
                        constraints.maxHeight - 260),
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
        ),

        // Overlay de fim de jogo cobrindo a tela inteira
        if (_gameOver)
          GameOverOverlay(
            score: score,
            bestScore: bestScore,
            isNewRecord: _isNewRecord,
            onRetry: _restartGame,
          ),
      ],
    );
  }
}