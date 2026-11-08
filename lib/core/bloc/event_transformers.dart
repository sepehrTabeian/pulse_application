import 'package:bloc/bloc.dart';
import 'package:rxdart/rxdart.dart';

/// Debounce + restartable (BLOC-03): waits for [duration] of silence, and a
/// newer event cancels the handler still running for an older one.
EventTransformer<E> debounceRestartable<E>(Duration duration) {
  return (events, mapper) => events.debounceTime(duration).switchMap(mapper);
}
