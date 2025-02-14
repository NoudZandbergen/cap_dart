import 'dart:collection';
import 'dart:math';

import 'package:cap/extensions.dart';

enum CharCap {
	// The character is UPPER CASE
	upper,
	// The character is lower case
	lower,
	// The character is not upper or lower case
	none;

	static CharCap fromRune(int rune) => switch (rune) {
		>= 65 && < 91 => upper,
		>= 97 && < 123 => lower,
		_ => none
	};

	static CharCap fromChar(String char) => fromRune(char.runes.first);
	static List<CharCap> fromText(String text) => text.runes.map(fromRune).toList();

	WordCap get wordCase => switch (this) {
		upper => WordCap.upper,
		lower => WordCap.lower,
		none => WordCap.none,
	};
}

/// The types of capitalization that can be determined from an input string
enum WordCap {
	/// The segment is in UPPER CASE
	upper,
	/// The segment is in lower case
	lower,
	/// The segment is in Title Case. Also applies if more than one letter is capitalized at the beginning, as could be the case with acronyms. Though, those would ideally be split as different words.
	title, // TODO: Consider creating a separate case for acronyms
	/// The segment contains both upper case and lower case characters in indeterminate order
	mixed,
	/// The segment contains neither upper case nor lower case characters
	none;

	static WordCap fromWord(String word) {
		var wordCap = WordCap.none;
		// none -> none | upper | lower
		// upper -> upper | title
		// title -> title | mixed
		// lower -> lower | mixed
		// mixed -> mixed

		for (var rune in word.runes) {
			wordCap = switch ((wordCap, CharCap.fromRune(rune))) {
				(none, var charCap) => charCap.wordCase, // none -> none | upper | lower
				(upper, CharCap.lower) => title, // upper -> title
				(title || lower, CharCap.upper) => mixed, // title | lower -> mixed
				(_, _) => wordCap, // x -> x
			};
		}
		return wordCap;
	}

	WordCapOp? get op => switch (this) {
		upper => WordCapOp.upper,
		lower => WordCapOp.lower,
		title => WordCapOp.title,
		_ => null,
	};
}

/// The types of capitalization operations that can be applied to text
enum WordCapOp {
	upper, lower, title, random, flip, preserve;
	
	static final _random = Random();

	WordCap? readsAs([WordCap? current]) => switch ((this, current)) {
		(upper, _) => WordCap.upper,
		(lower, _) => WordCap.lower,
		(title, _) => WordCap.title,
		(random, _) => WordCap.mixed,
		(flip, WordCap.upper) => WordCap.lower,
		(flip, WordCap.lower) => WordCap.upper,
		(flip, WordCap.mixed || WordCap.title) => WordCap.mixed,
		(preserve, _) => current,
		(_, WordCap.none) => WordCap.none,
		(_, _) => null
	};

	String apply(String input) => switch (this) {
		upper => input.toUpperCase(),
		lower => input.toLowerCase(),
		title => input[0].toUpperCase() + input.substring(1).toLowerCase(),
		random => input.split('').map((e) => _random.nextBool() ? e.toUpperCase() : e.toLowerCase()).join(),
		flip => String.fromCharCodes(input.runes.map((rune) => CharCap.fromRune(rune) != CharCap.none ? rune ^ 32 : rune)),
		preserve => input,
	};
}

const upperSplitter = '(?=[A-Z])';
const lowerSplitter = '(?=[a-z])';
final defaultSplitter = RegExp('[ _\\\\/-]');
final defaultWithUpperSplitter = RegExp('[ _\\\\/-]|$upperSplitter');

class CappedWord {
	final String? prefix;
	final String text;
	final WordCap wordCase;

	CappedWord(this.text, this.wordCase, {this.prefix});

	@override
  	String toString() => '${prefix??''}$text';

	static List<CappedWord> from(String input, [Pattern? splitter]) {
		splitter ??= defaultSplitter;

		final splits = Queue<Match>()..addAll(splitter.allMatches(input));
		final runes = input.runes.toList();
		final results = <CappedWord>[];

		var wordCase = WordCap.none;
		String? prefix;
		int i = 0, start = 0;

		void split([int? splitStart, int? splitEnd]) {
			splitStart ??= i;
			splitEnd ??= splitStart;

			bool segmentIsEmpty = start >= splitStart;
			bool splitIsEmpty = splitStart >= splitEnd;

			// Only create splits if the resulting segments are not empty.
			if (!segmentIsEmpty) {
				results.add(CappedWord(input.substring(start, splitStart), wordCase, prefix: prefix));
				// Only reset prefix if an actual segment was created.
				if (splitIsEmpty) {
				  prefix = null;
				} else {
					prefix = input.substring(splitStart, splitEnd);
					i = splitEnd;
				}
			}
			start = splitEnd;
		}

		while (i < runes.length) {
			final rune = runes[i];
			
			switch ((wordCase, CharCap.fromRune(rune))) {
				case (WordCap.none, var charCase):    wordCase = charCase.wordCase;
				case (WordCap.upper, CharCap.lower):
					split(i-1);
					wordCase = WordCap.title;
				case (WordCap.title || WordCap.lower, CharCap.upper):
					split();
					wordCase = WordCap.none;
				default:
			}
			
			if (splits.isNotEmpty && i >= splits.first.start) {
				var splitter = splits.removeFirst();
				split(splitter.start, splitter.end);
			} else {
			  i += 1;
			}
		}
		split();

		return results;
	}

