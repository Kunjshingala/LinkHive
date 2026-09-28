/// Domain exceptions for links and categories.
///
/// These live with the models rather than the repository on purpose: they
/// express rules about the domain, not about how or where it is stored. A
/// caller catching one is reacting to "this isn't allowed", not to "the
/// database said no", so the type should not move if persistence ever does.
library;

/// Thrown when adding a category whose name already exists.
///
/// Category names are the user's own labels and must stay unique, so the UI
/// can tell them apart. Callers are expected to catch this and show a
/// message rather than treat it as a failure.
class CategoryAlreadyExistsException implements Exception {
  const CategoryAlreadyExistsException();
}
