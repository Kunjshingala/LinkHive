import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/features/shell/bloc/shell_bloc.dart';
import 'package:link_hive/features/shell/bloc/shell_event.dart';
import 'package:link_hive/features/shell/bloc/shell_state.dart';

void main() {
  group('ShellBloc', () {
    test('initial state is ShellInitial', () {
      final bloc = ShellBloc();
      expect(bloc.state, const ShellInitial());
      bloc.close();
    });

    blocTest<ShellBloc, ShellState>(
      'emits [ShellBackPressedOnce] on first back press',
      build: ShellBloc.new,
      act: (bloc) => bloc.add(const ShellBackPressed()),
      expect: () => [isA<ShellBackPressedOnce>()],
    );

    blocTest<ShellBloc, ShellState>(
      'emits [ShellCanExit] on second back press within timeout',
      build: ShellBloc.new,
      seed: () => ShellBackPressedOnce(pressTime: DateTime.now()),
      act: (bloc) => bloc.add(const ShellBackPressed()),
      expect: () => [const ShellCanExit()],
    );

    blocTest<ShellBloc, ShellState>(
      'emits [ShellBackPressedOnce] again when timeout has expired',
      build: ShellBloc.new,
      seed: () => ShellBackPressedOnce(
        pressTime: DateTime.now().subtract(const Duration(seconds: 4)),
      ),
      act: (bloc) => bloc.add(const ShellBackPressed()),
      expect: () => [isA<ShellBackPressedOnce>()],
    );

    blocTest<ShellBloc, ShellState>(
      'double press sequence: first → once, second → exit',
      build: ShellBloc.new,
      act: (bloc) {
        bloc.add(const ShellBackPressed());
        bloc.add(const ShellBackPressed());
      },
      expect: () => [isA<ShellBackPressedOnce>(), const ShellCanExit()],
    );
  });
}
