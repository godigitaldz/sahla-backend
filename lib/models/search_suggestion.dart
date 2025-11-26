/// 💡 Search Suggestion Model for Autocomplete
class SearchSuggestion {
  final String text;
  final SuggestionType type;
  final double score;
  final String? subtitle;
  final String? imageUrl;
  final Map<String, dynamic>? metadata;

  SearchSuggestion({
    required this.text,
    required this.type,
    required this.score,
    this.subtitle,
    this.imageUrl,
    this.metadata,
  });

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) {
    return SearchSuggestion(
      text: json['text'] ?? '',
      type: SuggestionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => SuggestionType.popular,
      ),
      score: json['score']?.toDouble() ?? 0.0,
      subtitle: json['subtitle'],
      imageUrl: json['image_url'],
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'type': type.toString().split('.').last,
      'score': score,
      'subtitle': subtitle,
      'image_url': imageUrl,
      'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchSuggestion &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          type == other.type;

  @override
  int get hashCode => text.hashCode ^ type.hashCode;
}

enum SuggestionType {
  popular,
  history,
  category,
  restaurant,
  menuItem,
}
