/// Ask the reader for a file and read it as text — bwh47's only input.
///
/// Deliberately narrow: it returns the CONTENT and the file's name, and
/// nothing else. No path, no handle, no upload — the file is read in the
/// browser and the string is handed to the validator. There is nothing
/// here a network could be attached to.
///
/// Split by the same conditional-export pattern `fetch_helper.dart`
/// uses; native returns null, because the import surface is web-only.
library;

export 'pick_text_file_io.dart'
    if (dart.library.js_interop) 'pick_text_file_web.dart';
