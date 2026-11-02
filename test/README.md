# Test Data Boundary

Fixed passcodes, child names, amounts, dates, and `fixtures/backup-schema4.json` in this directory and `integration_test/` are synthetic test inputs. Fixture passwords verify a legacy authenticated-encryption format; they are not developer or real-family credentials.

Tests use in-memory/isolated file databases and separate Keychain namespaces. Never clear production `pennywood.sqlite` to make tests pass. The production app does not import test principal or credentials. Test descriptions/comments are English; Chinese UI assertions and business inputs intentionally exercise the app's supported language. See [validation](../docs/10-native-validation.md).
