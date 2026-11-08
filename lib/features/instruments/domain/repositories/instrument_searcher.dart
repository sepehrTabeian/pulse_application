import 'package:pulse/features/instruments/domain/entities/instrument.dart';

/// Searches instruments by free text (max 10 results). A blank query returns
/// an empty list. Throws `AppException` subtypes.
abstract interface class InstrumentSearcher {
  Future<List<Instrument>> search(String query);
}
