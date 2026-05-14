import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/theme_colors.dart';

class ProfilePhotoAvatar extends StatefulWidget {
  final String userId;
  final String initial;
  final double size;
  final bool isCircle;
  final double borderRadius;
  final Decoration? emptyDecoration;
  final double badgeSize;
  final double badgeIconSize;

  const ProfilePhotoAvatar({
    super.key,
    required this.userId,
    required this.initial,
    this.size = 80,
    this.isCircle = true,
    this.borderRadius = 16,
    this.emptyDecoration,
    this.badgeSize = 28,
    this.badgeIconSize = 14,
  });

  @override
  State<ProfilePhotoAvatar> createState() => _ProfilePhotoAvatarState();
}

class _ProfilePhotoAvatarState extends State<ProfilePhotoAvatar> {
  String? _photoPath;
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_photo_${widget.userId}');
    if (mounted) {
      setState(() {
        _photoPath = (path != null && File(path).existsSync()) ? path : null;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final destPath = '${dir.path}/profile_${widget.userId}.jpg';
      await File(picked.path).copy(destPath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_photo_${widget.userId}', destPath);

      if (mounted) setState(() => _photoPath = destPath);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Não foi possível selecionar a foto. Tente novamente.')),
        );
      }
    }
  }

  Future<void> _removePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_photo_${widget.userId}');
    if (_photoPath != null) {
      final file = File(_photoPath!);
      if (file.existsSync()) await file.delete();
    }
    if (mounted) setState(() => _photoPath = null);
  }

  Future<void> _confirmAndRemove(BuildContext sheetCtx) async {
    Navigator.pop(sheetCtx);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover foto'),
        content: const Text('Deseja remover a foto de perfil?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) _removePhoto();
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: context.colors.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Foto de perfil',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: AppColors.primary),
                ),
                title: Text('Tirar foto',
                    style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w500)),
                subtitle: Text('Usar câmera do dispositivo',
                    style: TextStyle(
                        color: context.colors.textSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library, color: AppColors.primary),
                ),
                title: Text('Escolher da galeria',
                    style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w500)),
                subtitle: Text('Selecionar imagem existente',
                    style: TextStyle(
                        color: context.colors.textSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_photoPath != null) ...[
                Divider(color: context.colors.border),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  title: const Text('Remover foto',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w500)),
                  onTap: () => _confirmAndRemove(ctx),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (_photoPath != null) {
      final image = Image.file(
        File(_photoPath!),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
      );
      return widget.isCircle
          ? ClipOval(child: SizedBox(width: widget.size, height: widget.size, child: image))
          : ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: SizedBox(width: widget.size, height: widget.size, child: image),
            );
    }

    final decoration = widget.emptyDecoration ??
        BoxDecoration(
          color: AppColors.primary,
          shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: widget.isCircle ? null : BorderRadius.circular(widget.borderRadius),
        );

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: decoration,
      child: Center(
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                ),
              )
            : Text(
                widget.initial,
                style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPick = widget.userId.isNotEmpty;
    return GestureDetector(
      onTap: canPick ? _showImageSourceSheet : null,
      child: Stack(
        children: [
          _buildAvatar(),
          if (canPick)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: widget.badgeSize,
                height: widget.badgeSize,
                decoration: BoxDecoration(
                  color: context.colors.surfaceLighter,
                  border: Border.all(color: context.colors.border, width: 1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt,
                    size: widget.badgeIconSize,
                    color: context.colors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}
