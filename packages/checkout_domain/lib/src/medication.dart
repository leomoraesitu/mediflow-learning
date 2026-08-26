/// A class representing a medication with its EAN, name, and unit price in cents.
final class Medication {
  final String ean;
  final String name;
  final int unitPriceInCents;

  const Medication({
    required this.ean,
    required this.name,
    required this.unitPriceInCents,
  });
}
