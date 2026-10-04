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
      home: const HomeScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// CONFIGURAÇÕES GERAIS
// ---------------------------------------------------------------------------

const Color kBackground = Color(0xFF121214);
const Color kCardColor = Color(0xFF202024);
const Color kGreen = Color(0xFF00B37E);
const Color kBoardColor = Color(0xFF29292E);
const Color kEmptyCellColor = Color(0xFF323238);

// ---------------------------------------------------------------------------
// MODOS LIVRES
// ---------------------------------------------------------------------------

enum BoardMode {
  compact(3, 'Compacto', '3x3', 'best_score_3x3'),
  classic(4, 'Clássico', '4x4', 'best_score'),
  expanded(5, 'Expandido', '5x5', 'best_score_5x5');

  final int size;
  final String label;
  final String dims;
  final String storageKey;

  const BoardMode(
    this.size,
    this.label,
    this.dims,
    this.storageKey,
  );
}

// ---------------------------------------------------------------------------
// CAMPANHA
// ---------------------------------------------------------------------------

class CampaignLevel {
  final int number;
  final int world;
  final String name;
  final int boardSize;
  final int targetScore;
  final int? targetValue;
  final int? maxMoves;
  final bool allowMultiplication;
  final bool allowCollapse;
  final bool allowMultiplesOfThree;

  const CampaignLevel({
    required this.number,
    required this.world,
    required this.name,
    required this.boardSize,
    required this.targetScore,
    this.targetValue,
    this.maxMoves,
    required this.allowMultiplication,
    required this.allowCollapse,
    required this.allowMultiplesOfThree,
  });

  String get worldName {
    switch (world) {
      case 1:
        return 'Vale das Sombras';
      case 2:
        return 'Floresta dos Produtos';
      case 3:
        return 'Templo das Raízes';
      default:
        return 'Mundo $world';
    }
  }

  String get objective {
    if (targetValue != null) {
      return 'Forme uma peça de valor $targetValue';
    }

    if (maxMoves != null) {
      return 'Faça $targetScore pontos em até $maxMoves jogadas';
    }

    return 'Faça $targetScore pontos';
  }
}

final List<CampaignLevel> campaignLevels = _createCampaignLevels();

List<CampaignLevel> _createCampaignLevels() {
  final List<CampaignLevel> levels = [];

  for (int i = 1; i <= 10; i++) {
    levels.add(
      CampaignLevel(
        number: i,
        world: 1,
        name: i == 10 ? 'A primeira grande prova' : 'Primeiros passos $i',
        boardSize: i <= 3 ? 4 : 3,
        targetScore: 20 + (i * 15),
        targetValue: i == 1 ? 8 : null,
        maxMoves: i >= 5 ? 35 - i : null,
        allowMultiplication: false,
        allowCollapse: false,
        allowMultiplesOfThree: false,
      ),
    );
  }

  for (int i = 11; i <= 20; i++) {
    levels.add(
      CampaignLevel(
        number: i,
        world: 2,
        name: i == 20 ? 'O desafio dos produtos' : 'Força multiplicadora $i',
        boardSize: i <= 14 ? 4 : 3,
        targetScore: 180 + ((i - 10) * 55),
        targetValue: i == 12
            ? 16
            : i == 16
                ? 32
                : null,
        maxMoves: i >= 16 ? 34 - (i - 16) : null,
        allowMultiplication: true,
        allowCollapse: false,
        allowMultiplesOfThree: false,
      ),
    );
  }

  for (int i = 21; i <= 30; i++) {
    levels.add(
      CampaignLevel(
        number: i,
        world: 3,
        name: i == 30 ? 'O templo da raiz' : 'Caminho das raízes $i',
        boardSize: i <= 24 ? 4 : 3,
        targetScore: 600 + ((i - 20) * 130),
        targetValue: i == 24
            ? 25
            : i == 28
                ? 36
                : null,
        maxMoves: i >= 26 ? 30 - (i - 26) : null,
        allowMultiplication: true,
        allowCollapse: true,
        allowMultiplesOfThree: i >= 25,
      ),
    );
  }

  return levels;
}

class CampaignProgress {
  static const String unlockedKey = 'campaign_unlocked_level';
  static const String starsPrefix = 'campaign_stars_';
  static const String scorePrefix = 'campaign_score_';

