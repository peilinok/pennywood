// The retired town finance journey now shares the production journal flow.
// Its real-family isolation assertions remain enabled in the common scenario.
import 'wishboard_finance_test.dart' as journal;

void main() => journal.main(verifyRealIsolation: true);
