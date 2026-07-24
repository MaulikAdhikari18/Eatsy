import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';

/// Reached from Dashboard's profile menu. Deliberately its own screen
/// rather than a dialog — this is a store-required, irreversible,
/// destructive action, and a full screen forces a real "stop and read"
/// moment in a way a dismissible dialog doesn't.
///
/// Confirmation is type-to-confirm ("DELETE") rather than re-entering
/// the password. Password re-entry proves *identity* (this device
/// might not be the account owner), which matters for something like
/// changing the password itself — but here the device is already
/// holding a live, unexpired session, so identity isn't really in
/// question. What actually needs confirming is *intent*: that this
/// isn't an accidental tap. Typing the word does that without adding
/// friction that doesn't map to the actual risk.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  static const _confirmWord = 'DELETE';

  final _confirmController = TextEditingController();
  bool _isDeleting = false;
  String? _errorMessage;

  bool get _isConfirmed =>
      _confirmController.text.trim() == _confirmWord;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      // The account and its session no longer exist at this point —
      // go straight to Login rather than back through Dashboard, which
      // would just immediately bounce anyway once it hits a signed-out
      // Supabase client.
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Back button — same circular chip treatment used across
              // the auth screens (Signup, Forgot Password).
              GestureDetector(
                onTap: _isDeleting ? null : () => Navigator.pop(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back_ios_new,
                      size: 16, color: colors.textPrimary),
                ),
              ),

              const SizedBox(height: 28),

              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    size: 32, color: Colors.red),
              ),
              const SizedBox(height: 20),

              Text(
                'Delete your account',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "This can't be undone. Deleting your account permanently removes:",
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _DeletionItem('Your food log and nutrition history'),
                    _DeletionItem('Weight and water tracking history'),
                    _DeletionItem('Saved meal plans'),
                    _DeletionItem('Goals and diet preferences'),
                    _DeletionItem('Your profile and login itself'),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'TYPE "DELETE" TO CONFIRM',
                style: AppFonts.mono(
                  fontSize: 11,
                  color: colors.textSecondary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmController,
                enabled: !_isDeleting,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'DELETE',
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: (_isConfirmed && !_isDeleting)
                    ? _deleteAccount
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  disabledBackgroundColor: colors.surfaceVariant,
                ),
                child: _isDeleting
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text('Permanently Delete Account'),
              ),

              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: _isDeleting ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeletionItem extends StatelessWidget {
  final String text;
  const _DeletionItem(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.close, size: 16, color: Colors.red.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}