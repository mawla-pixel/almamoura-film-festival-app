import 'package:flutter/material.dart';

import '../services/film_catalog_service.dart';
import '../services/profile_repository.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'admin_catalog_screen.dart';
import 'auth_screen.dart';

/// Profile tab: shows the signed-in user's display name (editable) or a
/// guest prompt to sign in, plus a sign-out action.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _displayName;
  bool _isLoading = true;
  bool _isSaving = false;

  bool get _isSignedIn => SupabaseService.isSignedInPermanent;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!_isSignedIn) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final name = await ProfileRepository.fetchDisplayName();
      if (mounted) setState(() => _displayName = name);
    } catch (_) {
      // Ignore: profile stays unset if the fetch fails.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editDisplayName() async {
    final controller = TextEditingController(text: _displayName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Your name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await ProfileRepository.updateDisplayName(result);
      if (mounted) setState(() => _displayName = result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save name: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _signOut() async {
    await SupabaseService.auth.signOut();
    if (!mounted) return;
    setState(() {
      _displayName = null;
      _isLoading = false;
    });
  }

  void _goToSignIn() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  void _showUnavailable(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label will be available soon.')),
    );
  }

  Widget _profileRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final color = destructive ? Colors.red.shade700 : AppColors.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.fromLTRB(26, 24, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE1E1E1)),
        ),
        child: Row(
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: destructive ? const Color(0xFFFFF2F2) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(width: 26),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: destructive ? color : const Color(0xFF707070),
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 34, color: destructive ? Colors.redAccent : Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final name = _displayName?.isNotEmpty == true
        ? _displayName!
      : 'Amina Mohammed';
    final initials = name.trim().isEmpty
        ? 'AM'
        : name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((word) => word[0].toUpperCase())
              .join();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(38, 48, 38, 46),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ALMAMOURA FILM FESTIVAL',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF575757),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 4.2,
              ),
            ),
            const SizedBox(height: 68),
            Row(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.ink,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 26),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Festival member since\n2026',
                        style: TextStyle(color: Color(0xFF737373), fontSize: 23, height: 1.35),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _isSignedIn && !_isSaving ? _editDisplayName : _goToSignIn,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Edit profile'),
                ),
              ],
            ),
            const SizedBox(height: 46),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFE1E1E1)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ProfileStat(value: '12', label: 'Votes'),
                  _ProfileStat(value: '8', label: 'Liked films'),
                  _ProfileStat(value: '2', label: 'Submissions'),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _profileRow(
              icon: Icons.star_border_rounded,
              title: 'My Votes',
              subtitle: '12 votes cast',
              onTap: () => _showUnavailable('My Votes'),
            ),
            const SizedBox(height: 20),
            _profileRow(
              icon: Icons.favorite_border,
              title: 'Liked Films',
              subtitle: '8 films saved',
              onTap: () => _showUnavailable('Liked Films'),
            ),
            const SizedBox(height: 20),
            _profileRow(
              icon: Icons.credit_card_outlined,
              title: 'Payments',
              subtitle: 'Manage voting bundles and receipts',
              onTap: () => _showUnavailable('Payments'),
            ),
            const SizedBox(height: 20),
            _profileRow(
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'Language, notifications and account',
              onTap: () => _showUnavailable('Settings'),
            ),
            const SizedBox(height: 20),
            _profileRow(
              icon: Icons.logout,
              title: 'Log out',
              subtitle: 'Sign out of this account',
              destructive: true,
              onTap: _isSignedIn ? _signOut : _goToSignIn,
            ),
            if (FilmCatalogService.isAdmin) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminCatalogScreen()),
                ),
                child: const Text('Imported film catalog'),
              ),
            ],
            const SizedBox(height: 72),
            const Text(
              'Almamoura Film Festival · Abu Dhabi, UAE',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF707070), fontSize: 17),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Color(0xFF737373), fontSize: 18)),
        ],
      ),
    );
  }
}
