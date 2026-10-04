/// The exact information the user confirms before story generation.
class StoryDetails {
  final String place, characters, emotions, life, memo;
  const StoryDetails(
      {this.place = '',
      this.characters = '',
      this.emotions = '',
      this.life = '',
      this.memo = ''});
  bool get isEmpty =>
      [place, characters, emotions, life, memo].every((s) => s.trim().isEmpty);
  String get summary => {
        '장소': place,
        '등장인물': characters,
        '감정': emotions,
        '생활': life,
        '기타 메모': memo
      }
          .entries
          .map((e) =>
              '${e.key}: ${e.value.trim().isEmpty ? '입력 없음' : e.value.trim()}')
          .join('\n');
  String get confirmation =>
      '정보가 맞아요. 아래 정보는 제가 최종 확인한 내용입니다. 이전 대화와 다른 부분은 이 내용을 우선해 주세요. 입력하지 않은 사실은 지어내지 말고, 이 정보와 제가 들려준 이야기를 바탕으로 하나의 자연스러운 이야기를 구성해 주세요.\n\n$summary';
  String get previewStory => [
        if (place.trim().isNotEmpty) '이야기의 배경은 ${place.trim()}였다.',
        if (characters.trim().isNotEmpty) '그 이야기에는 ${characters.trim()}가 등장했다.',
        if (emotions.trim().isNotEmpty) '그때 느낀 감정은 ${emotions.trim()}이었다.',
        if (life.trim().isNotEmpty) '생활 속에서는 이런 일이 떠올랐다. ${life.trim()}',
        if (memo.trim().isNotEmpty) '함께 기억해 두고 싶은 내용도 있다. ${memo.trim()}',
      ].join('\n\n');
}
