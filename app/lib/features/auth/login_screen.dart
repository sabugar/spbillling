import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/design_tokens.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .login(_userCtrl.text.trim(), _passCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: DT.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DT.s24),
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(DT.s24),
            decoration: BoxDecoration(
              color: DT.surface,
              borderRadius: BorderRadius.circular(DT.rLg),
              border: Border.all(color: DT.border),
              boxShadow: DT.shMd,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: DT.brand600,
                      borderRadius: BorderRadius.circular(DT.rMd),
                    ),
                    child: const Icon(Icons.local_gas_station,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: DT.s16),
                  Text(
                    'SP Gas Billing',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  const SizedBox(height: DT.s4),
                  const Text(
                    'S. P. Gas Agency — sign in to continue',
                    style: TextStyle(color: DT.text2, fontSize: DT.fsSm),
                  ),
                  const SizedBox(height: DT.s24),
                  if (state.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(DT.s12),
                      decoration: BoxDecoration(
                        color: DT.err50,
                        borderRadius: BorderRadius.circular(DT.rSm),
                        border: Border.all(color: DT.err500.withValues(alpha: .3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 18, color: DT.err700),
                          const SizedBox(width: DT.s8),
                          Expanded(
                            child: Text(
                              state.error!,
                              style: const TextStyle(
                                color: DT.err700,
                                fontSize: DT.fsSm,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DT.s16),
                  ],
                  TextFormField(
                    controller: _userCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline, size: 18),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: DT.s12),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            size: 18),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: DT.s24),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: state.loading ? null : _submit,
                      child: state.loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text('Sign in'),
                    ),
                  ),
                  const SizedBox(height: DT.s16),
                  const Text(
                    'Default: admin / admin123',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: DT.text3, fontSize: DT.fsSm),
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
