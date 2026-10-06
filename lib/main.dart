import 'dart:async';

import 'package:flutter/material.dart';

const hungerInterval = Duration(seconds: 30);
const winDuration = Duration(minutes: 3);
const animationDuration = Duration(milliseconds: 400);

enum Mood { unhappy, neutral, happy }

Mood moodFor(int happiness) {
  if (happiness > 70) return Mood.happy;
  if (happiness >= 30) return Mood.neutral;
  return Mood.unhappy;
}

Color tintFor(int happiness) => switch (moodFor(happiness)) {
  Mood.happy => Colors.lightGreen,
  Mood.neutral => Colors.amber,
  Mood.unhappy => Colors.redAccent,
};

String moodLabel(int happiness) => switch (moodFor(happiness)) {
  Mood.happy => 'Happy',
  Mood.neutral => 'Neutral',
  Mood.unhappy => 'Unhappy',
};

bool isLoss(int hunger, int happiness) => hunger >= 100 && happiness <= 10;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Pet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const PetScreen(),
    );
  }
}

class PetScreen extends StatefulWidget {
  const PetScreen({
    super.key,
    this.initialHappiness = 50,
    this.initialHunger = 50,
  });

  final int initialHappiness;
  final int initialHunger;

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> {
  String _petName = 'Pip';
  late int _happiness = _clampMeter(widget.initialHappiness);
  late int _hunger = _clampMeter(widget.initialHunger);
  bool _gameOver = false;
  bool _hasWon = false;
  bool _paused = false;
  bool _bouncing = false;
  final TextEditingController _nameController = TextEditingController();
  String _message = 'Keep happiness above 80 for 3 minutes to win!';
  Timer? _hungerTimer;
  Timer? _winTimer;
  Timer? _bounceTimer;

  int _clampMeter(int value) => value.clamp(0, 100).toInt();
  bool get _actionsDisabled => _gameOver || _hasWon || _paused;

  @override
  void initState() {
    super.initState();
    _startHungerTimer();
    _updateWinTimer();
  }

  void _startHungerTimer() {
    _hungerTimer?.cancel();
    _hungerTimer = Timer.periodic(hungerInterval, (_) => _onHungerTick());
  }

  void _onHungerTick() {
    setState(() {
      if (_hunger >= 100) {
        _happiness = _clampMeter(_happiness - 20);
        _message = '$_petName is starving and losing happiness!';
      } else {
        _hunger = _clampMeter(_hunger + 5);
      }
      _checkOutcome();
    });
  }

  void _updateWinTimer() {
    final streakActive = _happiness > 80 && !_paused && !_gameOver && !_hasWon;
    if (!streakActive) {
      _winTimer?.cancel();
      _winTimer = null;
    } else {
      _winTimer ??= Timer(winDuration, () {
        setState(() {
          _hasWon = true;
          _message = 'You win! $_petName stayed happy for 3 minutes.';
          _stopTimers();
        });
      });
    }
  }

  void _checkOutcome() {
    if (isLoss(_hunger, _happiness)) {
      _gameOver = true;
      _message = 'Game over! $_petName was too hungry and unhappy.';
      _stopTimers();
    } else {
      _updateWinTimer();
    }
  }

  void _stopTimers() {
    _hungerTimer?.cancel();
    _winTimer?.cancel();
    _hungerTimer = null;
    _winTimer = null;
  }

  void _applyAction(int happinessChange, int hungerChange, String message) {
    if (_actionsDisabled) return;
    setState(() {
      _happiness = _clampMeter(_happiness + happinessChange);
      _hunger = _clampMeter(_hunger + hungerChange);
      _message = message;
      _bouncing = true;
      _checkOutcome();
    });
    _bounceTimer?.cancel();
    _bounceTimer = Timer(const Duration(milliseconds: 200), () {
      setState(() => _bouncing = false);
    });
  }

  void _feed() => _applyAction(10, -10, '$_petName enjoyed a meal.');

  void _play() => _applyAction(15, 5, '$_petName had fun playing!');

  void _togglePause() {
    if (_gameOver || _hasWon) return;
    setState(() {
      _paused = !_paused;
      if (_paused) {
        _hungerTimer?.cancel();
        _hungerTimer = null;
        _message = 'Paused. Hunger is on hold.';
      } else {
        _startHungerTimer();
        _message = 'Resumed. Take care of $_petName!';
      }
      _updateWinTimer();
    });
  }

  void _confirmName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _message = 'Please enter a name for your pet.');
      return;
    }
    setState(() {
      _petName = name;
      _message = 'Meet $_petName!';
    });
    _nameController.clear();
  }

  void _reset() {
    setState(() {
      _stopTimers();
      _bounceTimer?.cancel();
      _petName = 'Pip';
      _happiness = _clampMeter(widget.initialHappiness);
      _hunger = _clampMeter(widget.initialHunger);
      _gameOver = false;
      _hasWon = false;
      _paused = false;
      _bouncing = false;
      _message = 'Keep happiness above 80 for 3 minutes to win!';
      _nameController.clear();
      _startHungerTimer();
      _updateWinTimer();
    });
  }

  @override
  void dispose() {
    _hungerTimer?.cancel();
    _winTimer?.cancel();
    _bounceTimer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  Widget _meter(String label, int value, Color color, Duration duration) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value'),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(end: value / 100),
          duration: duration,
          builder: (context, progress, _) => LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            color: color,
            semanticsLabel: label,
            semanticsValue: '$value',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion ? Duration.zero : animationDuration;
    final mood = moodLabel(_happiness);

    return Scaffold(
      appBar: AppBar(title: const Text('Digital Pet'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedScale(
              scale: _bouncing && !reduceMotion ? 1.15 : 1.0,
              duration: duration,
              curve: Curves.easeOutBack,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  tintFor(_happiness),
                  BlendMode.modulate,
                ),
                child: Image.asset(
                  'assets/pet.png',
                  height: 180,
                  semanticLabel: '$_petName looks $mood',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Hi, I'm $_petName!",
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            Text(
              mood.toUpperCase(),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _meter('Happiness', _happiness, tintFor(_happiness), duration),
            const SizedBox(height: 12),
            _meter('Hunger', _hunger, Colors.deepOrange, duration),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Pet name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _confirmName(),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _confirmName,
              child: const Text('Set Name'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _actionsDisabled ? null : _feed,
                    child: const Text('Feed'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _actionsDisabled ? null : _play,
                    child: const Text('Play'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _gameOver || _hasWon ? null : _togglePause,
              child: Text(_paused ? 'Resume' : 'Pause'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _reset, child: const Text('Reset')),
            const SizedBox(height: 16),
            Text(_message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
