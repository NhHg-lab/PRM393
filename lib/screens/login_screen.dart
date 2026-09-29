import 'package:flutter/material.dart';

import '../app.dart';
import '../config/asset_paths.dart';
import '../widgets/game_logo.dart';
import '../widgets/media_backdrop.dart';
import '../widgets/sound_volume_control.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController(text: 'admin');
  final _password = TextEditingController(text: '123456');
  bool _obscure = true;
  bool _musicStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_musicStarted) return;
    _musicStarted = true;
    GameScope.of(context, listen: false).ensureMenuMusic();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _login() {
    final controller = GameScope.of(context, listen: false);
    controller.playClick();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final error = controller.login(_username.text, _password.text);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MediaBackdrop(
        assetPath: AssetPaths.loginBackground,
        child: Stack(
          children: [
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight > 32
                            ? constraints.maxHeight - 32
                            : 0,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1080),
                          child: Row(
                            children: [
                          const Expanded(
                            flex: 6,
                            child: Center(
                              child: GameLogo(
                                runnerAsset: AssetPaths.homeRunner,
                              ),
                            ),
                          ),
                          const SizedBox(width: 40),
                          Expanded(
                            flex: 5,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(22),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Text(
                                        'PLAYER LOGIN',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      TextFormField(
                                        controller: _username,
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(
                                          labelText: 'Username',
                                          prefixIcon: Icon(
                                            Icons.person_rounded,
                                          ),
                                        ),
                                        validator: (value) =>
                                            value == null ||
                                                value.trim().isEmpty
                                            ? 'Vui lòng nhập username.'
                                            : null,
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _password,
                                        obscureText: _obscure,
                                        onFieldSubmitted: (_) => _login(),
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          prefixIcon: const Icon(
                                            Icons.lock_rounded,
                                          ),
                                          suffixIcon: IconButton(
                                            onPressed: () => setState(
                                              () => _obscure = !_obscure,
                                            ),
                                            icon: Icon(
                                              _obscure
                                                  ? Icons.visibility_rounded
                                                  : Icons
                                                        .visibility_off_rounded,
                                            ),
                                          ),
                                        ),
                                        validator: (value) =>
                                            value == null || value.isEmpty
                                            ? 'Vui lòng nhập password.'
                                            : null,
                                      ),
                                      const SizedBox(height: 14),
                                      FilledButton.icon(
                                        onPressed: _login,
                                        icon: const Icon(Icons.login_rounded),
                                        label: const Text('LOGIN'),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Demo: admin / 123456',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.62,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
            const Positioned(
              top: 12,
              right: 18,
              child: SafeArea(
                child: SoundVolumeControl(decorated: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
