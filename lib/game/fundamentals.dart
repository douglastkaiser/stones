/// A fixed learning contract. New variant lessons must not move this goal.
const squareFundamentals = [
  'tutorial_1',
  'tutorial_2',
  'tutorial_3',
  'tutorial_4',
  'tutorial_5',
  'tutorial_6',
  'tutorial_7',
  'tutorial_8',
  'tutorial_9',
];

String? nextFundamental(Set<String> completed) =>
    squareFundamentals.where((id) => !completed.contains(id)).firstOrNull;
