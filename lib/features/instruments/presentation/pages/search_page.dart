import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pulse/core/l10n/generated/app_localizations.dart';
import 'package:pulse/core/presentation/error_message_resolver.dart';
import 'package:pulse/features/instruments/domain/entities/instrument.dart';
import 'package:pulse/features/instruments/presentation/bloc/search_bloc.dart';
import 'package:pulse/features/watchlist/presentation/cubit/watchlist_cubit.dart';
import 'package:pulse_design_system/pulse_design_system.dart';

/// Search instruments and add them to the watchlist (Should #7).
/// [searchBloc] and [resolver] are injected by the caller (composition root).
class SearchPage extends StatelessWidget {
  const SearchPage({
    required this.searchBloc,
    required this.resolver,
    super.key,
  });

  final SearchBloc searchBloc;
  final ErrorMessageResolver resolver;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocProvider<SearchBloc>.value(
      value: searchBloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.searchTitle),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                PulseSpacing.md,
                0,
                PulseSpacing.md,
                PulseSpacing.sm,
              ),
              child: TextField(
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => searchBloc.add(SearchQueryChanged(value)),
              ),
            ),
          ),
        ),
        body: BlocBuilder<SearchBloc, SearchState>(
          builder: (context, state) => switch (state.status) {
            SearchStatus.idle => PulseMessageView(
              icon: Icons.search,
              title: l10n.searchPrompt,
            ),
            SearchStatus.loading => PulseLoadingView(label: l10n.loadingLabel),
            SearchStatus.failure => PulseMessageView(
              icon: Icons.error_outline,
              title: resolver.resolve(state.error!, l10n),
              actionLabel: l10n.actionRetry,
              onAction: () => searchBloc.add(SearchQueryChanged(state.query)),
            ),
            SearchStatus.results when state.results.isEmpty => PulseMessageView(
              icon: Icons.search_off,
              title: l10n.searchNoResults,
            ),
            SearchStatus.results => _Results(results: state.results),
          },
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.results});

  final List<Instrument> results;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final symbols = context.select<WatchlistCubit, List<String>>(
      (cubit) => cubit.state.symbols,
    );
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final instrument = results[index];
        final added = symbols.contains(instrument.symbol);
        return ListTile(
          minVerticalPadding: PulseSpacing.sm,
          title: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(instrument.symbol),
            ),
          ),
          subtitle: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(instrument.name, textAlign: TextAlign.start),
          ),
          trailing: added
              ? Text(l10n.searchAlreadyAdded)
              : IconButton(
                  tooltip: l10n.actionAdd,
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () =>
                      context.read<WatchlistCubit>().add(instrument),
                ),
        );
      },
    );
  }
}