  int unlockedLevel = 1;
  final Map<int, int> stars = {};
  final Map<int, int> bestScores = {};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    unlockedLevel = prefs.getInt(unlockedKey) ?? 1;

    for (final level in campaignLevels) {
      stars[level.number] = prefs.getInt(
            '$starsPrefix${level.number}',
          ) ??
          0;

      bestScores[level.number] = prefs.getInt(
            '$scorePrefix${level.number}',
          ) ??
          0;
    }
  }

  Future<void> saveLevelResult({
    required int levelNumber,
    required int earnedStars,
    required int score,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final int oldStars = stars[levelNumber] ?? 0;
    final int oldScore = bestScores[levelNumber] ?? 0;

    final int finalStars = max(oldStars, earnedStars);
    final int finalScore = max(oldScore, score);

    stars[levelNumber] = finalStars;
    bestScores[levelNumber] = finalScore;

    if (levelNumber >= unlockedLevel &&
        levelNumber < campaignLevels.length) {
      unlockedLevel = levelNumber + 1;
    }

    await prefs.setInt(unlockedKey, unlockedLevel);
    await prefs.setInt('$starsPrefix$levelNumber', finalStars);
    await prefs.setInt('$scorePrefix$levelNumber', finalScore);
  }

  int starsFor(int levelNumber) => stars[levelNumber] ?? 0;

  int bestScoreFor(int levelNumber) => bestScores[levelNumber] ?? 0;

  int get totalStars {
    return stars.values.fold(0, (total, value) => total + value);
  }
}

// ---------------------------------------------------------------------------
// PEÇAS
// ---------------------------------------------------------------------------

enum TileEvent {
  none,
  spawned,
  merged,
  collapsed,
}

class CellData {
  static int _nextId = 0;

  final int id = _nextId++;

  int value;
  String operation;
  TileEvent event;

  CellData({
    required this.value,
    required this.operation,
    this.event = TileEvent.none,
  });
}

