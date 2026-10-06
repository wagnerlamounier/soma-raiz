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
const Color kHammerColor = Color(0xFFF59E0B);
const Color kScissorsColor = Color(0xFF42A5F5);
const Color kCoinColor = Color(0xFFFFC107);

// ---------------------------------------------------------------------------
// ECONOMIA E ITENS
// ---------------------------------------------------------------------------

// Chaves onde moedas e itens ficam salvos no aparelho.
const String kHammerStorageKey = 'item_hammer_count';
const String kCoinStorageKey = 'player_coins';
const String kScissorsStorageKey = 'item_scissors_count';

// Quantidade inicial de martelos (valor de teste).
const int kInitialHammers = 5;

// Quantidade inicial de tesouras (valor de teste).
const int kInitialScissors = 5;

// Preço de um martelo na loja.
const int kHammerPrice = 40;

// Recompensas por concluir fases.
const int kFirstClearCoins = 20;
const int kCoinsPerStar = 10;
const int kRepeatClearCoins = 5;
const int kHammerEveryLevels = 5;

class PlayerWallet {
  int coins = 0;
  int hammers = kInitialHammers;
  int scissors = kInitialScissors;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      coins = prefs.getInt(kCoinStorageKey) ?? 0;
      hammers = prefs.getInt(kHammerStorageKey) ?? kInitialHammers;
      scissors =
          prefs.getInt(kScissorsStorageKey) ?? kInitialScissors;
    } catch (e) {
      debugPrint('Erro ao carregar carteira: $e');
    }
  }

  Future<void> save() async {
    final int savedCoins = coins;
    final int savedHammers = hammers;
    final int savedScissors = scissors;

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setInt(kCoinStorageKey, savedCoins);
      await prefs.setInt(kHammerStorageKey, savedHammers);
      await prefs.setInt(
        kScissorsStorageKey,
        savedScissors,
      );
    } catch (e) {
      debugPrint('Erro ao salvar carteira: $e');
    }
  }

  bool buyHammer() {
    if (coins < kHammerPrice) return false;

    coins -= kHammerPrice;
    hammers += 1;

    return true;
  }
}

