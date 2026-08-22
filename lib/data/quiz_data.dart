import '../models/category.dart';
import '../models/question.dart';
import '../theme/colors.dart';

final List<Category> kCategories = [
  const Category(key: 'movies', name: 'Movies', emoji: '🎬', bg: AppColors.catMovies),
  const Category(key: 'music', name: 'Music', emoji: '🎵', bg: AppColors.catMusic),
  const Category(key: 'characters', name: 'Characters', emoji: '🎭', bg: AppColors.catCharacters),
  const Category(key: 'general', name: 'General Knowledge', emoji: '🌍', bg: AppColors.catGeneral),
  const Category(key: 'sounds', name: 'Funny Sounds', emoji: '😂', bg: AppColors.catSounds),
  const Category(key: 'tv', name: 'TV Shows', emoji: '📺', bg: AppColors.catTv),
  const Category(key: 'games', name: 'Games', emoji: '🎮', bg: AppColors.catGames),
  const Category(key: 'trivia', name: 'Trivia', emoji: '🧠', bg: AppColors.catTrivia),
];

final List<Question> kQuestions = [
  const Question(
    type: QuestionType.image,
    label: 'LOOK & GUESS 👀',
    prompt: 'Who is this character?',
    placeholder: 'character portrait',
    options: ['Elsa', 'Moana', 'Anna', 'Rapunzel'],
    correct: 0,
    timerSeconds: 15,
  ),
  const Question(
    type: QuestionType.audio,
    label: 'LISTEN & GUESS 🎧',
    prompt: 'Who is speaking?',
    duration: '0:12',
    options: ['Genie', 'Olaf', 'Sebastian', 'Timon'],
    correct: 1,
    timerSeconds: 12,
  ),
  const Question(
    type: QuestionType.video,
    label: 'WATCH & GUESS 🎬',
    prompt: 'Which movie is this from?',
    duration: '0:08',
    options: ['Frozen', 'Moana', 'Encanto', 'Tangled'],
    correct: 2,
    timerSeconds: 15,
  ),
  const Question(
    type: QuestionType.text,
    label: 'READ & ANSWER 🧠',
    prompt: 'Which movie features a talking snowman named Olaf?',
    options: ['Frozen', 'Moana', 'Brave', 'Coco'],
    correct: 0,
  ),
  const Question(
    type: QuestionType.emoji,
    label: 'DECODE & GUESS 🔤',
    prompt: 'Guess the movie',
    emojis: '❄️👸⛄🏰',
    options: ['Frozen', 'Tangled', 'Brave', 'Moana'],
    correct: 0,
  ),
  const Question(
    type: QuestionType.progressive,
    label: 'CLUE BY CLUE 🕵️',
    prompt: 'Guess the character',
    clues: [
      'Lives by the ocean',
      'Sails beyond the reef',
      'Daughter of the village chief',
      'Guided by the ocean itself',
    ],
    options: ['Moana', 'Ariel', 'Elsa', 'Pocahontas'],
    correct: 0,
  ),
];
