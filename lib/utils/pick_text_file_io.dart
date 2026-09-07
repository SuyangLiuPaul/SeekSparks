/// Native half of the file picker — see `pick_text_file.dart`.
library;

/// A file the reader chose: its name and its contents.
typedef PickedTextFile = ({String name, String text});

Future<PickedTextFile?> pickTextFile() async => null;

bool get canPickTextFile => false;
