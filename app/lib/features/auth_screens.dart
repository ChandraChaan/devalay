import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/auth.dart';
import '../core/i18n.dart';
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
          if (mounted) {
            toast(
              context,
              t3(
                appLang,
                'If the account exists, a 6-digit code was emailed.',
                'अगर यह खाता मौजूद है, तो 6 अंकों का कोड ईमेल कर दिया गया है।',
                'ఈ ఖాతా ఉంటే, 6 అంకెల కోడ్ ఈమెయిల్‌కు పంపాం.',
              ),
            );
          }
          setState(() => _mode = _Mode.reset);
          return;
        case _Mode.reset:
          await auth.resetPassword(_email.text.trim(), _code.text.trim(), _password.text);
          if (mounted) {
            toast(
              context,
              t3(
                appLang,
                'Password updated. Please sign in.',
                'पासवर्ड बदल गया। कृपया साइन इन करें।',
                'పాస్‌వర్డ్ మార్చాం. దయచేసి సైన్ ఇన్ చేయండి.',
              ),
            );
          }
          setState(() => _mode = _Mode.login);
          return;
      }
      if (mounted) {
        toast(context, t3(appLang, 'Welcome 🙏', 'स्वागत है 🙏', 'స్వాగతం 🙏'));
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
      _Mode.login => l3(ref, 'Sign in', 'साइन इन', 'సైన్ ఇన్'),
      _Mode.register => l3(ref, 'Create account', 'खाता बनाएँ', 'ఖాతా సృష్టించండి'),
      _Mode.forgot => l3(ref, 'Forgot password', 'पासवर्ड भूल गए', 'పాస్‌వర్డ్ మర్చిపోయారు'),
      _Mode.reset => l3(ref, 'Set a new password', 'नया पासवर्ड बनाएँ', 'కొత్త పాస్‌వర్డ్ పెట్టుకోండి'),
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
            Text(
              l3(
                ref,
                'An account is optional. It only syncs favourites and Premium across devices.',
                'खाता ज़रूरी नहीं है। यह सिर्फ़ पसंदीदा और प्रीमियम को आपके सभी डिवाइस पर सिंक करता है।',
                'ఖాతా తప్పనిసరి కాదు. ఇది ఇష్టమైనవి, ప్రీమియంను మీ అన్ని పరికరాల్లో సింక్ చేయడానికి మాత్రమే.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_mode == _Mode.register) ...[
              TextFormField(
                controller: _name,
                decoration: InputDecoration(hintText: l3(ref, 'Name (optional)', 'नाम (वैकल्पिक)', 'పేరు (ఐచ్ఛికం)')),
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 4),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                hintText: l3(ref, 'Email', 'ईमेल', 'ఈమెయిల్'),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              validator: (v) => v != null && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())
                  ? null
                  : t3(appLang, 'Enter a valid email', 'सही ईमेल डालें', 'సరైన ఈమెయిల్ ఇవ్వండి'),
            ),
            const SizedBox(height: 12),
            if (_mode == _Mode.reset) ...[
              TextFormField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: l3(ref, '6-digit code', '6 अंकों का कोड', '6 అంకెల కోడ్'),
                  prefixIcon: const Icon(Icons.pin_outlined),
                ),
                validator: (v) => v != null && RegExp(r'^\d{6}$').hasMatch(v)
                    ? null
                    : t3(appLang, 'Enter the 6-digit code', '6 अंकों का कोड डालें', '6 అంకెల కోడ్ ఇవ్వండి'),
              ),
              const SizedBox(height: 4),
            ],
            if (_mode != _Mode.forgot)
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: [_mode == _Mode.login ? AutofillHints.password : AutofillHints.newPassword],
                decoration: InputDecoration(
                  hintText: _mode == _Mode.reset
                      ? l3(ref, 'New password', 'नया पासवर्ड', 'కొత్త పాస్‌వర్డ్')
                      : l3(ref, 'Password', 'पासवर्ड', 'పాస్‌వర్డ్'),
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return t3(appLang, 'Enter your password', 'अपना पासवर्ड डालें', 'మీ పాస్‌వర్డ్ ఇవ్వండి');
                  }
                  if (_mode != _Mode.login && v.length < 8) {
                    return t3(appLang, 'At least 8 characters', 'कम से कम 8 अक्षर', 'కనీసం 8 అక్షరాలు');
                  }
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
                child: Text(
                  l3(ref, 'New here? Create an account', 'नए हैं? खाता बनाएँ', 'కొత్తగా వచ్చారా? ఖాతా సృష్టించండి'),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _mode = _Mode.forgot),
                child: Text(l3(ref, 'Forgot password?', 'पासवर्ड भूल गए?', 'పాస్‌వర్డ్ మర్చిపోయారా?')),
              ),
            ] else
              TextButton(
                onPressed: () => setState(() => _mode = _Mode.login),
                child: Text(l3(ref, 'Back to sign in', 'साइन इन पर वापस जाएँ', 'సైన్ ఇన్‌కు వెనక్కి')),
              ),
          ],
        ),
      ),
    );
  }
}