// ---------------------------------------------------------------------------
// TELA INICIAL
// ---------------------------------------------------------------------------

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openCampaign(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CampaignScreen(),
      ),
    );
  }

  void _openFreeGame(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GameScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: const Color(0xFF075E4A),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 179, 126, 0.25),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.functions,
                    color: Colors.white,
                    size: 68,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Soma-Raiz',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Um desafio matemático diferente',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 46),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed: () => _openCampaign(context),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text(
                      'Jogar Campanha',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: () => _openFreeGame(context),
                    icon: const Icon(Icons.all_inclusive),
                    label: const Text(
                      'Modo Livre',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kGreen,
                      side: const BorderSide(color: kGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Combine. Multiplique. Supere seus limites.',
                  style: TextStyle(
                    color: Color(0xFF77777F),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MAPA DA CAMPANHA
// ---------------------------------------------------------------------------

class CampaignScreen extends StatefulWidget {
  const CampaignScreen({super.key});

  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> {
  final CampaignProgress progress = CampaignProgress();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    await progress.load();

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  Future<void> _openLevel(CampaignLevel level) async {
    if (level.number > progress.unlockedLevel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete a fase anterior para desbloquear esta.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(campaignLevel: level),
      ),
    );

    await _loadProgress();
  }

  Widget _buildStars(int amount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (index) => Icon(
          index < amount ? Icons.star : Icons.star_border,
          color: index < amount
              ? const Color(0xFFFFC107)
              : const Color(0xFF66666D),
          size: 18,
        ),
      ),
    );
  }

  Widget _buildLevelCard(CampaignLevel level) {
    final bool unlocked = level.number <= progress.unlockedLevel;
    final int stars = progress.starsFor(level.number);
    final bool isCurrent = level.number == progress.unlockedLevel;

    return GestureDetector(
      onTap: () => _openLevel(level),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: unlocked ? 1 : 0.45,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrent ? kGreen : const Color(0xFF303036),
              width: isCurrent ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: unlocked ? kGreen : const Color(0xFF3A3A40),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: unlocked
                      ? Text(
                          '${level.number}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 19,
                          ),
                        )
                      : const Icon(
                          Icons.lock,
                          color: Colors.grey,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      level.objective,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                    if (stars > 0) ...[
                      const SizedBox(height: 5),
                      _buildStars(stars),
                    ],
                  ],
                ),
              ),
              Icon(
                unlocked
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.lock_outline,
                color: unlocked ? kGreen : Colors.grey,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorld(int world) {
    final List<CampaignLevel> worldLevels =
        campaignLevels.where((level) => level.world == world).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 8),
          child: Text(
            worldLevels.first.worldName,
            style: const TextStyle(
              color: kGreen,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        ...worldLevels.map(_buildLevelCard),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: kBackground,
        body: Center(
          child: CircularProgressIndicator(color: kGreen),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text(
          'Campanha',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF075E4A),
                    Color(0xFF173A35),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 38,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Jornada Soma-Raiz',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Fases desbloqueadas: '
                          '${min(progress.unlockedLevel - 1, 30)}/30\n'
                          'Estrelas: ${progress.totalStars}/90',
                          style: const TextStyle(
                            color: Color(0xFFD5FFF2),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildWorld(1),
            _buildWorld(2),
            _buildWorld(3),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// COMO JOGAR
// ---------------------------------------------------------------------------

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
          color: kBackground,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
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
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.help_outline, color: kGreen, size: 28),
                SizedBox(width: 10),
                Text(
                  'Como Jogar',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: const [
                  _RuleCard(
                    icon: Icons.swipe,
                    accent: kGreen,
                    title: 'Objetivo',
                    text:
                        'Deslize sobre o tabuleiro ou use as setas para mover '
                        'as peças. Quando duas peças com o mesmo valor se '
                        'encostam, elas se fundem.',
                  ),
                  _RuleCard(
                    icon: Icons.grid_view_rounded,
                    accent: Color(0xFF6A1B9A),
                    title: 'Modos Livres',
                    text:
                        'No modo livre, escolha entre os tabuleiros 3x3, 4x4 '
                        'e 5x5. Cada tamanho possui seu próprio recorde.',
                  ),
                  _RuleCard(
                    icon: Icons.map_outlined,
                    accent: Color(0xFFFFA000),
                    title: 'Campanha',
                    text:
                        'Complete fases, conquiste estrelas e desbloqueie '
                        'novos desafios. Cada mundo acrescenta novas regras.',
                  ),
                  _RuleCard(
                    icon: Icons.calculate_outlined,
                    accent: Color(0xFF2E7D32),
                    title: 'Operações',
                    text:
                        'A peça pode ter operação de soma ou multiplicação. '
                        'O resultado usa a operação da peça que está na frente '
                        'no sentido do movimento.',
                    example: '4 + 4 = 8       3 x 3 = 9',
                  ),
                  _RuleCard(
                    icon: Icons.functions,
                    accent: Color(0xFF1565C0),
                    title: 'Raiz Quadrada',
                    text:
                        'Quando uma fusão produz resultado acima de 99, o '
                        'valor pode sofrer um colapso e virar sua raiz '
                        'quadrada arredondada.',
                    example: '64 + 64 = 128 → √128 ≈ 11',
                  ),
                  _RuleCard(
                    icon: Icons.block,
                    accent: Color(0xFFC62828),
                    title: 'Fim de Jogo',
                    text:
                        'No modo livre, a partida termina quando o tabuleiro '
                        'está cheio e não existem mais combinações possíveis.',
                  ),
                  SizedBox(height: 8),
                ],
              ),
            ),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
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

  const _RuleCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.text,
    this.example,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
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
                  color: Color.alphaBlend(
                    accent.withAlpha(60),
                    kCardColor,
                  ),
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
                    color: kGreen,
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
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: kBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                example!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// OVERLAY DE GAME OVER DO MODO LIVRE
// ---------------------------------------------------------------------------

class GameOverOverlay extends StatelessWidget {
  final int score;
  final int bestScore;
  final bool isNewRecord;
  final String modeDims;
  final VoidCallback onRetry;

  const GameOverOverlay({
    super.key,
    required this.score,
    required this.bestScore,
    required this.isNewRecord,
    required this.modeDims,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _OverlayBackground(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kGreen, width: 2),
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
            const Icon(Icons.flag_rounded, color: kGreen, size: 58),
            const SizedBox(height: 14),
            const Text(
              'FIM DE JOGO',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Não há mais movimentos possíveis',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 22),
            const Text(
              'PONTUAÇÃO FINAL',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              '$score',
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                color: kGreen,
              ),
            ),
            if (isNewRecord) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: kGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'NOVO RECORDE!',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECORDE · $modeDims',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '$bestScore',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  'Tentar Novamente',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
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
  }
}

// ---------------------------------------------------------------------------
// OVERLAY DE RESULTADO DA CAMPANHA
// ---------------------------------------------------------------------------

class CampaignResultOverlay extends StatelessWidget {
  final CampaignLevel level;
  final int score;
  final int stars;
  final bool won;
  final VoidCallback onRetry;
  final VoidCallback onBackToMap;

  const CampaignResultOverlay({
    super.key,
    required this.level,
    required this.score,
    required this.stars,
    required this.won,
    required this.onRetry,
    required this.onBackToMap,
  });

  Widget _buildStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (index) => Icon(
          index < stars ? Icons.star : Icons.star_border,
          color: index < stars
              ? const Color(0xFFFFC107)
              : const Color(0xFF66666D),
          size: 42,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _OverlayBackground(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: won ? const Color(0xFFFFC107) : const Color(0xFFC62828),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              won ? Icons.emoji_events : Icons.replay_rounded,
              color: won ? const Color(0xFFFFC107) : const Color(0xFFC62828),
              size: 62,
            ),
            const SizedBox(height: 12),
            Text(
              won ? 'FASE CONCLUÍDA!' : 'TENTE NOVAMENTE',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Fase ${level.number} · ${level.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 18),
            if (won) _buildStars(),
            if (won) const SizedBox(height: 16),
            Text(
              'Pontuação: $score',
              style: const TextStyle(
                color: kGreen,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'Jogar Novamente',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: onBackToMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text(
                  'Voltar ao Mapa',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kGreen,
                  side: const BorderSide(color: kGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
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

class _OverlayBackground extends StatelessWidget {
  final Widget child;

  const _OverlayBackground({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color.fromRGBO(0, 0, 0, 0.82),
        alignment: Alignment.center,
        child: SafeArea(
          child: SingleChildScrollView(
            child: child,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TELA DO JOGO
// ---------------------------------------------------------------------------

class GameScreen extends StatefulWidget {
  final CampaignLevel? campaignLevel;

  const GameScreen({
    super.key,
    this.campaignLevel,
  });

  bool get isCampaign => campaignLevel != null;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  CampaignLevel? get campaignLevel => widget.campaignLevel;
  bool get isCampaign => campaignLevel != null;

  BoardMode _mode = BoardMode.classic;

  int get n => campaignLevel?.boardSize ?? _mode.size;

  late List<List<CellData?>> board;

  int score = 0;
  int bestScore = 0;

  int _recordAtStart = 0;

  bool _gameOver = false;
  bool _campaignWon = false;
  bool _campaignResultShown = false;

  int _campaignMoves = 0;
  int _campaignStars = 0;

  final Random random = Random();
  final CampaignProgress campaignProgress = CampaignProgress();

  bool _mergedThisMove = false;
  bool _collapsedThisMove = false;

  Offset? _pointerStart;

  bool get _isNewRecord {
    return score > 0 && score > _recordAtStart;
  }

  @override
  void initState() {
    super.initState();

    _resetBoard();

    if (isCampaign) {
      _loadCampaignProgress();
    } else {
      _loadBestScore();
    }
  }

  Future<void> _loadCampaignProgress() async {
    try {
      await campaignProgress.load();
    } catch (e) {
      debugPrint('Erro ao carregar campanha: $e');
    }
  }

  Future<void> _loadBestScore() async {
    final BoardMode mode = _mode;

    try {
      final prefs = await SharedPreferences.getInstance();
      final int saved = prefs.getInt(mode.storageKey) ?? 0;

      if (!mounted || mode != _mode) return;

      setState(() {
        bestScore = saved;
        _recordAtStart = saved;
      });
    } catch (e) {
      debugPrint('Erro ao carregar recorde: $e');
    }
  }

  Future<void> _saveBestScore() async {
    final BoardMode mode = _mode;
    final int value = bestScore;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(mode.storageKey, value);
    } catch (e) {
      debugPrint('Erro ao salvar recorde: $e');
    }
  }

  void _resetBoard() {
    board = List.generate(
      n,
      (_) => List<CellData?>.filled(n, null),
    );

    score = 0;
    _gameOver = false;
    _campaignWon = false;
    _campaignResultShown = false;
    _campaignMoves = 0;
    _campaignStars = 0;

    _recordAtStart = bestScore;

    _addRandomTile();
    _addRandomTile();
  }

  void _restartGame() {
    setState(_resetBoard);
  }

  Future<void> _requestModeChange(BoardMode mode) async {
    if (mode == _mode) return;

    if (score > 0 && !_gameOver) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: kCardColor,
            title: const Text('Trocar de modo?'),
            content: Text(
              'A partida atual será perdida ao mudar para '
              '${mode.label} (${mode.dims}).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Trocar',
                  style: TextStyle(color: kGreen),
                ),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;
    }

    if (!mounted) return;

    setState(() {
      _mode = mode;
      bestScore = 0;
      _resetBoard();
    });

    _loadBestScore();
  }

  void _addRandomTile() {
    final List<Point<int>> emptyCells = [];

    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (board[r][c] == null) {
          emptyCells.add(Point<int>(r, c));
        }
      }
    }

    if (emptyCells.isEmpty) return;

    final Point<int> position =
        emptyCells[random.nextInt(emptyCells.length)];

    final List<String> operations = ['+'];

    if (!isCampaign || campaignLevel!.allowMultiplication) {
      operations.add('x');
    }

    final double roll = random.nextDouble();
    final bool canSpawnThree =
        isCampaign && campaignLevel!.allowMultiplesOfThree;

    int value;

    if (canSpawnThree && roll < 0.15) {
      value = 3;
    } else if (roll < 0.80) {
      value = 2;
    } else {
      value = 4;
    }

    board[position.x][position.y] = CellData(
      value: value,
      operation: operations[random.nextInt(operations.length)],
      event: TileEvent.spawned,
    );
  }

  CellData _calculateCollision(CellData a, CellData b) {
    int result;

    if (a.operation == '+') {
      result = a.value + b.value;
    } else {
      result = a.value * b.value;
    }

    score += result;

    final bool collapsed = isCampaign
        ? campaignLevel!.allowCollapse && result > 99
        : result > 99;

    if (collapsed) {
      result = sqrt(result).round();
    }

    _mergedThisMove = true;

    if (collapsed) {
      _collapsedThisMove = true;
    }

    return CellData(
      value: result,
      operation: a.operation,
      event: collapsed ? TileEvent.collapsed : TileEvent.merged,
    );
  }

  bool _move(String direction) {
    bool moved = false;

    _mergedThisMove = false;
    _collapsedThisMove = false;

    for (final row in board) {
      for (final cell in row) {
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

    for (int r = 0; r < n; r++) {
      final List<CellData> row = board[r].whereType<CellData>().toList();
      final List<CellData?> newRow = [];

      int i = 0;

      while (i < row.length) {
        if (i + 1 < row.length &&
            row[i].value == row[i + 1].value) {
          newRow.add(
            _calculateCollision(row[i], row[i + 1]),
          );
          i += 2;
          moved = true;
        } else {
          newRow.add(row[i]);
          i++;
        }
      }

      while (newRow.length < n) {
        newRow.add(null);
      }

      for (int c = 0; c < n; c++) {
        final CellData? oldCell = board[r][c];
        final CellData? newCell = newRow[c];

        if (oldCell?.value != newCell?.value ||
            oldCell?.operation != newCell?.operation) {
          moved = true;
        }

        board[r][c] = newCell;
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
    final List<List<CellData?>> temporary = List.generate(
      n,
      (_) => List<CellData?>.filled(n, null),
    );

    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        temporary[c][n - 1 - r] = board[r][c];
      }
    }

    board = temporary;
  }

  bool _isGameOver() {
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final CellData? cell = board[r][c];

        if (cell == null) {
          return false;
        }

        if (c + 1 < n &&
            board[r][c + 1]?.value == cell.value) {
          return false;
        }

        if (r + 1 < n &&
            board[r + 1][c]?.value == cell.value) {
          return false;
        }
      }
    }

    return true;
  }

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
    if (_gameOver || _campaignWon) return;

    const double minimumDistance = 30;
    String? direction;

    if (dx.abs() > dy.abs()) {
      if (dx > minimumDistance) {
        direction = 'right';
      } else if (dx < -minimumDistance) {
        direction = 'left';
      }
    } else {
      if (dy > minimumDistance) {
        direction = 'down';
      } else if (dy < -minimumDistance) {
        direction = 'up';
      }
    }

    if (direction == null) return;

    try {
      final bool moved = _move(direction);

      if (!moved) return;

      if (isCampaign) {
        _campaignMoves++;
      }

      _playFeedback();

      final bool beatBest = score > bestScore;

      setState(() {
        if (beatBest) {
          bestScore = score;
        }

        if (isCampaign) {
          _checkCampaignStatus();
        } else if (_isGameOver()) {
          _gameOver = true;
        }
      });

      if (beatBest && !isCampaign) {
        _saveBestScore();
      }
    } catch (e, st) {
      debugPrint('Erro no movimento: $e\n$st');
    }
  }

  void _checkCampaignStatus() {
    final CampaignLevel? level = campaignLevel;

    if (level == null || _campaignWon || _gameOver) {
      return;
    }

    bool reachedScore = score >= level.targetScore;
    bool reachedValue = false;

    if (level.targetValue != null) {
      for (final row in board) {
        for (final cell in row) {
          if (cell?.value == level.targetValue) {
            reachedValue = true;
          }
        }
      }
    }

    final bool objectiveCompleted =
        level.targetValue != null ? reachedValue : reachedScore;

    final bool exceededMoves =
        level.maxMoves != null && _campaignMoves > level.maxMoves!;

    if (objectiveCompleted && !exceededMoves) {
      _campaignWon = true;

      final int movesRemaining = level.maxMoves == null
          ? 20
          : max(0, level.maxMoves! - _campaignMoves);

      _campaignStars = movesRemaining >= 15
          ? 3
          : movesRemaining >= 7
              ? 2
              : 1;

      _saveCampaignResult();
    } else if (exceededMoves || _isGameOver()) {
      _gameOver = true;
    }
  }

  Future<void> _saveCampaignResult() async {
    final CampaignLevel? level = campaignLevel;

    if (level == null) return;

    try {
      await campaignProgress.saveLevelResult(
        levelNumber: level.number,
        earnedStars: _campaignStars,
        score: score,
      );
    } catch (e) {
      debugPrint('Erro ao salvar resultado da campanha: $e');
    }
  }

  void _returnToCampaignMap() {
    Navigator.of(context).pop();
  }

  Widget _buildScoreBox(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: kCardColor,
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
              color: kGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignHeader() {
    final CampaignLevel level = campaignLevel!;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF075E4A),
            Color(0xFF173A35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FASE ${level.number} · ${level.worldName}',
            style: const TextStyle(
              color: Color(0xFFA8FFE4),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            level.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            level.objective,
            style: const TextStyle(
              color: Color(0xFFD5FFF2),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.swipe,
                color: Color(0xFFA8FFE4),
                size: 16,
              ),
              const SizedBox(width: 5),
              Text(
                'Jogadas: ${level.maxMoves == null ? _campaignMoves : '$_campaignMoves/${level.maxMoves}'}',
                style: const TextStyle(
                  color: Color(0xFFD5FFF2),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (level.allowMultiplication)
                const Text(
                  '+  x',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (level.allowCollapse) ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.functions,
                  color: Color(0xFFA8FFE4),
                  size: 17,
                ),
              ],
              if (level.allowMultiplesOfThree) ...[
                const SizedBox(width: 12),
                const Text(
                  '3',
                  style: TextStyle(
                    color: Color(0xFFA8FFE4),
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final BoardMode mode in BoardMode.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(mode.dims),
                  selected: mode == _mode,
                  showCheckmark: false,
                  onSelected: (_) => _requestModeChange(mode),
                  backgroundColor: kCardColor,
                  selectedColor: kGreen,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: mode == _mode ? Colors.white : Colors.grey,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Modo ${_mode.label}',
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildArrowButton(
    IconData icon,
    double dx,
    double dy,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: 64,
        height: 64,
        child: IconButton(
          onPressed: () => _handleSwipe(dx, dy),
          icon: Icon(icon, size: 32),
          style: IconButton.styleFrom(
            backgroundColor: kCardColor,
            foregroundColor: kGreen,
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
        color: kEmptyCellColor,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildTileBody(CellData cell) {
    final double fontSize = n >= 5 ? 20 : 24;

    final Color tileColor = cell.operation == '+'
        ? const Color(0xFF3C3C43)
        : const Color(0xFF303F50);

    final Color borderColor = cell.operation == '+'
        ? kGreen
        : const Color(0xFF42A5F5);

    return Container(
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 4,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 2,
              ),
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
              padding: const EdgeInsets.only(
                top: 10,
                left: 4,
                right: 4,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${cell.value}',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPop(
    CellData cell,
    Widget child, {
    required double begin,
    required Duration duration,
    required Curve curve,
  }) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(cell.id),
      tween: Tween<double>(
        begin: begin,
        end: 1,
      ),
      duration: duration,
      curve: curve,
      child: child,
      builder: (context, scale, animatedChild) {
        return Transform.scale(
          scale: scale,
          child: animatedChild,
        );
      },
    );
  }

  Widget _buildCell(CellData? cell) {
    if (cell == null) {
      return _buildEmptyCell();
    }

    final Widget tile = _buildTileBody(cell);

    switch (cell.event) {
      case TileEvent.spawned:
        return _buildPop(
          cell,
          tile,
          begin: 0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
        );

      case TileEvent.merged:
        return _buildPop(
          cell,
          tile,
          begin: 0.75,
          duration: const Duration(milliseconds: 350),
          curve: Curves.elasticOut,
        );

      case TileEvent.collapsed:
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
            title: Text(
              isCampaign ? 'Campanha' : 'Soma-Raiz',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: isCampaign
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _returnToCampaignMap,
                  )
                : null,
            actions: [
              IconButton(
                tooltip: 'Como jogar',
                icon: const Icon(
                  Icons.help_outline,
                  size: 28,
                ),
                color: kGreen,
                onPressed: () => showHowToPlay(context),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double reservedHeight = isCampaign ? 360 : 330;

                final double boardSize = max(
                  200,
                  min(
                    380,
                    min(
                      constraints.maxWidth * 0.9,
                      constraints.maxHeight - reservedHeight,
                    ),
                  ),
                );

                final double gap = n >= 5 ? 6 : 8;

                return Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (isCampaign) _buildCampaignHeader(),
                        if (!isCampaign) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildScoreBox('PONTOS', score),
                              const SizedBox(width: 12),
                              _buildScoreBox('RECORDE', bestScore),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildModeSelector(),
                        ],
                        if (isCampaign)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildScoreBox('PONTOS', score),
                          ),
                        const SizedBox(height: 8),
                        Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (event) {
                            _pointerStart = event.position;
                          },
                          onPointerUp: (event) {
                            final Offset? start = _pointerStart;
                            _pointerStart = null;

                            if (start == null) return;

                            final Offset distance =
                                event.position - start;

                            _handleSwipe(
                              distance.dx,
                              distance.dy,
                            );
                          },
                          onPointerCancel: (_) {
                            _pointerStart = null;
                          },
                          child: Container(
                            width: boardSize,
                            height: boardSize,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: kBoardColor,
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
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: n,
                                  crossAxisSpacing: gap,
                                  mainAxisSpacing: gap,
                                ),
                                itemCount: n * n,
                                itemBuilder: (context, index) {
                                  final int row = index ~/ n;
                                  final int column = index % n;

                                  return _buildCell(
                                    board[row][column],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildArrowButton(
                              Icons.arrow_back,
                              -100,
                              0,
                            ),
                            _buildArrowButton(
                              Icons.arrow_upward,
                              0,
                              -100,
                            ),
                            _buildArrowButton(
                              Icons.arrow_downward,
                              0,
                              100,
                            ),
                            _buildArrowButton(
                              Icons.arrow_forward,
                              100,
                              0,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _restartGame,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            isCampaign
                                ? 'Reiniciar Fase'
                                : 'Reiniciar Jogo',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
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
        if (!isCampaign && _gameOver)
          GameOverOverlay(
            score: score,
            bestScore: bestScore,
            isNewRecord: _isNewRecord,
            modeDims: _mode.dims,
            onRetry: _restartGame,
          ),
        if (isCampaign && (_gameOver || _campaignWon))
          CampaignResultOverlay(
            level: campaignLevel!,
            score: score,
            stars: _campaignStars,
            won: _campaignWon,
            onRetry: _restartGame,
            onBackToMap: _returnToCampaignMap,
          ),
      ],
    );
  }
}