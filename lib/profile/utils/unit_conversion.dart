/// Pure metric <-> imperial conversions for Profile height/weight.
/// [ProfileDetails.heightCm]/[weightKg] are always stored in metric — see
/// their doc comments — these helpers only ever affect display/input.
library;

double feetInchesToCm(double feet, double inches) =>
    ((feet * 12) + inches) * 2.54;

/// Splits a metric height into whole feet + remaining inches, for
/// pre-filling the imperial input fields from a stored metric value.
(int feet, double inches) cmToFeetAndInches(double cm) {
  final totalInches = cm / 2.54;
  final feet = totalInches ~/ 12;
  final inches = totalInches - (feet * 12);
  return (feet, inches);
}

double lbToKg(double lb) => lb * 0.45359237;

double kgToLb(double kg) => kg / 0.45359237;
