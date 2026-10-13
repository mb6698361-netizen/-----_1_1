import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const GangWarGame());
}

class GangWarGame extends StatelessWidget {
  const GangWarGame({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'صراع العصابات',
      home: GameScreen(),
    );
  }
}

class Enemy {
  Offset position;
  double health;

  Enemy(this.position, {this.health = 2});
}

class Bullet {
  Offset position;
  final Offset direction;

  Bullet(this.position, this.direction);
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final Random random = Random();

  Offset player = const Offset(0, 0);
  Offset joystick = Offset.zero;
  Offset joystickOrigin = Offset.zero;

  final List<Enemy> enemies = [];
  final List<Bullet> bullets = [];

  Timer? gameTimer;

  double worldX = 0;
  double worldY = 0;

  int score = 0;
  int health = 100;
  int wave = 1;

  bool gameOver = false;
  bool firing = false;

  Size screenSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    gameTimer?.cancel();

    player = Offset.zero;
    joystick = Offset.zero;
    enemies.clear();
    bullets.clear();

    score = 0;
    health = 100;
    wave = 1;
    gameOver = false;
    firing = false;

    _spawnWave();

    gameTimer = Timer.periodic(
      const Duration(milliseconds: 30),
      (_) => _updateGame(),
    );
  }

  void _spawnWave() {
    final count = min(3 + wave * 2, 20);

    for (int i = 0; i < count; i++) {
      final angle = random.nextDouble() * pi * 2;
      final distance = 260 + random.nextDouble() * 250;

      enemies.add(
        Enemy(
          Offset(
            player.dx + cos(angle) * distance,
            player.dy + sin(angle) * distance,
          ),
          health: 2 + wave * 0.2,
        ),
      );
    }
  }

  void _updateGame() {
    if (!mounted || gameOver) return;

    setState(() {
      // تحريك اللاعب
      player += joystick * 4.0;

      // إطلاق النار في اتجاه أقرب عدو
      if (firing && enemies.isNotEmpty) {
        if (random.nextInt(4) == 0) {
          Enemy? target;
          double nearest = double.infinity;

          for (final enemy in enemies) {
            final distance = (enemy.position - player).distance;
            if (distance < nearest) {
              nearest = distance;
              target = enemy;
            }
          }

          if (target != null && nearest < 550) {
            final difference = target.position - player;
            final length = max(difference.distance, 1.0);

            bullets.add(
              Bullet(
                player,
                Offset(difference.dx / length, difference.dy / length),
              ),
            );
          }
        }
      }

      // حركة الرصاص
      for (final bullet in bullets) {
        bullet.position += bullet.direction * 13;
      }

      // حركة الأعداء
      for (final enemy in enemies) {
        final difference = player - enemy.position;
        final distance = difference.distance;

        if (distance > 35) {
          enemy.position +=
              Offset(difference.dx / distance, difference.dy / distance) *
                  (0.65 + wave * 0.08);
        } else {
          health -= 1;

          if (health <= 0) {
            health = 0;
            gameOver = true;
            gameTimer?.cancel();
          }
        }
      }

      // إصابة الأعداء بالرصاص
      final deadBullets = <Bullet>[];

      for (final bullet in bullets) {
        for (final enemy in enemies) {
          if ((bullet.position - enemy.position).distance < 24) {
            enemy.health -= 1;
            deadBullets.add(bullet);
            break;
          }
        }
      }

      bullets.removeWhere((b) {
        return deadBullets.contains(b) ||
            (b.position - player).distance > 1000;
      });

      final defeated = enemies.where((e) => e.health <= 0).toList();

      score += defeated.length * 10;
      enemies.removeWhere((e) => e.health <= 0);

      if (enemies.isEmpty) {
        wave++;
        _spawnWave();
      }

      worldX = player.dx;
      worldY = player.dy;
    });
  }

  Offset _screenPosition(Offset worldPosition) {
    return Offset(
      screenSize.width / 2 + worldPosition.dx - worldX,
      screenSize.height / 2 + worldPosition.dy - worldY,
    );
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF202A28),
      body: LayoutBuilder(
        builder: (context, constraints) {
          screenSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: CityPainter(
                    player: player,
                    enemies: enemies,
                    bullets: bullets,
                    cameraPosition: Offset(worldX, worldY),
                  ),
                ),
              ),

              // لوحة المعلومات
              Positioned(
                top: 14,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⚔ صراع العصابات',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'النقاط: $score',
                        style: const TextStyle(color: Colors.amber),
                      ),
                      Text(
                        'الموجة: $wave',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 130,
                        child: LinearProgressIndicator(
                          value: health / 100,
                          minHeight: 8,
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            health > 30 ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                      Text(
                        'الصحة: $health%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // عصا الحركة
              Positioned(
                left: 28,
                bottom: 22,
                child: GestureDetector(
                  onPanStart: (details) {
                    final box = context.findRenderObject() as RenderBox;
                    joystickOrigin =
                        box.globalToLocal(details.globalPosition);
                  },
                  onPanUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox;
                    final current =
                        box.globalToLocal(details.globalPosition);

                    final delta = current - joystickOrigin;
                    final length = max(delta.distance, 1.0);
                    const maxRadius = 48.0;

                    final limited = min(length, maxRadius);

                    setState(() {
                      joystick = Offset(
                        delta.dx / length * limited / maxRadius,
                        delta.dy / length * limited / maxRadius,
                      );
                    });
                  },
                  onPanEnd: (_) {
                    setState(() => joystick = Offset.zero);
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white38, width: 2),
                    ),
                    child: Center(
                      child: Transform.translate(
                        offset: joystick * 35,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.gamepad_rounded,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // زر إطلاق النار
              Positioned(
                right: 28,
                bottom: 35,
                child: GestureDetector(
                  onTapDown: (_) => setState(() => firing = true),
                  onTapUp: (_) => setState(() => firing = false),
                  onTapCancel: () => setState(() => firing = false),
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.85),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.gps_fixed_rounded,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                ),
              ),

              // نهاية اللعبة
              if (gameOver)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.82),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.dangerous_rounded,
                            color: Colors.red,
                            size: 75,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'انتهت اللعبة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'مجموع نقاطك: $score',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(_startGame);
                            },
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text('العب من جديد'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class CityPainter extends CustomPainter {
  final Offset player;
  final List<Enemy> enemies;
  final List<Bullet> bullets;
  final Offset cameraPosition;

  CityPainter({
    required this.player,
    required this.enemies,
    required this.bullets,
    required this.cameraPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFF34443A);
    canvas.drawRect(Offset.zero & size, background);

    canvas.save();
    canvas.translate(
      size.width / 2 - cameraPosition.dx,
      size.height / 2 - cameraPosition.dy,
    );

    // شبكة شوارع المدينة
    final road = Paint()..color = const Color(0xFF414747);
    final roadLine = Paint()
      ..color = const Color(0xFFB8B9A3)
      ..strokeWidth = 2;

    const gridSize = 240.0;

    final minX =
        ((cameraPosition.dx - size.width / 2) / gridSize).floor() - 1;
    final maxX =
        ((cameraPosition.dx + size.width / 2) / gridSize).ceil() + 1;
    final minY =
        ((cameraPosition.dy - size.height / 2) / gridSize).floor() - 1;
    final maxY =
        ((cameraPosition.dy + size.height / 2) / gridSize).ceil() + 1;

    for (int x = minX; x <= maxX; x++) {
      final px = x * gridSize;

      canvas.drawRect(
        Rect.fromLTWH(px - 34, minY * gridSize, 68,
            (maxY - minY + 1) * gridSize),
        road,
      );

      canvas.drawLine(
        Offset(px, minY * gridSize),
        Offset(px, (maxY + 1) * gridSize),
        roadLine,
      );
    }

    for (int y = minY; y <= maxY; y++) {
      final py = y * gridSize;

      canvas.drawRect(
        Rect.fromLTWH(minX * gridSize, py - 34,
            (maxX - minX + 1) * gridSize, 68),
        road,
      );

      canvas.drawLine(
        Offset(minX * gridSize, py),
        Offset((maxX + 1) * gridSize, py),
        roadLine,
      );
    }

    // مباني المدينة
    final buildingPaint = Paint()..color = const Color(0xFF69716E);
    final buildingDark = Paint()..color = const Color(0xFF515A57);
    final windows = Paint()..color = const Color(0xFFD6C98A);

    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        final baseX = x * gridSize;
        final baseY = y * gridSize;

        final rect = Rect.fromLTWH(
          baseX + 48,
          baseY + 48,
          130,
          130,
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.shift(const Offset(6, 7)),
            const Radius.circular(5),
          ),
          buildingDark,
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(5)),
          buildingPaint,
        );

        for (int wx = 0; wx < 3; wx++) {
          for (int wy = 0; wy < 3; wy++) {
            canvas.drawRect(
              Rect.fromLTWH(
                baseX + 62 + wx * 38,
                baseY + 62 + wy * 35,
                18,
                18,
              ),
              windows,
            );
          }
        }
      }
    }

    // الأعداء
    for (final enemy in enemies) {
      canvas.drawCircle(
        enemy.position,
        17,
        Paint()..color = const Color(0xFF7F1D1D),
      );

      canvas.drawCircle(
        enemy.position + const Offset(-5, -3),
        3,
        Paint()..color = Colors.white,
      );

      canvas.drawCircle(
        enemy.position + const Offset(5, -3),
        3,
        Paint()..color = Colors.white,
      );

      canvas.drawRect(
        Rect.fromCenter(
          center: enemy.position + const Offset(0, -25),
          width: 35,
          height: 4,
        ),
        Paint()..color = Colors.red,
      );

      canvas.drawRect(
        Rect.fromLTWH(
          enemy.position.dx - 17.5,
          enemy.position.dy - 27,
          35 * (enemy.health / 3).clamp(0.0, 1.0),
          4,
        ),
        Paint()..color = Colors.green,
      );
    }

    // الرصاص
    final bulletPaint = Paint()..color = Colors.amber;

    for (final bullet in bullets) {
      canvas.drawCircle(bullet.position, 5, bulletPaint);
    }

    // اللاعب
    canvas.drawCircle(
      player,
      22,
      Paint()..color = const Color(0xFF1687FF),
    );

    canvas.drawCircle(
      player + const Offset(0, -5),
      8,
      Paint()..color = const Color(0xFFFFD7B0),
    );

    canvas.drawCircle(
      player + const Offset(-3, -7),
      2,
      Paint()..color = Colors.black,
    );

    canvas.drawCircle(
      player + const Offset(3, -7),
      2,
      Paint()..color = Colors.black,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: player + const Offset(0, 9),
          width: 27,
          height: 18,
        ),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF123E76),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CityPainter oldDelegate) => true;
}