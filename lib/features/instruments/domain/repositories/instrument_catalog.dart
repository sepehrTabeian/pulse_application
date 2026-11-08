import 'package:pulse/features/instruments/domain/entities/instrument.dart';

/// Reads the instrument universe. Throws `AppException` subtypes.
abstract interface class InstrumentCatalog {
  Future<List<Instrument>> getInstruments();
}
