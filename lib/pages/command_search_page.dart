/// The command line, full screen.
///
/// SeekSparks used to have two searches: this app's own `SearchPage`
/// and the Workbench's command pane. They shared the search engine and
/// nothing else — different grammars, different result rows, AI in one
/// and Strong's booleans in the other — so which features a reader got
/// depended on how wide their window was. BibleWorks has exactly one
/// search surface (bwh09) and so does this now: [CommandPane] is the
/// search, and this page is simply the shape it takes when there is no
/// room to put it beside the text.
///
/// It owns its own [WorkbenchProvider] because that provider is scoped
/// to the Workbench page and is not registered globally. The results
/// therefore live as long as this route does, which is the right
/// lifetime for a search you opened from the reader and will close
/// again the moment you find the verse.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/providers/workbench_provider.dart';
import 'package:seeksparks/widgets/command_pane.dart';

class CommandSearchPage extends StatefulWidget {
  const CommandSearchPage({super.key});

  @override
  State<CommandSearchPage> createState() => _CommandSearchPageState();
}

class _CommandSearchPageState extends State<CommandSearchPage> {
  late final WorkbenchProvider _wb;
  final FocusNode _commandFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _wb = WorkbenchProvider(mainProvider: context.read<MainProvider>());
    // The reader asked for search; the caret goes in the box. Deferred
    // one frame because the route is still animating in and a focus
    // request during the push is dropped.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _commandFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _commandFocus.dispose();
    _wb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    return ChangeNotifierProvider<WorkbenchProvider>.value(
      value: _wb,
      child: Scaffold(
        appBar: AppBar(
          title: Text(uiStrings['search']?[locale] ?? 'Search'),
        ),
        body: SafeArea(
          child: CommandPane(
            focusNode: _commandFocus,
            // Tapping a hit prepares the jump on the shared
            // MainProvider and then gets out of the way — the reader
            // underneath is already scrolled to the verse.
            onVerseOpened: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
    );
  }
}
