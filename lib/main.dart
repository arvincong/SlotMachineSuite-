import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

void main() {
  runApp(const SlotMachineSuiteApp());
}

class SlotMachineSuiteApp extends StatelessWidget {
  const SlotMachineSuiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Slot Machine Suite',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff13bdf2)),
        useMaterial3: true,
      ),
      home: const SlotMachineScreen(),
    );
  }
}

enum SlotSymbol {
  nova,
  crown,
  gem,
  bell,
  seven,
  coin,
  wild,
  bonus;

  String get title {
    switch (this) {
      case SlotSymbol.nova:
        return 'NOVA';
      case SlotSymbol.crown:
        return 'CROWN';
      case SlotSymbol.gem:
        return 'GEM';
      case SlotSymbol.bell:
        return 'BELL';
      case SlotSymbol.seven:
        return 'SEVEN';
      case SlotSymbol.coin:
        return 'COIN';
      case SlotSymbol.wild:
        return 'WILD';
      case SlotSymbol.bonus:
        return 'BONUS';
    }
  }

  IconData get icon {
    switch (this) {
      case SlotSymbol.nova:
        return Icons.auto_awesome;
      case SlotSymbol.crown:
        return Icons.workspace_premium;
      case SlotSymbol.gem:
        return Icons.diamond;
      case SlotSymbol.bell:
        return Icons.notifications_active;
      case SlotSymbol.seven:
        return Icons.filter_7;
      case SlotSymbol.coin:
        return Icons.monetization_on;
      case SlotSymbol.wild:
        return Icons.auto_fix_high;
      case SlotSymbol.bonus:
        return Icons.redeem;
    }
  }

  List<Color> get palette {
    switch (this) {
      case SlotSymbol.nova:
        return [const Color(0xff24c7f2), const Color(0xff0840c4)];
      case SlotSymbol.crown:
        return [const Color(0xffffde3d), const Color(0xffed591f)];
      case SlotSymbol.gem:
        return [const Color(0xfff230b8), const Color(0xff5214b8)];
      case SlotSymbol.bell:
        return [const Color(0xfffcb32e), const Color(0xfffa3333)];
      case SlotSymbol.seven:
        return [const Color(0xfffa243d), const Color(0xff6b051f)];
      case SlotSymbol.coin:
        return [const Color(0xfff5ed63), const Color(0xff14a647)];
      case SlotSymbol.wild:
        return [const Color(0xfffff25c), const Color(0xff21bd70)];
      case SlotSymbol.bonus:
        return [const Color(0xff5ceeff), const Color(0xff0a63ef)];
    }
  }

  int get weight {
    switch (this) {
      case SlotSymbol.nova:
        return 18;
      case SlotSymbol.crown:
        return 16;
      case SlotSymbol.gem:
      case SlotSymbol.bell:
        return 14;
      case SlotSymbol.coin:
        return 12;
      case SlotSymbol.seven:
        return 10;
      case SlotSymbol.wild:
      case SlotSymbol.bonus:
        return 8;
    }
  }

  int get payoutMultiplier {
    switch (this) {
      case SlotSymbol.nova:
        return 2;
      case SlotSymbol.crown:
        return 3;
      case SlotSymbol.gem:
        return 4;
      case SlotSymbol.bell:
        return 5;
      case SlotSymbol.coin:
        return 6;
      case SlotSymbol.seven:
        return 8;
      case SlotSymbol.wild:
        return 10;
      case SlotSymbol.bonus:
        return 12;
    }
  }
}

class Payline {
  const Payline(this.name, this.rows);

  final String name;
  final List<int> rows;
}

class SpinResult {
  const SpinResult({
    required this.lineWin,
    required this.bonusWin,
    required this.jackpotWin,
  });

  final int lineWin;
  final int bonusWin;
  final int jackpotWin;

  int get total => lineWin + bonusWin + jackpotWin;
}

class SlotGameController extends ChangeNotifier {
  SlotGameController() {
    reels = _randomReels();
  }

  final _random = Random();
  final betOptions = const [100, 250, 500, 1000, 2500, 5000];
  final paylines = const [
    Payline('Top', [0, 0, 0, 0, 0]),
    Payline('Middle', [1, 1, 1, 1, 1]),
    Payline('Bottom', [2, 2, 2, 2, 2]),
    Payline('Rise', [2, 1, 0, 1, 2]),
    Payline('Dip', [0, 1, 2, 1, 0]),
  ];

