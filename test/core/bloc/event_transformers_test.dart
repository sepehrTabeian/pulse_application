import 'package:bloc/bloc.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/bloc/event_transformers.dart';

class _Query {
  const _Query(this.text);
  final String text;
}

class _DebouncedBloc extends Bloc<_Query, List<String>> {
  _DebouncedBloc(Duration debounce, {Duration work = Duration.zero})
    : super(const []) {
    on<_Query>((event, emit) async {
      if (work > Duration.zero) await Future<void>.delayed(work);
      emit([...state, event.text]);
    }, transformer: debounceRestartable<_Query>(debounce));
  }
}

void main() {
  const debounce = Duration(milliseconds: 300);

  test('only the last of rapid events is processed', () {
    fakeAsync((async) {
      final bloc = _DebouncedBloc(debounce);
      final states = <List<String>>[];
      bloc.stream.listen(states.add);

      bloc.add(const _Query('a'));
      async.elapse(const Duration(milliseconds: 100));
      bloc.add(const _Query('ab'));
      async.elapse(const Duration(milliseconds: 100));
      bloc.add(const _Query('abc'));
      async.elapse(const Duration(seconds: 1));

      expect(states, [
        ['abc'],
      ]);
      bloc.close();
    });
  });

  test('events spaced beyond the debounce are all processed', () {
    fakeAsync((async) {
      final bloc = _DebouncedBloc(debounce);
      final states = <List<String>>[];
      bloc.stream.listen(states.add);

      bloc.add(const _Query('a'));
      async.elapse(const Duration(milliseconds: 400));
      bloc.add(const _Query('b'));
      async.elapse(const Duration(milliseconds: 400));

      expect(states.last, ['a', 'b']);
      bloc.close();
    });
  });

  test('nothing is emitted before the debounce window ends', () {
    fakeAsync((async) {
      final bloc = _DebouncedBloc(debounce);
      final states = <List<String>>[];
      bloc.stream.listen(states.add);

      bloc.add(const _Query('a'));
      async.elapse(const Duration(milliseconds: 299));

      expect(states, isEmpty);
      bloc.close();
    });
  });

  test('a newer event cancels the in-flight handler (restartable)', () {
    fakeAsync((async) {
      final bloc = _DebouncedBloc(
        const Duration(milliseconds: 10),
        work: const Duration(milliseconds: 100),
      );
      final states = <List<String>>[];
      bloc.stream.listen(states.add);

      bloc.add(const _Query('old'));
      async.elapse(const Duration(milliseconds: 50));
      bloc.add(const _Query('new'));
      async.elapse(const Duration(seconds: 1));

      expect(states, [
        ['new'],
      ]);
      bloc.close();
    });
  });

  test('closing the bloc while a debounce is pending does not throw', () {
    fakeAsync((async) {
      final bloc = _DebouncedBloc(debounce);
      bloc.add(const _Query('a'));

      bloc.close();

      expect(() => async.elapse(const Duration(seconds: 1)), returnsNormally);
    });
  });
}
