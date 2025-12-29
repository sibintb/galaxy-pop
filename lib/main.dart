import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

// --- Entry Point ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for storage
  await Hive.initFlutter();
  await Hive.openBox('game_data');

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const BubbleShooterApp());
}

class BubbleShooterApp extends StatelessWidget {
  const BubbleShooterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galaxy Bubble Shooter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const MainMenuScreen(),
    );
  }
}

// --- Managers (Storage, Audio, Haptics) ---

class GameData {
  static final _box = Hive.box('game_data');

  static int get highScore => _box.get('highScore', defaultValue: 0);
  static set highScore(int v) => _box.put('highScore', v);

  static bool get soundEnabled => _box.get('soundEnabled', defaultValue: true);
  static set soundEnabled(bool v) => _box.put('soundEnabled', v);

  static bool get musicEnabled => _box.get('musicEnabled', defaultValue: true);
  static set musicEnabled(bool v) => _box.put('musicEnabled', v);

  static bool get vibrationEnabled =>
      _box.get('vibrationEnabled', defaultValue: true);
  static set vibrationEnabled(bool v) => _box.put('vibrationEnabled', v);
}

class AudioManager {
  static final AudioPlayer _musicPlayer = AudioPlayer();
  static final AudioPlayer _sfxPlayer = AudioPlayer();

  static void init() {
    _musicPlayer.setReleaseMode(ReleaseMode.loop);
    if (GameData.musicEnabled) {
      playMusic();
    }
  }

  static void playMusic() async {
    if (!GameData.musicEnabled) return;
    try {
      await _musicPlayer.play(AssetSource('audio/music.mp3'), volume: 0.3);
    } catch (e) {
      // Asset might be missing, ignore
    }
  }

  static void stopMusic() {
    _musicPlayer.stop();
  }

  static void playSfx(String fileName) async {
    if (!GameData.soundEnabled) return;
    try {
      // For overlapping SFX, we might need multiple players or low latency mode,
      // but keeping it simple here with one player for UI sounds.
      // For rapid game sounds, creating a new player is often safer in Flutter:
      final player = AudioPlayer();
      await player.play(AssetSource('audio/$fileName'), volume: 0.5);
      player.onPlayerComplete.listen((event) => player.dispose());
    } catch (e) {
      // Asset missing
    }
  }