  late List<List<SlotSymbol>> reels;
  int balance = 50000;
  int bet = 500;
  int lastWin = 0;
  int jackpot = 1250000;
  int spinCount = 0;
  String message = 'Ready';
  bool isSpinning = false;

  void increaseBet() {
    final index = betOptions.indexOf(bet);
    if (index >= 0 && index < betOptions.length - 1) {
      bet = betOptions[index + 1];
      notifyListeners();
    }
  }

  void decreaseBet() {
    final index = betOptions.indexOf(bet);
    if (index > 0) {
      bet = betOptions[index - 1];
      notifyListeners();
    }
  }

  void maxBet() {
    bet = betOptions.last;
    notifyListeners();
  }

  void resetSession() {
    balance = 50000;
    bet = 500;
    lastWin = 0;
    jackpot = 1250000;
    spinCount = 0;
    message = 'Ready';
    isSpinning = false;
    reels = _randomReels();
    notifyListeners();
  }

  Future<void> spin() async {
    if (isSpinning) {
      return;
    }

    if (balance < bet) {
      message = 'Add demo credits';
      notifyListeners();
      return;
    }

    balance -= bet;
    jackpot += max(25, bet ~/ 20);
    lastWin = 0;
    message = 'Spinning';
    isSpinning = true;
    notifyListeners();

    for (var step = 0; step < 18; step++) {
      reels = _randomReels();
      notifyListeners();
      await Future<void>.delayed(Duration(milliseconds: 45 + step * 5));
    }

    reels = _randomReels();
    final result = evaluate(reels);
    lastWin = result.total;
    balance += result.total;
    spinCount += 1;

    if (result.jackpotWin > 0) {
      message = 'Grand jackpot';
      jackpot = 1250000;
    } else if (result.total > bet * 20) {
      message = 'Mega win';
    } else if (result.total > 0) {
      message = 'Nice win';
    } else {
      message = 'Try again';
    }

    isSpinning = false;
    notifyListeners();
  }

  SpinResult evaluate(List<List<SlotSymbol>> settledReels) {
    var lineWin = 0;

    for (final payline in paylines) {
      final symbols = [
        for (var column = 0; column < payline.rows.length; column++)
          settledReels[column][payline.rows[column]],
      ];
      final anchor = symbols.firstWhere(
        (symbol) => symbol != SlotSymbol.wild,
        orElse: () => SlotSymbol.wild,
      );
      var matchCount = 0;

      for (final symbol in symbols) {
        if (symbol == anchor ||
            symbol == SlotSymbol.wild ||
            anchor == SlotSymbol.wild) {
          matchCount += 1;
        } else {
          break;
        }
      }

      if (matchCount >= 3) {
        lineWin += bet * anchor.payoutMultiplier * matchCount ~/ 5;
      }
    }

    final bonusCount = settledReels
        .expand((column) => column)
        .where((symbol) => symbol == SlotSymbol.bonus)
        .length;
    final bonusWin = bonusCount >= 4 ? bet * bonusCount * 4 : 0;
    final jackpotHit = bonusCount >= 7 || _random.nextInt(2500) == 0;
    final jackpotWin = jackpotHit ? jackpot : 0;
    return SpinResult(
      lineWin: lineWin,
      bonusWin: bonusWin,
      jackpotWin: jackpotWin,
    );
  }

  List<List<SlotSymbol>> _randomReels() {
    return List.generate(5, (_) => List.generate(3, (_) => _weightedSymbol()));
  }

  SlotSymbol _weightedSymbol() {
    final totalWeight = SlotSymbol.values.fold<int>(
      0,
      (sum, symbol) => sum + symbol.weight,
    );
    var ticket = _random.nextInt(totalWeight) + 1;

    for (final symbol in SlotSymbol.values) {
      ticket -= symbol.weight;
      if (ticket <= 0) {
        return symbol;
      }
    }

    return SlotSymbol.nova;
  }
}

class SlotMachineScreen extends StatefulWidget {
  const SlotMachineScreen({super.key});

  @override
  State<SlotMachineScreen> createState() => _SlotMachineScreenState();
}

class _SlotMachineScreenState extends State<SlotMachineScreen> {
  late final SlotGameController game;

  @override
  void initState() {
    super.initState();
    game = SlotGameController()..addListener(_refresh);
  }