// Abre a loja. Retorna true se uma compra foi feita.
Future<bool> showHammerShop(
  BuildContext context,
  PlayerWallet wallet,
) async {
  final bool? bought = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final bool canBuy = wallet.coins >= kHammerPrice;
      bool busy = false;

      return AlertDialog(
        backgroundColor: kCardColor,
        title: const Text('Loja'),
        content: Text(
          canBuy
              ? 'Você tem ${wallet.coins} moedas.\n\n'
                  'Comprar 1 martelo por $kHammerPrice moedas?'
              : 'Você tem ${wallet.coins} moedas.\n\n'
                  'Um martelo custa $kHammerPrice moedas. '
                  'Conclua fases para ganhar mais moedas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(canBuy ? 'Cancelar' : 'Fechar'),
          ),
          if (canBuy)
            TextButton(
              onPressed: () async {
                if (busy) return;
                busy = true;

                wallet.buyHammer();
                await wallet.save();

                if (ctx.mounted) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text(
                'Comprar',
                style: TextStyle(color: kGreen),
              ),
            ),
        ],
      );
    },
  );

  return bought ?? false;
}

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

  // Quantas vezes o martelo pode ser usado em uma partida desta fase.
  final int maxHammerUses;

  // Quantas vezes a tesoura pode ser usada nesta fase.
  final int maxScissorsUses;

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
    this.maxHammerUses = 2,
    this.maxScissorsUses = 0,
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

  String get rulesSymbols {
    final List<String> symbols = ['+'];

    if (allowMultiplication) symbols.add('×');
    if (allowCollapse) symbols.add('√');
    if (allowMultiplesOfThree) symbols.add('3');

    return symbols.join('   ');
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
        maxHammerUses: 1,
        maxScissorsUses: 0,
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
            ? 32
            : i == 16
                ? 32
                : null,
        maxMoves: i >= 16 ? 34 - (i - 16) : null,
        allowMultiplication: true,
        allowCollapse: false,
        allowMultiplesOfThree: false,
        maxHammerUses: 2,
        maxScissorsUses: 0,
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
        targetScore: i == 26
            ? 1200
            : i == 27
                ? 1300
                : 600 + ((i - 20) * 130),
        targetValue: i == 24
            ? 11
            : i == 28
                ? 36
                : null,
        maxMoves: i >= 26 ? 33 - (i - 26) : null,
        allowMultiplication: true,
        allowCollapse: true,
        allowMultiplesOfThree: i >= 25,
        maxHammerUses: 3,
        maxScissorsUses: 1,
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
  bool showRoot;

  CellData({
    required this.value,
    required this.operation,
    this.event = TileEvent.none,
    this.showRoot = false,
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
  final PlayerWallet wallet = PlayerWallet();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    await progress.load();
    await wallet.load();

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  Future<void> _openShop() async {
    final bool bought = await showHammerShop(context, wallet);

    if (bought && mounted) {
      setState(() {});
    }
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
              margin: const EdgeInsets.only(bottom: 12),
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
                          'Fases concluídas: '
                          '${min(progress.unlockedLevel - 1, 30)}/30\n'
                          'Estrelas: ${progress.totalStars}/90\n'
                          'Moedas: ${wallet.coins}  ·  '
                          'Martelos: ${wallet.hammers}  ·  '
                          'Tesouras: ${wallet.scissors}',
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
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _openShop,
                  icon: const Icon(Icons.storefront),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Loja · Martelo por $kHammerPrice moedas',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kCoinColor,
                    side: const BorderSide(color: kCoinColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
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
                        'O círculo no canto superior direito de cada peça '
                        'mostra a operação dela: azul com + para soma e '
                        'vermelho com × para multiplicação. O resultado '
                        'usa a operação da peça que está na frente no '
                        'sentido do movimento. Peças com o mesmo número '
                        'têm a mesma cor.',
                    example: '4 + 4 = 8       3 × 3 = 9',
                  ),
                  _RuleCard(
                    icon: Icons.functions,
                    accent: Color(0xFF1565C0),
                    title: 'Raiz Quadrada',
                    text:
                        'Quando uma fusão produz resultado acima de 99, o '
                        'valor pode sofrer um colapso e virar sua raiz '
                        'quadrada arredondada. Essas peças ganham borda '
                        'dourada e um círculo roxo com √ no canto '
                        'superior esquerdo.',
                    example: '64 + 64 = 128 → √128 ≈ 11',
                  ),
                  _RuleCard(
                    icon: Icons.gavel,
                    accent: kHammerColor,
                    title: 'Martelo',
                    text:
                        'Na campanha, toque no botão Martelo e depois em '
                        'uma peça para destruí-la. Usar o martelo não conta '
                        'como jogada e consome um item. Cada fase tem um '
                        'limite de usos do martelo, mostrado abaixo do '
                        'tabuleiro. Ao reiniciar a fase, os usos permitidos '
                        'voltam, mas os martelos gastos não. Toque em '
                        'Cancelar para desistir sem gastar.',
                  ),
                  _RuleCard(
                    icon: Icons.content_cut_rounded,
                    accent: Color(0xFF42A5F5),
                    title: 'Tesoura',
                    text:
                        'Na campanha, a tesoura remove toda a linha e '
                        'toda a coluna da célula escolhida. Ela não gera '
                        'pontos, não conta como jogada e não cria peças '
                        'novas. Cada fase pode ter um limite de usos. '
                        'Toque em Cancelar para desistir sem gastar.',
                  ),
                  _RuleCard(
                    icon: Icons.monetization_on_outlined,
                    accent: kCoinColor,
                    title: 'Moedas e Loja',
                    text:
                        'Ao concluir fases da campanha você ganha moedas, '
                        'e mais ainda se conquistar estrelas. Algumas fases '
                        'também dão um martelo de bônus. Use as moedas na '
                        'loja do mapa da campanha para comprar martelos.',
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
  final int rewardCoins;
  final int rewardHammers;
  final VoidCallback onRetry;
  final VoidCallback onBackToMap;

  const CampaignResultOverlay({
    super.key,
    required this.level,
    required this.score,
    required this.stars,
    required this.won,
    required this.rewardCoins,
    required this.rewardHammers,
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

  Widget _buildRewards() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 18,
        runSpacing: 8,
        children: [
          if (rewardCoins > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: kCoinColor,
                  size: 24,
                ),
                const SizedBox(width: 6),
                Text(
                  '+$rewardCoins moedas',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          if (rewardHammers > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.gavel,
                  color: kHammerColor,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Text(
                  '+$rewardHammers martelo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
        ],
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
            if (won && (rewardCoins > 0 || rewardHammers > 0)) ...[
              const SizedBox(height: 16),
              _buildRewards(),
            ],
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

  int _campaignMoves = 0;
  int _campaignStars = 0;

  // Carteira (moedas e itens) e recompensa da última vitória.
  final PlayerWallet wallet = PlayerWallet();
  int _rewardCoins = 0;
  int _rewardHammers = 0;

  int get _hammers => wallet.hammers;
  bool _hammerActive = false;
  bool _scissorsActive = false;

  // Quantas vezes cada item já foi usado nesta partida da fase.
  int _hammerUsesThisRun = 0;
  int _scissorsUsesThisRun = 0;

  int get _hammerUsesLeft {
    final CampaignLevel? level = campaignLevel;

    if (level == null) return 0;

    return max(0, level.maxHammerUses - _hammerUsesThisRun);
  }

  int get _scissors {
    return wallet.scissors;
  }

  int get _scissorsUsesLeft {
    final CampaignLevel? level = campaignLevel;

    if (level == null) return 0;

    return max(
      0,
      level.maxScissorsUses - _scissorsUsesThisRun,
    );
  }

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
      _loadWallet();
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

  Future<void> _loadWallet() async {
    await wallet.load();

    if (!mounted) return;

    setState(() {});
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
    _campaignMoves = 0;
    _campaignStars = 0;
    _rewardCoins = 0;
    _rewardHammers = 0;
    _hammerActive = false;
    _hammerUsesThisRun = 0;
    _scissorsActive = false;
    _scissorsUsesThisRun = 0;

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

  // Segurança: se um item deixar o tabuleiro totalmente vazio,
  // nasce uma peça para o jogo não travar.
  void _ensureBoardNotEmpty() {
    for (final row in board) {
      for (final cell in row) {
        if (cell != null) return;
      }
    }

    _addRandomTile();
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
      showRoot: collapsed,
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
    if (_gameOver ||
        _campaignWon ||
        _hammerActive ||
        _scissorsActive) {
      return;
    }

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

  // -------------------------------------------------------------------------
  // MARTELO, TESOURA E LOJA
  // -------------------------------------------------------------------------

  Future<void> _openHammerShop() async {
    final bool bought = await showHammerShop(context, wallet);

    if (bought && mounted) {
      setState(() {});
    }
  }

  void _toggleHammer() {
    if (!isCampaign || _gameOver || _campaignWon) return;

    // Limite de usos da fase atingido: o martelo não pode ser ativado.
    if (!_hammerActive && _hammerUsesLeft <= 0) return;

    // Sem martelos: oferece a compra na loja.
    if (!_hammerActive && _hammers <= 0) {
      _openHammerShop();
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _hammerActive = !_hammerActive;

      if (_hammerActive) {
        _scissorsActive = false;
      }
    });
  }

  Future<void> _useHammerAt(
    Offset local,
    double boardSize,
    double gap,
  ) async {
    if (!_hammerActive || _hammers <= 0) return;
    if (_hammerUsesLeft <= 0) return;
    if (_gameOver || _campaignWon) return;

    // O tabuleiro tem 10 de espaço interno (3 de borda + 7 de padding).
    const double pad = 10;

    final double inner = boardSize - (pad * 2);
    final double pitch = (inner + gap) / n;

    final double x = local.dx - pad;
    final double y = local.dy - pad;

    if (x < 0 || y < 0 || x > inner || y > inner) return;

    final int column = (x / pitch).floor();
    final int row = (y / pitch).floor();

    if (row < 0 || row >= n || column < 0 || column >= n) return;

    if (board[row][column] == null) return;

    HapticFeedback.heavyImpact();

    setState(() {
      board[row][column] = null;
      wallet.hammers--;
      _hammerUsesThisRun++;
      _hammerActive = false;

      _ensureBoardNotEmpty();
    });

    await wallet.save();
  }

  void _toggleScissors() {
    if (!isCampaign || _gameOver || _campaignWon) return;

    if (!_scissorsActive && _scissorsUsesLeft <= 0) return;

    if (!_scissorsActive && _scissors <= 0) return;

    HapticFeedback.selectionClick();

    setState(() {
      _scissorsActive = !_scissorsActive;

      if (_scissorsActive) {
        _hammerActive = false;
      }
    });
  }

  Future<void> _useScissorsAt(
    Offset local,
    double boardSize,
    double gap,
  ) async {
    if (!_scissorsActive || _scissors <= 0) return;
    if (_scissorsUsesLeft <= 0) return;
    if (_gameOver || _campaignWon) return;

    const double pad = 10;

    final double inner = boardSize - (pad * 2);
    final double pitch = (inner + gap) / n;

    final double x = local.dx - pad;
    final double y = local.dy - pad;

    if (x < 0 || y < 0 || x > inner || y > inner) return;

    final int column = (x / pitch).floor();
    final int row = (y / pitch).floor();

    if (row < 0 || row >= n || column < 0 || column >= n) {
      return;
    }

    HapticFeedback.heavyImpact();

    setState(() {
      for (int c = 0; c < n; c++) {
        board[row][c] = null;
      }

      for (int r = 0; r < n; r++) {
        board[r][column] = null;
      }

      wallet.scissors--;
      _scissorsUsesThisRun++;
      _scissorsActive = false;

      _ensureBoardNotEmpty();
    });

    await wallet.save();
  }

  // -------------------------------------------------------------------------
  // STATUS DA CAMPANHA
  // -------------------------------------------------------------------------

  void _checkCampaignStatus() {
    final CampaignLevel? level = campaignLevel;

    if (level == null || _campaignWon || _gameOver) {
      return;
    }

    final bool reachedScore = score >= level.targetScore;
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

    final bool outOfMoves =
        level.maxMoves != null && _campaignMoves >= level.maxMoves!;

    if (objectiveCompleted) {
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
    } else if (outOfMoves || _isGameOver()) {
      _gameOver = true;
    }
  }

  Future<void> _saveCampaignResult() async {
    final CampaignLevel? level = campaignLevel;

    if (level == null) return;

    try {
      // Recarrega o progresso para saber se é a primeira vez na fase.
      await campaignProgress.load();

      final int oldStars = campaignProgress.starsFor(level.number);
      final bool firstClear = oldStars == 0;

      int coins;
      int hammers = 0;

      if (firstClear) {
        coins = kFirstClearCoins + (kCoinsPerStar * _campaignStars);

        if (level.number % kHammerEveryLevels == 0) {
          hammers = 1;
        }
      } else {
        final int newStars = max(0, _campaignStars - oldStars);

        coins = newStars > 0
            ? newStars * kCoinsPerStar
            : kRepeatClearCoins;
      }

      await campaignProgress.saveLevelResult(
        levelNumber: level.number,
        earnedStars: _campaignStars,
        score: score,
      );

      wallet.coins += coins;
      wallet.hammers += hammers;

      await wallet.save();

      if (!mounted || !_campaignWon) return;

      setState(() {
        _rewardCoins = coins;
        _rewardHammers = hammers;
      });
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

  Widget _buildCoinBox() {
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
          const Text(
            'MOEDAS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${wallet.coins}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: kCoinColor,
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
              Text(
                level.rulesSymbols,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
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

  Widget _buildRestartButton() {
    return ElevatedButton.icon(
      onPressed: _restartGame,
      icon: const Icon(Icons.refresh),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          isCampaign ? 'Reiniciar Fase' : 'Reiniciar Jogo',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildHammerButton() {
    // O botão fica ativo se o martelo já está ligado (para cancelar)
    // ou se ainda restam usos na fase.
    final bool canUse = !_gameOver &&
        !_campaignWon &&
        (_hammerActive || _hammerUsesLeft > 0);

    return ElevatedButton.icon(
      onPressed: canUse ? _toggleHammer : null,
      icon: Icon(_hammerActive ? Icons.close : Icons.gavel),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          _hammerActive ? 'Cancelar' : 'Martelo ($_hammers)',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _hammerActive ? kHammerColor : kCardColor,
        foregroundColor: _hammerActive ? Colors.black : kHammerColor,
        disabledBackgroundColor: kCardColor,
        disabledForegroundColor: const Color(0xFF66666D),
        side: BorderSide(
          color: canUse ? kHammerColor : const Color(0xFF66666D),
          width: 1.5,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildScissorsButton() {
    final bool available = campaignLevel != null &&
        campaignLevel!.maxScissorsUses > 0;

    final bool canUse = available &&
        !_gameOver &&
        !_campaignWon &&
        (_scissorsActive || _scissorsUsesLeft > 0) &&
        (_scissors > 0 || _scissorsActive);

    return ElevatedButton.icon(
      onPressed: canUse ? _toggleScissors : null,
      icon: Icon(
        _scissorsActive
            ? Icons.close
            : Icons.content_cut_rounded,
      ),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          _scissorsActive
              ? 'Cancelar'
              : 'Tesoura ($_scissors)',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            _scissorsActive ? kScissorsColor : kCardColor,
        foregroundColor:
            _scissorsActive ? Colors.white : kScissorsColor,
        disabledBackgroundColor: kCardColor,
        disabledForegroundColor: const Color(0xFF66666D),
        side: BorderSide(
          color: canUse ? kScissorsColor : const Color(0xFF66666D),
          width: 1.5,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // Texto abaixo do tabuleiro (apenas na campanha).
  Widget _buildCampaignItemStatus() {
    final CampaignLevel level = campaignLevel!;

    if (_hammerActive) {
      return const Center(
        child: Text(
          'Toque em uma peça para destruí-la',
          style: TextStyle(
            color: kHammerColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }

    if (_scissorsActive) {
      return const Center(
        child: Text(
          'Toque em uma célula para cortar a linha e a coluna',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: kScissorsColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );
    }

    if (level.maxScissorsUses > 0) {
      return Center(
        child: Text(
          'Martelo: $_hammerUsesLeft de ${level.maxHammerUses}  ·  '
          'Tesoura: $_scissorsUsesLeft de ${level.maxScissorsUses}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF9A9AA2),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      );
    }

    final bool limitReached = _hammerUsesLeft <= 0;

    return Center(
      child: Text(
        limitReached
            ? 'Limite de martelos desta fase atingido'
            : 'Martelo: $_hammerUsesLeft de ${level.maxHammerUses} '
                'usos nesta fase',
        style: TextStyle(
          color: limitReached
              ? const Color(0xFFC62828)
              : const Color(0xFF9A9AA2),
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    if (!isCampaign) {
      return _buildRestartButton();
    }

    final bool scissorsAvailable =
        campaignLevel!.maxScissorsUses > 0;

    if (!scissorsAvailable) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(child: _buildRestartButton()),
            const SizedBox(width: 12),
            Expanded(child: _buildHammerButton()),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(child: _buildRestartButton()),
          const SizedBox(width: 7),
          Expanded(child: _buildHammerButton()),
          const SizedBox(width: 7),
          Expanded(child: _buildScissorsButton()),
        ],
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

  // Cores dos círculos de operação (únicas, nunca usadas nas peças).
  static const Color _opPlusColor = Color(0xFF1E5BFF); // azul
  static const Color _opTimesColor = Color(0xFFE0103A); // vermelho
  static const Color _opRootColor = Color(0xFF8E24AA); // roxo

  // As peças usam só verdes, azul-petróleo, laranjas, dourados,
  // marrons e cinzas, evitando azul, vermelho e roxo (cores dos círculos).
  Color _colorForValue(int value) {
    const Map<int, Color> valueColors = {
      2: Color(0xFF2E9E57),
      3: Color(0xFFE67E22),
      4: Color(0xFF12A58B),
      5: Color(0xFFB7791F),
      6: Color(0xFF8D6E4F),
      8: Color(0xFF8A9A1A),
      9: Color(0xFF1F6B4A),
      11: Color(0xFF5F7A85),
      12: Color(0xFFC9A400),
      16: Color(0xFF00838F),
      18: Color(0xFF689F38),
      24: Color(0xFF6D4C41),
      25: Color(0xFF455A64),
      32: Color(0xFF00695C),
      36: Color(0xFF33691E),
      48: Color(0xFFBF6F00),
      64: Color(0xFFD9822B),
      81: Color(0xFF1B5E20),
      128: Color(0xFF827717),
      256: Color(0xFF5D4037),
      512: Color(0xFF546E7A),
    };

    final Color? known = valueColors[value];

    if (known != null) return known;

    // Valores fora da tabela: matiz entre 20 e 169 (sem azul/vermelho/roxo).
    final double hue = 20.0 + ((value * 37) % 150);

    return HSLColor.fromAHSL(1, hue, 0.60, 0.36).toColor();
  }

  Color _shade(Color color, double delta) {
    final HSLColor hsl = HSLColor.fromColor(color);

    return hsl
        .withLightness((hsl.lightness + delta).clamp(0.0, 1.0).toDouble())
        .toColor();
  }

  Widget _buildTileBody(CellData cell) {
    final Color base = _colorForValue(cell.value);
    final Color light = _shade(base, 0.10);
    final Color dark = _shade(base, -0.10);
    final Color bottomEdge = _shade(base, -0.22);

    final bool isTimes = cell.operation == 'x';
    final Color opColor = isTimes ? _opTimesColor : _opPlusColor;
    final String opSymbol = isTimes ? '×' : '+';

    return LayoutBuilder(
      builder: (context, constraints) {
        final double size = min(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        final double radius = size * 0.2;
        final double badge = size * 0.36;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [light, base, dark],
            ),
            // Peça colapsada por raiz ganha borda dourada.
            border: cell.showRoot
                ? Border.all(
                    color: const Color(0xFFFFC107),
                    width: max(2.5, size * 0.05),
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: bottomEdge,
                offset: Offset(0, size * 0.05),
              ),
              BoxShadow(
                color: const Color.fromRGBO(0, 0, 0, 0.35),
                offset: Offset(0, size * 0.08),
                blurRadius: size * 0.10,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Brilho no topo.
              Positioned(
                left: size * 0.07,
                right: size * 0.07,
                top: size * 0.04,
                height: size * 0.34,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius * 0.8),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withAlpha(90),
                        Colors.white.withAlpha(0),
                      ],
                    ),
                  ),
                ),
              ),
              // Número central em branco.
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(size * 0.12),
                  child: Align(
                    alignment: const Alignment(0, 0.12),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${cell.value}',
                        style: TextStyle(
                          fontSize: size * 0.46,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1,
                          shadows: const [
                            Shadow(
                              color: Color.fromRGBO(0, 0, 0, 0.45),
                              blurRadius: 3,
                              offset: Offset(0, 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Círculo da operação, canto superior direito.
              Positioned(
                top: size * 0.05,
                right: size * 0.05,
                child: Container(
                  width: badge,
                  height: badge,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: opColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: max(1.5, size * 0.025),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.4),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    opSymbol,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: badge * 0.75,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
              // Círculo da raiz, canto superior esquerdo (só se colapsada).
              if (cell.showRoot)
                Positioned(
                  top: size * 0.05,
                  left: size * 0.05,
                  child: Container(
                    width: badge * 0.9,
                    height: badge * 0.9,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _opRootColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: max(1.5, size * 0.025),
                      ),
                    ),
                    child: Text(
                      '√',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: badge * 0.62,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
                final double reservedHeight = isCampaign ? 400 : 330;

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

                // O conteúdo não rola: se não couber na altura da tela,
                // o FittedBox reduz tudo proporcionalmente até caber.
                return Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildScoreBox('PONTOS', score),
                                  const SizedBox(width: 12),
                                  _buildCoinBox(),
                                ],
                              ),
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

                              // Com o martelo ativo, um toque escolhe a peça.
                              if (_hammerActive) {
                                if (distance.distance < 15) {
                                  _useHammerAt(
                                    event.localPosition,
                                    boardSize,
                                    gap,
                                  );
                                }
                                return;
                              }

                              // Com a tesoura ativa, um toque escolhe
                              // a linha e a coluna.
                              if (_scissorsActive) {
                                if (distance.distance < 15) {
                                  _useScissorsAt(
                                    event.localPosition,
                                    boardSize,
                                    gap,
                                  );
                                }
                                return;
                              }

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
                              // 3 de borda + 7 de padding = 10 de espaço
                              // interno.
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: kBoardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _hammerActive
                                      ? kHammerColor
                                      : _scissorsActive
                                          ? kScissorsColor
                                          : Colors.transparent,
                                  width: 3,
                                ),
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
                          SizedBox(
                            height: isCampaign ? 30 : 16,
                            child: isCampaign
                                ? _buildCampaignItemStatus()
                                : null,
                          ),
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
                          _buildBottomButtons(),
                          const SizedBox(height: 12),
                        ],
                      ),
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
            rewardCoins: _rewardCoins,
            rewardHammers: _rewardHammers,
            onRetry: _restartGame,
            onBackToMap: _returnToCampaignMap,
          ),
      ],
    );
  }
}