  static void vibrate() {
    if (GameData.vibrationEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  static void vibrateHeavy() {
    if (GameData.vibrationEnabled) {
      HapticFeedback.heavyImpact();
    }
  }
}

// --- Screens ---

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgController;
  final List<BubbleParticle> _bgBubbles = [];
  final Random _rnd = Random();

  @override
  void initState() {
    super.initState();
    AudioManager.init();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _bgController.addListener(() {
      setState(() {
        if (_rnd.nextDouble() < 0.05 && _bgBubbles.length < 20) {
          _bgBubbles.add(
            BubbleParticle(
              position: Offset(_rnd.nextDouble() * 400, 900),
              velocity: Offset(
                (_rnd.nextDouble() - 0.5) * 1,
                -(_rnd.nextDouble() * 2 + 1),
              ),
              color: Colors.primaries[_rnd.nextInt(Colors.primaries.length)]
                  .withOpacity(0.3),
              life: 1.0,
              radius: _rnd.nextDouble() * 20 + 10,
            ),
          );
        }
        for (var b in _bgBubbles) {
          b.position += b.velocity;
          b.life -= 0.002;
        }
        _bgBubbles.removeWhere((b) => b.life <= 0 || b.position.dy < -50);
      });
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomPaint(
            painter: BackgroundBubblePainter(_bgBubbles),
            size: Size.infinite,
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                _buildTitle(),
                const SizedBox(height: 40),
                _buildHighScore(),
                const SizedBox(height: 60),
                _buildMenuButton(
                  "PLAY",
                  Icons.play_arrow_rounded,
                  Colors.greenAccent,
                  () {
                    AudioManager.playSfx('pop.mp3');
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GameScreen()),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _buildMenuButton(
                  "SETTINGS",
                  Icons.settings,
                  Colors.blueAccent,
                  () {
                    AudioManager.playSfx('pop.mp3');
                    _showSettingsDialog(context);
                  },
                ),
                const Spacer(),
                const Text(
                  "Designed and Developed by CBn",
                  style: TextStyle(
                    color: Colors.white30,
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        const Icon(Icons.bubble_chart, size: 80, color: Colors.cyanAccent),
        const SizedBox(height: 10),
        Text(
          "GALAXY POP",
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: Colors.cyanAccent.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHighScore() {
    return ValueListenableBuilder(
      valueListenable: Hive.box('game_data').listenable(),
      builder: (context, box, widget) {
        int score = box.get('highScore', defaultValue: 0);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              const Text(
                "HIGH SCORE",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                "$score",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => const SettingsDialog());
  }
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text("Settings", style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSwitch(
            "Sound",
            GameData.soundEnabled,
            (v) => setState(() => GameData.soundEnabled = v),
          ),
          _buildSwitch("Music", GameData.musicEnabled, (v) {
            setState(() => GameData.musicEnabled = v);
            if (v)
              AudioManager.playMusic();
            else
              AudioManager.stopMusic();
          }),
          _buildSwitch(
            "Vibration",
            GameData.vibrationEnabled,
            (v) => setState(() => GameData.vibrationEnabled = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    );
  }

  Widget _buildSwitch(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.blueAccent,
          ),
        ],
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // Config
  static const int cols = 8;
  int rows = 15;
  double bubbleRadius = 20.0;
  static const double shooterSpeed = 20.0;

  // Game State
  List<List<Color?>> grid = [];
  late Color currentBubbleColor;
  late Color nextBubbleColor;
  Offset? projectilePosition;
  Offset? projectileVelocity;
  double gunAngle = -pi / 2;
  int score = 0;
  bool isGameOver = false;
  bool isShooting = false;
  bool isPaused = false;
  bool isGridOffset = false;

  // Level System
  int level = 1;
  int nextLevelScore = 1000;
  double descentTimer = 0.0;
  double descentInterval = 15.0;
  Duration _lastElapsed = Duration.zero;

  // Animations
  late Ticker _ticker;
  late AnimationController _levelUpController;
  late Animation<double> _levelUpOpacity;

  late AnimationController _swapController;
  late Animation<double> _swapRotation;

  List<BubbleParticle> particles = [];
  Size? boardSize;

  final List<Color> bubblePalette = [
    const Color(0xFFFF4D4D),
    const Color(0xFF4DA6FF),
    const Color(0xFF53DD6C),
    const Color(0xFFFFD166),
    const Color(0xFFC38FFF),
    const Color(0xFFFF9F1C),
  ];

  @override
  void initState() {
    super.initState();

    _levelUpController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _levelUpOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_levelUpController);

    _swapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _swapRotation = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _swapController, curve: Curves.easeInOutBack),
    );

    _swapController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Actually swap data when animation finishes (or halfway)
        final temp = currentBubbleColor;
        currentBubbleColor = nextBubbleColor;
        nextBubbleColor = temp;
        _swapController.reset();
        setState(() {});
      }
    });

    currentBubbleColor = bubblePalette[0];
    nextBubbleColor = bubblePalette[1];

    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _levelUpController.dispose();
    _swapController.dispose();
    super.dispose();
  }

  void _initGame(Size size) {
    if (grid.isNotEmpty && !isGameOver) return;
    double availableWidth = size.width;
    bubbleRadius = availableWidth / (cols * 2 + 1);
    double rowHeight = bubbleRadius * sqrt(3);
    double shooterAreaHeight = 150.0;
    double playableHeight = size.height - shooterAreaHeight;
    rows = (playableHeight / rowHeight).ceil() + 2;

    _startNewGame();
  }

  void _startNewGame() {
    setState(() {
      grid = List.generate(rows, (r) => List.filled(cols, null));
      score = 0;
      level = 1;
      nextLevelScore = 1000;
      descentInterval = 15.0;
      descentTimer = 0.0;
      isGridOffset = false;

      isGameOver = false;
      isShooting = false;
      projectilePosition = null;
      isPaused = false;
      particles.clear();
      gunAngle = -pi / 2;

      int initialRows = (rows / 3).ceil();
      for (int r = 0; r < initialRows; r++) {
        for (int c = 0; c < cols; c++) {
          grid[r][c] = bubblePalette[Random().nextInt(bubblePalette.length)];
        }
      }

      currentBubbleColor =
          bubblePalette[Random().nextInt(bubblePalette.length)];
      nextBubbleColor = bubblePalette[Random().nextInt(bubblePalette.length)];
    });
  }

  void _triggerSwap() {
    if (isShooting || isGameOver || isPaused || _swapController.isAnimating)
      return;
    AudioManager.playSfx('pop.mp3');
    _swapController.forward();
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    double dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    if (dt > 0.1) dt = 0.016;
    if (isPaused) return;

    if (particles.isNotEmpty) {
      setState(() {
        for (var p in particles) {
          p.position += p.velocity;
          p.velocity += const Offset(0, 0.5);
          p.life -= 0.02;
        }
        particles.removeWhere((p) => p.life <= 0);
      });
    }

    if (isGameOver || boardSize == null) return;

    setState(() {
      descentTimer += dt;
      if (descentTimer >= descentInterval) {
        _shiftGridDown();
        descentTimer = 0;
      }
    });

    if (!isShooting || projectilePosition == null) return;

    setState(() {
      projectilePosition = projectilePosition! + projectileVelocity!;

      // Wall Bounce
      if (projectilePosition!.dx <= bubbleRadius &&
          projectileVelocity!.dx < 0) {
        projectileVelocity = Offset(
          -projectileVelocity!.dx,
          projectileVelocity!.dy,
        );
        projectilePosition = Offset(bubbleRadius, projectilePosition!.dy);
      } else if (projectilePosition!.dx >= boardSize!.width - bubbleRadius &&
          projectileVelocity!.dx > 0) {
        projectileVelocity = Offset(
          -projectileVelocity!.dx,
          projectileVelocity!.dy,
        );
        projectilePosition = Offset(
          boardSize!.width - bubbleRadius,
          projectilePosition!.dy,
        );
      }

      // Ceiling Collision
      if (projectilePosition!.dy <= bubbleRadius) {
        _snapBubbleToGrid(projectilePosition!);
        return;
      }

      // Bubble Collision
      if (_checkCollision(projectilePosition!)) {
        _snapBubbleToGrid(projectilePosition!);
      }
    });
  }

  void _shiftGridDown() {
    setState(() {
      if (_checkGameOverCondition()) {
        _gameOver();
        return;
      }
      grid.removeLast();
      List<Color?> newRow = List.generate(
        cols,
        (index) => bubblePalette[Random().nextInt(bubblePalette.length)],
      );
      grid.insert(0, newRow);
      isGridOffset = !isGridOffset;
    });
  }

  bool _checkCollision(Offset pos) {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] != null) {
          Offset bubblePos = _getGridPosition(r, c);
          double dist = (pos - bubblePos).distance;
          if (dist < bubbleRadius * 1.8) return true;
        }
      }
    }
    return false;
  }

  Offset _getGridPosition(int r, int c) {
    double x = (c * bubbleRadius * 2) + bubbleRadius;
    if ((r + (isGridOffset ? 1 : 0)) % 2 != 0) {
      x += bubbleRadius;
    }
    double y = (r * bubbleRadius * sqrt(3)) + bubbleRadius;
    return Offset(x, y);
  }

  void _snapBubbleToGrid(Offset pos) {
    AudioManager.playSfx('pop.mp3'); // Impact sound
    AudioManager.vibrate();

    int bestR = -1;
    int bestC = -1;
    double minInfoDist = double.infinity;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] == null) {
          Offset slotPos = _getGridPosition(r, c);
          if (slotPos.dx > boardSize!.width - 5) continue;

          double dist = (pos - slotPos).distance;
          if (dist < minInfoDist) {
            minInfoDist = dist;
            bestR = r;
            bestC = c;
          }
        }
      }
    }

    if (bestR != -1 && minInfoDist < bubbleRadius * 3) {
      grid[bestR][bestC] = currentBubbleColor;
      _handleMatches(bestR, bestC);

      if (_checkGameOverCondition()) {
        _gameOver();
      }
    }

    isShooting = false;
    projectilePosition = null;
    currentBubbleColor = nextBubbleColor;
    nextBubbleColor = bubblePalette[Random().nextInt(bubblePalette.length)];
  }

  bool _checkGameOverCondition() {
    double shooterY = boardSize!.height - 100;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] != null) {
          Offset pos = _getGridPosition(r, c);
          if (pos.dy + bubbleRadius >= shooterY) {
            return true;
          }
        }
      }
    }
    return false;
  }

  void _gameOver() {
    isGameOver = true;
    AudioManager.playSfx('gameover.mp3');
    AudioManager.vibrateHeavy();
    if (score > GameData.highScore) {
      GameData.highScore = score;
    }
  }

  void _handleMatches(int startR, int startC) {
    Color matchColor = grid[startR][startC]!;
    Set<Point<int>> matched = {};
    List<Point<int>> toVisit = [Point(startR, startC)];

    while (toVisit.isNotEmpty) {
      Point<int> current = toVisit.removeLast();
      if (matched.contains(current)) continue;
      matched.add(current);

      for (Point<int> neighbor in _getNeighbors(current.x, current.y)) {
        if (grid[neighbor.x][neighbor.y] == matchColor &&
            !matched.contains(neighbor)) {
          toVisit.add(neighbor);
        }
      }
    }

    if (matched.length >= 3) {
      // Pop Sound if heavy match?
      if (matched.length > 5) AudioManager.playSfx('pop.mp3');

      for (var p in matched) {
        grid[p.x][p.y] = null;
        _spawnExplosion(_getGridPosition(p.x, p.y), matchColor);
      }
      score += matched.length * 10;
      _removeFloatingBubbles();

      if (score >= nextLevelScore) {
        _levelUp();
      }
    }
  }

  void _levelUp() {
    level++;
    nextLevelScore += 1000 + (level * 500);
    descentInterval = max(2.0, descentInterval * 0.85);

    AudioManager.playSfx('levelup.mp3');
    _levelUpController.forward(from: 0);
  }

  void _spawnExplosion(Offset pos, Color color) {
    for (int i = 0; i < 8; i++) {
      double angle = Random().nextDouble() * 2 * pi;
      double speed = Random().nextDouble() * 3 + 2;
      particles.add(
        BubbleParticle(
          position: pos,
          velocity: Offset(cos(angle) * speed, sin(angle) * speed),
          color: color,
          life: 1.0,
          radius: Random().nextDouble() * 4 + 2,
        ),
      );
    }
  }

  void _removeFloatingBubbles() {
    Set<Point<int>> connected = {};
    for (int c = 0; c < cols; c++) {
      if (grid[0][c] != null) _markConnected(0, c, connected);
    }

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] != null && !connected.contains(Point(r, c))) {
          grid[r][c] = null;
          _spawnExplosion(_getGridPosition(r, c), Colors.white);
          score += 20;
        }
      }
    }
  }

  void _markConnected(int r, int c, Set<Point<int>> connected) {
    List<Point<int>> stack = [Point(r, c)];
    while (stack.isNotEmpty) {
      Point<int> current = stack.removeLast();
      if (connected.contains(current)) continue;
      connected.add(current);

      for (Point<int> neighbor in _getNeighbors(current.x, current.y)) {
        if (grid[neighbor.x][neighbor.y] != null) stack.add(neighbor);
      }
    }
  }

  List<Point<int>> _getNeighbors(int r, int c) {
    List<Point<int>> neighbors = [];
    bool isOddRow = (r + (isGridOffset ? 1 : 0)) % 2 != 0;

    List<List<int>> offsets = isOddRow
        ? [
            [-1, 0],
            [-1, 1],
            [0, -1],
            [0, 1],
            [1, 0],
            [1, 1],
          ]
        : [
            [-1, -1],
            [-1, 0],
            [0, -1],
            [0, 1],
            [1, -1],
            [1, 0],
          ];

    for (var o in offsets) {
      int nr = r + o[0];
      int nc = c + o[1];
      if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
        neighbors.add(Point(nr, nc));
      }
    }
    return neighbors;
  }

  void _shoot() {
    if (isShooting || isGameOver || isPaused || boardSize == null) return;

    AudioManager.playSfx('shoot.mp3');
    isShooting = true;
    double startX = boardSize!.width / 2;
    double startY = boardSize!.height - 50;
    projectilePosition = Offset(startX, startY);
    projectileVelocity = Offset(
      cos(gunAngle) * shooterSpeed,
      sin(gunAngle) * shooterSpeed,
    );
  }

  void _handleAim(Offset localPosition) {
    if (isGameOver || isPaused || boardSize == null) return;
    double startX = boardSize!.width / 2;
    double startY = boardSize!.height - 50;
    double dx = localPosition.dx - startX;
    double dy = localPosition.dy - startY;

    double angle = atan2(dy, dx);
    if (angle > 0) angle -= 2 * pi;
    if (angle < -pi + 0.2) angle = -pi + 0.2;
    if (angle > -0.2) angle = -0.2;

    setState(() => gunAngle = angle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (grid.isEmpty ||
                        boardSize?.width != constraints.maxWidth) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _initGame(
                          Size(constraints.maxWidth, constraints.maxHeight),
                        );
                      });
                    }
                    boardSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );

                    return GestureDetector(
                      onPanStart: (d) => _handleAim(d.localPosition),
                      onPanUpdate: (d) => _handleAim(d.localPosition),
                      onPanEnd: (d) => _shoot(),
                      child: Container(
                        color: Colors.transparent,
                        width: double.infinity,
                        height: double.infinity,
                        child: grid.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : CustomPaint(
                                painter: RealisticGamePainter(
                                  grid: grid,
                                  rows: rows,
                                  cols: cols,
                                  radius: bubbleRadius,
                                  projectilePos: projectilePosition,
                                  projectileColor: currentBubbleColor,
                                  gunAngle: gunAngle,
                                  particles: particles,
                                  isGridOffset: isGridOffset,
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
              _buildControls(),
            ],
          ),

          if (isPaused) _buildPauseOverlay(),
          if (isGameOver) _buildGameOverOverlay(),

          Positioned(
            bottom: 140,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _levelUpController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _levelUpOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - _levelUpOpacity.value) * 20),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 15,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.3),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "LEVEL UP!",
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                "Level $level • Faster Speed!",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 10),
      color: Colors.black26,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.pause_rounded, color: Colors.white),
            onPressed: () => setState(() => isPaused = true),
          ),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    "LEVEL",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    "$level",
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    "SCORE",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    "$score",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Swap Button
          GestureDetector(
            onTap: _triggerSwap,
            child: AnimatedBuilder(
              animation: _swapController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _swapRotation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "SWAP",
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                      const SizedBox(height: 5),
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white,
                                  nextBubbleColor,
                                  nextBubbleColor.withOpacity(0.8),
                                ],
                                center: const Alignment(-0.3, -0.3),
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black54, blurRadius: 5),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.sync,
                            color: Colors.white,
                            size: 16,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 2),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Shooter Visual
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: gunAngle + pi / 2,
                  child: const Icon(
                    Icons.navigation,
                    color: Colors.white38,
                    size: 40,
                  ),
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white,
                        currentBubbleColor,
                        currentBubbleColor.withOpacity(0.8),
                      ],
                      center: const Alignment(-0.3, -0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: currentBubbleColor.withOpacity(0.6),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Timer / Level Bar
          SizedBox(
            width: 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Lvl $level",
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 6,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  alignment: Alignment.bottomCenter,
                  child: LayoutBuilder(
                    builder: (ctx, c) => Container(
                      width: 6,
                      height:
                          c.maxHeight *
                          (descentTimer / descentInterval).clamp(0.0, 1.0),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          const BoxShadow(
                            color: Colors.redAccent,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Spacer(),
            const Text(
              "PAUSED",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                letterSpacing: 5,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => setState(() => isPaused = false),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                child: Text("RESUME"),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "EXIT TO MENU",
                style: TextStyle(color: Colors.white54),
              ),
            ),
            const Spacer(),
            const Text(
              "Designed and Developed by CBn",
              style: TextStyle(
                color: Colors.white30,
                fontSize: 12,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sentiment_dissatisfied,
              color: Colors.redAccent,
              size: 60,
            ),
            const SizedBox(height: 20),
            const Text(
              "GAME OVER",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "Score: $score",
              style: const TextStyle(color: Colors.white70, fontSize: 20),
            ),
            Text(
              "Level Reached: $level",
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _startNewGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                child: Text("TRY AGAIN"),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "EXIT",
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Rendering Helpers ---

class BubbleParticle {
  Offset position;
  Offset velocity;
  Color color;
  double life;
  double radius;

  BubbleParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.life,
    required this.radius,
  });
}

class RealisticGamePainter extends CustomPainter {
  final List<List<Color?>> grid;
  final int rows;
  final int cols;
  final double radius;
  final Offset? projectilePos;
  final Color? projectileColor;
  final double gunAngle;
  final List<BubbleParticle> particles;
  final bool isGridOffset;

  RealisticGamePainter({
    required this.grid,
    required this.rows,
    required this.cols,
    required this.radius,
    required this.projectilePos,
    required this.projectileColor,
    required this.gunAngle,
    required this.particles,
    required this.isGridOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Grid
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c] != null) {
          // Calculate pos
          double x = (c * radius * 2) + radius;
          // Apply offset logic
          if ((r + (isGridOffset ? 1 : 0)) % 2 != 0) {
            x += radius;
          }
          double y = (r * radius * sqrt(3)) + radius;

          _drawRealisticBubble(canvas, Offset(x, y), grid[r][c]!, radius);
        }
      }
    }

    // 2. Draw Particles
    for (var p in particles) {
      final paint = Paint()..color = p.color.withOpacity(p.life);
      canvas.drawCircle(p.position, p.radius * p.life, paint);
    }

    // 3. Draw Projectile
    if (projectilePos != null && projectileColor != null) {
      _drawRealisticBubble(canvas, projectilePos!, projectileColor!, radius);
    }

    // 4. Draw Aim Line
    Paint linePaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white.withOpacity(0.5), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    double startX = size.width / 2;
    double startY = size.height - 50;
    double dashWidth = 10;
    double dashSpace = 10;
    double distance = 0;
    double maxDist = 600;

    while (distance < maxDist) {
      canvas.drawLine(
        Offset(
          startX + cos(gunAngle) * distance,
          startY + sin(gunAngle) * distance,
        ),
        Offset(
          startX + cos(gunAngle) * (distance + dashWidth),
          startY + sin(gunAngle) * (distance + dashWidth),
        ),
        linePaint,
      );
      distance += dashWidth + dashSpace;
    }
  }

  void _drawRealisticBubble(
    Canvas canvas,
    Offset center,
    Color color,
    double rad,
  ) {
    final rect = Rect.fromCircle(center: center, radius: rad - 1);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.9), // Highlight
          color, // Main
          Color.lerp(color, Colors.black, 0.3)!, // Shadow
        ],
        stops: const [0.0, 0.4, 1.0],
        center: const Alignment(-0.4, -0.4), // Top-left light source
        radius: 1.2,
      ).createShader(rect);

    // Drop shadow
    canvas.drawCircle(
      center + const Offset(2, 2),
      rad - 2,
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    canvas.drawCircle(center, rad - 1, paint);
  }

  @override
  bool shouldRepaint(covariant RealisticGamePainter oldDelegate) => true;
}

class BackgroundBubblePainter extends CustomPainter {
  final List<BubbleParticle> bubbles;
  BackgroundBubblePainter(this.bubbles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var b in bubbles) {
      Paint paint = Paint()
        ..color = b.color.withOpacity(b.life * 0.5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(b.position, b.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BackgroundBubblePainter oldDelegate) => true;
}
