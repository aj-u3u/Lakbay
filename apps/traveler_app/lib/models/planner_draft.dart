class PlannerDraft {
  final String destinationName;
  final int step; // 1 = duration, 2 = vibe, 3 = budget, 4 = generate
  final int days;
  final String vibe;
  final double budget;
  final String imageUrl;

  PlannerDraft({
    required this.destinationName,
    required this.step,
    this.days = 3,
    this.vibe = '',
    this.budget = 5000.0,
    required this.imageUrl,
  });

  String get progressText {
    switch (step) {
      case 1:
        return "Step 1 of 4: Select duration";
      case 2:
        return "Step 2 of 4: Select travel vibe";
      case 3:
        return "Step 3 of 4: Enter budget";
      case 4:
        return "Step 4 of 4: Ready to plan";
      default:
        return "";
    }
  }
}
