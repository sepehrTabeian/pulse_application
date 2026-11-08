import 'package:pulse/features/instruments/domain/entities/instrument.dart';

/// The two groups the UI separates: stocks (incl. ETFs) and crypto.
enum AssetClass { stock, crypto }

/// Class of [symbol]. Without the instrument (e.g. a position that is not on
/// the watchlist) a `-` in the symbol (`BTC-USD`) marks a crypto pair.
AssetClass assetClassOf(String symbol, Instrument? instrument) {
  if (instrument != null) {
    return instrument.type == InstrumentType.crypto
        ? AssetClass.crypto
        : AssetClass.stock;
  }
  return symbol.contains('-') ? AssetClass.crypto : AssetClass.stock;
}
