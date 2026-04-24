import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/features/home/bloc/home_bloc.dart';
import 'package:link_hive/features/home/bloc/home_event.dart';
import 'package:link_hive/features/home/bloc/home_state.dart';

void main() {
  group('HomeBloc', () {
    test('initial state is HomeInitial', () {
      final bloc = HomeBloc();
      expect(bloc.state, const HomeInitial());
      bloc.close();
    });

    blocTest<HomeBloc, HomeState>(
      'emits [HomeBackPressedOnce] on first back press',
      build: HomeBloc.new,
      act: (bloc) => bloc.add(const HomeBackPressed()),
      expect: () => [isA<HomeBackPressedOnce>()],
    );

    blocTest<HomeBloc, HomeState>(
      'emits [HomeCanExit] on second back press within timeout',
      build: HomeBloc.new,
      seed: () => HomeBackPressedOnce(pressTime: DateTime.now()),
      act: (bloc) => bloc.add(const HomeBackPressed()),
      expect: () => [const HomeCanExit()],
    );

    blocTest<HomeBloc, HomeState>(
      'emits [HomeBackPressedOnce] again when timeout has expired',
      build: HomeBloc.new,
      seed: () => HomeBackPressedOnce(
        pressTime: DateTime.now().subtract(const Duration(seconds: 4)),
      ),
      act: (bloc) => bloc.add(const HomeBackPressed()),
      expect: () => [isA<HomeBackPressedOnce>()],
    );

    blocTest<HomeBloc, HomeState>(
      'double press sequence: first → once, second → exit',
      build: HomeBloc.new,
      act: (bloc) {
        bloc.add(const HomeBackPressed());
        bloc.add(const HomeBackPressed());
      },
      expect: () => [isA<HomeBackPressedOnce>(), const HomeCanExit()],
    );
  });
}