  @override
  void dispose() {
    game.removeListener(_refresh);
    game.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff14142e), Color(0xff330a2e), Color(0xff052e29)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const CoinCurtain(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > constraints.maxHeight;
                  final content = isWide ? _wideLayout() : _portraitLayout();
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      isWide ? 24 : 14,
                      10,
                      isWide ? 24 : 14,
                      12,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 22,
                      ),
                      child: content,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _portraitLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GameHeader(game: game, onPaytable: _showPaytable),
        const SizedBox(height: 10),
        JackpotStrip(game: game),
        const SizedBox(height: 14),
        SlotMachineGrid(reels: game.reels, isSpinning: game.isSpinning),
        const SizedBox(height: 12),
        StatusPanel(game: game),
        const SizedBox(height: 10),
        ControlPanel(game: game),
      ],
    );
  }

  Widget _wideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameHeader(game: game, onPaytable: _showPaytable),
              const SizedBox(height: 12),
              JackpotStrip(game: game),
              const SizedBox(height: 12),
              StatusPanel(game: game),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          flex: 5,
          child: SlotMachineGrid(
            reels: game.reels,
            isSpinning: game.isSpinning,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(flex: 3, child: ControlPanel(game: game)),
      ],
    );
  }

  void _showPaytable() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff111126),
      isScrollControlled: true,
      builder: (context) {
        return PaytableSheet(game: game);
      },
    );
  }
}

class CoinCurtain extends StatelessWidget {
  const CoinCurtain({super.key});

  static const coins = [
    (0.08, 0.24, 0.80),
    (0.22, 0.10, 1.10),
    (0.42, 0.32, 0.70),
    (0.64, 0.14, 1.00),
    (0.82, 0.28, 0.86),
    (0.94, 0.08, 1.20),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: 140,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                for (var index = 0; index < coins.length; index++)
                  Positioned(
                    left: constraints.maxWidth * coins[index].$1,
                    top: 140 * coins[index].$2,
                    child: Transform.rotate(
                      angle: index * 0.42,
                      child: Coin(size: 40 * coins[index].$3),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class Coin extends StatelessWidget {
  const Coin({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xfffff24d), Color(0xffeb731a)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white70, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.yellow.withOpacity(0.45), blurRadius: 12),
        ],
      ),
      child: Icon(
        Icons.attach_money,
        color: const Color(0xff8c330a),
        size: size * 0.48,
      ),
    );
  }
}

class GameHeader extends StatelessWidget {
  const GameHeader({required this.game, required this.onPaytable, super.key});

