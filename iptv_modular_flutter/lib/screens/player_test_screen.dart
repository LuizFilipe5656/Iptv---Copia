import 'package:flutter/material.dart';
import 'player_screen.dart';

class PlayerTestScreen extends StatelessWidget {
  const PlayerTestScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teste do Player')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Reproduzir vídeo de teste'),
          onPressed: () {
            Navigator.of(context).pushNamed(
              PlayerScreen.routeName,
              arguments: const PlayerLaunchRequest(
                url:
                    'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
                contentId: 'teste-player-mdn',
                contentTitle: 'Teste de Reprodução',
              ),
            );
          },
        ),
      ),
    );
  }
}
