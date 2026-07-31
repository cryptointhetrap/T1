import SwiftUI

struct MealsView: View {
    @ObservedObject var viewModel: MealsViewModel
    @State private var selectedMeal: MealOption?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if let meals = viewModel.meals {
                        ForEach(MealSlot.allCases) { slot in
                            mealSection(slot: slot, options: meals[slot])
                        }
                    } else if viewModel.isLoading {
                        ProgressView("Cooking up today's picks…")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    }
                }
                .padding()
            }
            .navigationTitle("Meals")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.loadIfNeeded() }
            .sheet(item: $selectedMeal) { meal in
                MealDetailSheet(meal: meal)
            }
            .alert("Something went wrong", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func mealSection(slot: MealSlot, options: [MealOption]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(slot.rawValue)
                .font(.title2.bold())

            carbGroup(title: "Low-carb", options: options.filter { $0.carbLevel == .low })
            carbGroup(title: "High-carb", options: options.filter { $0.carbLevel == .high })
        }
    }

    @ViewBuilder
    private func carbGroup(title: String, options: [MealOption]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                ForEach(options) { option in
                    MealCard(
                        option: option,
                        rating: viewModel.ratingsStore.rating(for: option.name),
                        onTap: { selectedMeal = option },
                        onRate: { rating in viewModel.ratingsStore.toggle(option.name, rating) }
                    )
                }
            }
        }
    }
}

private struct MealCard: View {
    let option: MealOption
    let rating: MealRating?
    let onTap: () -> Void
    let onRate: (MealRating) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(option.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            HStack(spacing: 14) {
                Button { onRate(.up) } label: {
                    Image(systemName: rating == .up ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .foregroundStyle(rating == .up ? Color.ghGreen : Color.secondary)
                }
                .buttonStyle(.plain)

                Button { onRate(.down) } label: {
                    Image(systemName: rating == .down ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .foregroundStyle(rating == .down ? Color.red : Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct MealDetailSheet: View {
    let meal: MealOption
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(meal.name)
                        .font(.title2.bold())
                    Text(meal.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Link(destination: meal.recipeSearchURL) {
                    Label("How to make it", systemImage: "book.closed")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)

                Link(destination: meal.deliverySearchURL) {
                    Label("Order on a delivery app", systemImage: "bag")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.ghGreen)
                .foregroundStyle(.black)

                Spacer()
            }
            .padding()
            .navigationTitle("Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
