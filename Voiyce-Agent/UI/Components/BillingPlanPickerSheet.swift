import SwiftUI

struct BillingPlanPickerSheet: View {
    @Environment(BillingManager.self) private var billingManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: BillingPlan?
    let onDismiss: (() -> Void)?

    init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
    }

    private var activePlan: BillingPlan {
        selectedPlan ?? billingManager.checkoutDefaultPlan
    }

    private var savedPlan: BillingPlan? {
        billingManager.preferredPlan
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose Your Pro Plan")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Your trial includes up to \(AppConstants.freeWordLimit) words over \(AppConstants.trialLengthDays) days with no credit card required. Upgrade anytime to keep dictating without limits.")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let savedPlan {
                    Text("Using your \(savedPlan.title.lowercased()) selection from the website.")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.accent)
                }
            }

            VStack(spacing: 12) {
                ForEach(BillingPlan.allCases) { plan in
                    Button {
                        selectedPlan = plan
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: activePlan == plan ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(activePlan == plan ? AppTheme.accent : AppTheme.textSecondary)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(plan.title)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)

                                    if savedPlan == plan {
                                        Text("Saved")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(AppTheme.accent)
                                            .clipShape(RoundedRectangle(cornerRadius: 999))
                                    }

                                    if let badge = plan.badge {
                                        Text(badge)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(AppTheme.accent)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(AppTheme.accent.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 999))
                                    }
                                }

                                Text(plan.subtitle)
                                    .font(AppTheme.captionFont)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 12)

                            VStack(alignment: .trailing, spacing: 8) {
                                Text(plan.priceDisplay)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(AppTheme.textPrimary)

                                Text(activePlan == plan ? "Selected" : "Select")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(activePlan == plan ? .white : AppTheme.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(activePlan == plan ? AppTheme.accent : AppTheme.accent.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.backgroundSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(activePlan == plan ? AppTheme.accent : AppTheme.ridge, lineWidth: activePlan == plan ? 2 : 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(billingManager.isOpeningCheckout)
                }
            }

            Button {
                Task {
                    await billingManager.beginCheckout(plan: activePlan)
                    close()
                }
            } label: {
                HStack {
                    if billingManager.isOpeningCheckout {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }

                    Text("Continue with \(activePlan.title)")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(billingManager.isOpeningCheckout)

            Text("Monthly renews at \(AppConstants.proMonthlyPriceDisplay). Yearly renews at \(AppConstants.proYearlyPriceDisplay).")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(24)
        .frame(width: 460)
        .background(GroovedBackground(base: AppTheme.backgroundPrimary))
    }

    private func close() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
}

private struct BillingPlanPickerOverlay: View {
    @Environment(BillingManager.self) private var billingManager
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissIfIdle()
                }

            BillingPlanPickerSheet {
                isPresented = false
            }
            .contentShape(RoundedRectangle(cornerRadius: 24))
            .onTapGesture {
                // Swallow taps inside the card so only outside clicks dismiss it.
            }
            .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
        .onExitCommand {
            dismissIfIdle()
        }
    }

    private func dismissIfIdle() {
        guard !billingManager.isOpeningCheckout else { return }
        isPresented = false
    }
}

private struct BillingPlanPickerPresentationModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    BillingPlanPickerOverlay(isPresented: $isPresented)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: isPresented)
    }
}

extension View {
    func billingPlanPicker(isPresented: Binding<Bool>) -> some View {
        modifier(BillingPlanPickerPresentationModifier(isPresented: isPresented))
    }
}
