class OnboardingItem {
  final String title;
  final String description;
  final String imagePath;
  final String tagLocation;
  final OnboardingVisualType visualType;

  const OnboardingItem({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.tagLocation,
    required this.visualType,
  });
}

enum OnboardingVisualType {
  destination,
  budgetPlanner,
  itineraryAndConcierge,
}