  final SlotGameController game;
  final VoidCallback onPaytable;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MetricTile(
                title: 'BALANCE',
                value: formatCredits(game.balance),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: onPaytable,
              tooltip: 'Paytable',
              icon: const Icon(Icons.list_alt, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xff1cb8f5),
                fixedSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'STARLIGHT',
          maxLines: 1,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Text(
          'JACKPOT',
          maxLines: 1,
          style: TextStyle(
            color: Color(0xffffe633),
            fontSize: 42,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class JackpotStrip extends StatelessWidget {
  const JackpotStrip({required this.game, super.key});

  final SlotGameController game;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: JackpotBadge(
            title: 'MINI',
            value: shortCredits(game.bet * 20),
            tint: const Color(0xff33d660),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: JackpotBadge(
            title: 'MAJOR',
            value: shortCredits(game.bet * 120),
            tint: const Color(0xff21a3f2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: JackpotBadge(
            title: 'GRAND',
            value: shortCredits(game.jackpot),
            tint: const Color(0xfffa3d4d),
          ),
        ),
      ],
    );
  }
}

class JackpotBadge extends StatelessWidget {
  const JackpotBadge({
    required this.title,
    required this.value,
    required this.tint,
    super.key,
  });

  final String title;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [tint, Colors.black.withOpacity(0.58)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.42), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: tint.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SlotMachineGrid extends StatelessWidget {
  const SlotMachineGrid({
    required this.reels,
    required this.isSpinning,
    super.key,
  });

  final List<List<SlotSymbol>> reels;
  final bool isSpinning;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.32,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            colors: [Color(0xffeb2180), Color(0xff2e0d5c), Color(0xff05503b)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xffffcf2e), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            for (var row = 0; row < 3; row++) ...[
              if (row > 0) const SizedBox(height: 6),
              Expanded(
                child: Row(
                  children: [
                    for (var column = 0; column < 5; column++) ...[
                      if (column > 0) const SizedBox(width: 6),
                      Expanded(
                        child: SymbolTile(
                          symbol: reels[column][row],
                          isSpinning: isSpinning,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SymbolTile extends StatelessWidget {
  const SymbolTile({required this.symbol, required this.isSpinning, super.key});

  final SlotSymbol symbol;
  final bool isSpinning;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSpinning ? 0.92 : 1,
      duration: const Duration(milliseconds: 160),
      child: AnimatedOpacity(
        opacity: isSpinning ? 0.82 : 1,
        duration: const Duration(milliseconds: 160),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [Color(0xff141a2e), Color(0xff050814)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  colors: symbol.palette,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: symbol.palette.first.withOpacity(0.55),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(symbol.icon, color: Colors.white, size: 30),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      symbol.title,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StatusPanel extends StatelessWidget {
  const StatusPanel({required this.game, super.key});

  final SlotGameController game;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MetricTile(title: 'BET', value: formatCredits(game.bet)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricTile(
            title: 'WIN',
            value: formatCredits(game.lastWin),
            highlight: game.lastWin > 0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricTile(
            title: 'SPINS',
            value: formatCredits(game.spinCount),
          ),
        ),
      ],
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.title,
    required this.value,
    this.highlight = false,
    super.key,
  });

  final String title;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: highlight ? const Color(0xffffeb38) : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ControlPanel extends StatelessWidget {
  const ControlPanel({required this.game, super.key});

  final SlotGameController game;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [Color(0xff8c056b), Color(0xff1a0a2e)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 26,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                game.message.toUpperCase(),
                maxLines: 1,
                style: TextStyle(
                  color: game.lastWin > 0
                      ? const Color(0xffffeb3d)
                      : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SquareCommandButton(
                icon: Icons.remove,
                onPressed: game.isSpinning ? null : game.decreaseBet,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricTile(title: 'BET', value: formatCredits(game.bet)),
              ),
              const SizedBox(width: 10),
              SquareCommandButton(
                icon: Icons.add,
                onPressed: game.isSpinning ? null : game.increaseBet,
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 42,
                child: TextButton(
                  onPressed: game.isSpinning ? null : game.maxBet,
                  style: commandButtonStyle(const Color(0xfff75c29)),
                  child: const Text(
                    'MAX',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SquareCommandButton(
                icon: Icons.refresh,
                size: const Size(50, 52),
                tint: const Color(0xffad29c7),
                onPressed: game.isSpinning ? null : game.resetSession,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 58,
                  child: FilledButton.icon(
                    onPressed: game.isSpinning ? null : game.spin,
                    icon: Icon(
                      game.isSpinning
                          ? Icons.auto_awesome_motion
                          : Icons.play_arrow,
                      size: 24,
                    ),
                    label: Text(game.isSpinning ? 'SPINNING' : 'SPIN'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff13b82e),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Virtual coins only',
            style: TextStyle(
              color: Colors.white.withOpacity(0.58),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class SquareCommandButton extends StatelessWidget {
  const SquareCommandButton({
    required this.icon,
    required this.onPressed,
    this.size = const Size(42, 42),
    this.tint = const Color(0xff198af5),
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Size size;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: IconButton.filled(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        style: IconButton.styleFrom(
          backgroundColor: tint,
          disabledBackgroundColor: tint.withOpacity(0.35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

ButtonStyle commandButtonStyle(Color tint) {
  return TextButton.styleFrom(
    backgroundColor: tint,
    foregroundColor: Colors.white,
    disabledBackgroundColor: tint.withOpacity(0.35),
    minimumSize: const Size(54, 42),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
}

class PaytableSheet extends StatelessWidget {
  const PaytableSheet({required this.game, super.key});

  final SlotGameController game;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.42,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Paytable',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final symbol in SlotSymbol.values)
              PaytableRow(symbol: symbol, bet: game.bet),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PAYLINES',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final payline in game.paylines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Text(
                            payline.name,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            payline.rows.map((row) => row + 1).join('-'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class PaytableRow extends StatelessWidget {
  const PaytableRow({required this.symbol, required this.bet, super.key});

  final SlotSymbol symbol;
  final int bet;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                colors: symbol.palette,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(symbol.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symbol.title,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '3+ from left pays x${symbol.payoutMultiplier}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.68),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatCredits(bet * symbol.payoutMultiplier * 3 ~/ 5),
              style: const TextStyle(
                color: Color(0xffffe838),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String formatCredits(int value) {
  return value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
}

String shortCredits(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return formatCredits(value);
}
