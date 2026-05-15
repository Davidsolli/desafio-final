/// Centraliza o mapeamento de IDs de grupos musculares para nomes amigáveis e emojis.
class MuscleGroupHelper {
  static const Map<String, String> _labels = {
    'peito': 'Peito',
    'costa': 'Costas',
    'costas': 'Costas',
    'ombro': 'Ombros',
    'bíceps': 'Bíceps',
    'biceps': 'Bíceps',
    'tríceps': 'Tríceps',
    'triceps': 'Tríceps',
    'antebraço': 'Antebraço',
    'antebraco': 'Antebraço',
    'core': 'Abdominal/Core',
    'perna_anterior': 'Quadríceps',
    'perna_posterior': 'Posterior de Coxa',
    'panturrilha': 'Panturrilha',
    'abdômen': 'Abdômen',
    'abdomen': 'Abdômen',
  };

  static const Map<String, String> _emojis = {
    'peito': '💪',
    'costa': '🔙',
    'costas': '🔙',
    'ombro': '🏋️',
    'bíceps': '💪',
    'biceps': '💪',
    'tríceps': '💪',
    'triceps': '💪',
    'antebraço': '🦾',
    'antebraco': '🦾',
    'core': '🎯',
    'perna_anterior': '🦵',
    'perna_posterior': '🦵',
    'panturrilha': '🦶',
    'abdômen': '🎯',
    'abdomen': '🎯',
  };

  /// Retorna o nome amigável do grupo muscular.
  static String getName(String id) {
    return _labels[id.toLowerCase()] ?? id;
  }

  /// Retorna o emoji associado ao grupo muscular.
  static String getEmoji(String id) {
    return _emojis[id.toLowerCase()] ?? '🏃';
  }

  /// Retorna uma string formatada "Emoji Nome".
  static String getLabelWithEmoji(String id) {
    return '${getEmoji(id)} ${getName(id)}';
  }
}
