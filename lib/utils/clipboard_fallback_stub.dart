/// Non-web stub for the legacy clipboard fallback. On iOS / Android /
/// macOS the platform `Clipboard.setData` channel is reliable, so
/// there is nothing sensible to fall back to — report failure and let
/// the caller show its failure feedback.
bool legacyClipboardCopy(String text) => false;

/// Non-web stub for the rich (`text/html`) clipboard write. There is no
/// portable way to put formatted text on the pasteboard through
/// Flutter's clipboard channel, so this reports failure and the caller
/// falls back to the plain-text copy — with an honest message, because
/// what the reader loses is the indentation and the underlining, which
/// is most of what the export is FOR.
bool richClipboardCopy(String html, String text) => false;