	// static List<(String, String?)> from(String input, [Pattern? separator]) {
	// 	separator ??= defaultSeparatorPattern;

	// 	// This is basically the code of the default string.split function, with some modifications

	// 	final segments = <(String, String?)>[];
	// 	Match? prev;

	// 	// Lil helpers
	// 	int len(Match? match) => match == null ? 1 : match.end - match.start;
	// 	void seg([int? end]) => segments.add((input.substring(prev?.end ?? 0, end), prev?.group(0)));

  //   for (var match in separator.allMatches(input)) {
  //     if (len(prev) == 0 && (prev?.end ?? 0) == match.start) continue;
	// 		seg(match.end);
	// 		prev = match;
  //   }
  //   if ((prev?.end ?? 0) < input.length || len(prev) > 0) {
	// 		seg();
  //   }
	// 	return segments;
	// }
}

extension Words on List<CappedWord> {
	Iterable<String> get cap => map((e) => e.text);

	String get upper    => TextCap.upper    .apply(cap);
	String get lower    => TextCap.lower    .apply(cap);
	String get title    => TextCap.title    .apply(cap);
	String get pascal   => TextCap.pascal   .apply(cap);
	String get camel    => TextCap.camel    .apply(cap);
	String get scream   => TextCap.scream   .apply(cap);
	String get snake    => TextCap.snake    .apply(cap);
	String get train    => TextCap.train    .apply(cap);
	String get kebab    => TextCap.kebab    .apply(cap);
	String get path     => TextCap.path     .apply(cap);
	String get winPath  => TextCap.winPath  .apply(cap);
	String get sentence => TextCap.sentence .apply(cap);
}

class TextCap {
	static const upper    = TextCap(WordCapOp.upper                                           );
	static const lower    = TextCap(WordCapOp.lower                                           );
	static const pascal   = TextCap(WordCapOp.title                                           );
	static const title    = TextCap(WordCapOp.title, separator: ' '                           );
	static const camel    = TextCap(WordCapOp.title, firstCap: WordCapOp.lower                );
	static const scream   = TextCap(WordCapOp.upper, separator: '_'                           );
	static const snake    = TextCap(WordCapOp.lower, separator: '_'                           );
	static const train    = TextCap(WordCapOp.upper, separator: '-'                           );
	static const kebab    = TextCap(WordCapOp.lower, separator: '-'                           );
	static const path     = TextCap(WordCapOp.lower, separator: '/'                           );
	static const winPath  = TextCap(WordCapOp.lower, separator: '\\'                          );
	static const sentence = TextCap(WordCapOp.lower, firstCap: WordCapOp.title, separator: ' ');

	static const values = [
		upper,
		lower,
		pascal,
		title,
		camel,
		scream,
		snake,
		train,
		kebab,
		path,
		winPath,
		sentence,
	];

	/// After a lossy text case conversion, you can no longer split the text and convert it to cases other than just uppercase and lowercase
	bool get isLossy => cap != WordCapOp.title && separator.isEmpty;

	final WordCapOp cap;
	final WordCapOp firstCap;
	final String separator;

	const TextCap(this.cap, {
		this.separator = '',
		WordCapOp? firstCap
	}) : firstCap = firstCap ?? cap;

	String apply(Iterable<String> segments) {
		if (segments.isEmpty) return '';
		return [
			firstCap.apply(segments.first),
			...segments.skip(1).map((e) => cap.apply(e)),
		].join(separator);
	}
}

void main(List<String> args) {
  // var cases = CappedWord.from('Just_D8MOSomeD8MOSample-text');
	var cases = 'SomeIPAddress_with-Other/SEPARATORS'.cases;
	print(cases.upper);   
  print(cases.lower);   
  print(cases.pascal);  
  print(cases.camel);   
  print(cases.scream);  
  print(cases.snake);   
  print(cases.train);   
  print(cases.kebab);   
  print(cases.path);    
  print(cases.winPath); 
  print(cases.sentence);
}