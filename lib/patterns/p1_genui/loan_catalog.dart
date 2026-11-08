import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'loan_offer_card.dart';

// ─── Slide 7: "Under the hood: a GenUI catalog item" ────────────────────────

/// 01  Describe your existing widget with a JSON schema.
final loanOffer = CatalogItem(
  name: 'LoanOfferCard',
  dataSchema: S.object(
    description: 'A loan offer for a small business. Pair it with a Slider '
        'bound to the same tenurePath so the user can change the tenure.',
    properties: {
      'amount': S.number(description: 'Loan principal in Naira.'),
      'monthlyRate': S.number(
        description: 'Monthly interest rate as a decimal, e.g. 0.04 for 4%.',
      ),
      'tenurePath': S.string(
        description: 'Data-model path where the Slider writes the tenure in '
            'months, e.g. "/loan/months".',
      ),
      'purpose': S.string(description: 'Short purpose, e.g. "Shop restock".'),
    },
    required: ['amount', 'monthlyRate', 'tenurePath'],
  ),
  // 02  BoundNumber ties tenure to the data model, so the built-in Slider
  //     drives your card.
  widgetBuilder: (item) {
    final data = item.data as JsonMap;
    return BoundNumber(
      dataContext: item.dataContext,
      value: {'path': data['tenurePath']},
      builder: (context, months) => LoanOfferCard(
        amount: data['amount'] as num,
        monthlyRate: data['monthlyRate'] as num,
        months: (months ?? 3).round(),
        purpose: data['purpose'] as String?,
      ),
    );
  },
);

/// 03  Add it to the basic catalog: Slider, Button, Text and more.
final catalog = BasicCatalogItems.asCatalog().copyWith(newItems: [loanOffer]);
