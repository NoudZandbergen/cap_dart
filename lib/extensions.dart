library;

import 'package:cap/cap.dart';

extension CapExt on String {
	List<CappedWord> get cases => CappedWord.from(this);
	List<CharCap> get charCaps => CharCap.fromText(this);
}