import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/auth.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/mandala.dart';

enum _Mode { login, register, forgot, reset }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _code = TextEditingController();
  _Mode _mode = _Mode.login;
  bool _busy = false;
  bool _obscure = true;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = ref.read(authProvider.notifier);
    try {
      switch (_mode) {
        case _Mode.login:
          await auth.login(_email.text.trim(), _password.text);
        case _Mode.register:
          await auth.register(_email.text.trim(), _password.text, _name.text.trim());
        case _Mode.forgot:
          await auth.forgotPassword(_email.text.trim());
          if (mounted) toast(context, 'If the account exists, a 6-digit code was emailed.');
          setState(() => _mode = _Mode.reset);
          return;
        case _Mode.reset:
          await auth.resetPassword(_email.text.trim(), _code.text.trim(), _password.text);
          if (mounted) toast(context, 'Password updated. Please sign in.');
          setState(() => _mode = _Mode.login);
          return;
      }
      if (mounted) {
        toast(context, 'Welcome 🙏');
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_mode) {
      _Mode.login => 'Sign in',
      _Mode.register => 'Create account',
      _Mode.forgot => 'Forgot password',
      _Mode.reset => 'Set a new password',
    };
    return Scaffold(
      appBar: AppBar(),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Mandala(size: 140, color: Palette.saffron, opacity: 0.3),
                  Text(
                    'ॐ',
                    style: TextStyle(fontFamily: scriptureFont, fontSize: 48, color: Palette.saffron),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text(
              'An account is optional. It only syncs favourites and Premium across devices.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_mode == _Mode.register) ...[
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(hintText: 'Name (optional)'),
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 4),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) =>
                  v != null && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? null : 'Enter a valid email',
            ),
            const SizedBox(height: 12),
            if (_mode == _Mode.reset) ...[
              TextFormField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(hintText: '6-digit code', prefixIcon: Icon(Icons.pin_outlined)),
                validator: (v) => v != null && RegExp(r'^\d{6}$').hasMatch(v) ? null : 'Enter the 6-digit code',
              ),
              const SizedBox(height: 4),
            ],
            if (_mode != _Mode.forgot)
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: [_mode == _Mode.login ? AutofillHints.password : AutofillHints.newPassword],
                decoration: InputDecoration(
                  hintText: _mode == _Mode.reset ? 'New password' : 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter your password';
                  if (_mode != _Mode.login && v.length < 8) return 'At least 8 characters';
                  return null;
                },
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(title),
            ),
            const SizedBox(height: 12),
            if (_mode == _Mode.login) ...[
              TextButton(
                onPressed: () => setState(() => _mode = _Mode.register),
                child: const Text('New here? Create an account'),
              ),
              TextButton(onPressed: () => setState(() => _mode = _Mode.forgot), child: const Text('Forgot password?')),
            ] else
              TextButton(onPressed: () => setState(() => _mode = _Mode.login), child: const Text('Back to sign in')),
          ],
        ),
      ),
    );
  }
}
