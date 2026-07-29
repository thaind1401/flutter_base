/// The single value of a type that carries no information.
///
/// `Result<void>` cannot hold a value, so operations that succeed without
/// producing data return `Result<Unit>` and callers write `const Ok(unit)`.
final class Unit {
  const Unit._();

  @override
  String toString() => '()';
}

const Unit unit = Unit._();
