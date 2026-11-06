import 'package:flutter/widgets.dart';

String appText(BuildContext context, String english, String japanese) {
  return Localizations.localeOf(context).languageCode == 'ja'
      ? japanese
      : english;
}

String collectionStatusText(BuildContext context, String status) {
  if (Localizations.localeOf(context).languageCode != 'ja') return status;
  return switch (status.toLowerCase()) {
    'playing' => 'プレイ中',
    'finished' => 'プレイ済み',
    'stalled' => '中断中',
    'dropped' => '中止',
    'wishlist' => 'プレイ予定',
    'blacklist' => '除外',
    _ => status,
  };
}

String collectionVoteText(BuildContext context, int vote) {
  const japaneseVotes = <int, String>{
    10: '最高傑作',
    9: '非常に優れている',
    8: 'とても良い',
    7: '良い',
    6: 'まずまず',
    5: '普通',
    4: 'やや難あり',
    3: '悪い',
    2: 'とても悪い',
    1: '最低',
    0: '未評価',
    -1: '混在',
  };
  if (Localizations.localeOf(context).languageCode != 'ja') {
    return switch (vote) {
      -1 => 'Mixed',
      _ => '$vote  (${_englishVoteDescription[vote] ?? 'No Vote'})',
    };
  }
  return vote < 0 ? japaneseVotes[vote]! : '$vote（${japaneseVotes[vote]}）';
}

const _englishVoteDescription = <int, String>{
  10: 'Masterpiece',
  9: 'Excellent',
  8: 'Very good',
  7: 'Good',
  6: 'Decent',
  5: 'So-so',
  4: 'Weak',
  3: 'Bad',
  2: 'Awful',
  1: 'Worst ever',
  0: 'No Vote',
};
