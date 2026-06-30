import SwiftUI
import SwiftData

struct ContentView: View {
    private enum DayNavigationDirection {
        case backward
        case forward
    }

    @State private var selectedDate = Date()
    @State private var dayNavigationDirection: DayNavigationDirection = .forward
    @State private var dayDragOffset: CGFloat = 0
    @State private var activeDaySwipeOffset: Int?
    @State private var isTrackingDaySwipe = false
    @State private var isCompletingDaySwipe = false
    @Environment(\.modelContext) private var modelContext

    private let swipeThreshold: CGFloat = 75
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    ZStack {
                        if let adjacentDate = adjacentDateForCurrentDrag {
                            DailyView(date: adjacentDate)
                                .id(Calendar.current.startOfDay(for: adjacentDate))
                                .offset(
                                    x: dayDragOffset + (dayDragOffset > 0
                                        ? -geometry.size.width
                                        : geometry.size.width)
                                )
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }

                        DailyView(
                            date: selectedDate,
                            dateSelection: $selectedDate,
                            onPreviousDay: { moveSelectedDate(by: -1) },
                            onNextDay: { moveSelectedDate(by: 1) },
                            onToday: { selectDate(Date()) },
                            onDaySwipeChanged: {
                                handleDaySwipeChanged(
                                    $0,
                                    containerWidth: geometry.size.width
                                )
                            },
                            onDaySwipeEnded: {
                                handleDaySwipeEnded(
                                    $0,
                                    containerWidth: geometry.size.width
                                )
                            }
                        )
                            .id(Calendar.current.startOfDay(for: selectedDate))
                            .offset(x: dayDragOffset)
                            .transition(dayTransition)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            .navigationTitle("Calories Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }

    private func handleDaySwipeChanged(
        _ value: DragGesture.Value,
        containerWidth: CGFloat
    ) {
        guard !isCompletingDaySwipe else { return }

        let horizontalDistance = value.translation.width
        let verticalDistance = value.translation.height

        if !isTrackingDaySwipe {
            guard abs(horizontalDistance) > abs(verticalDistance) * 1.5 else {
                return
            }
            activeDaySwipeOffset = horizontalDistance > 0 ? -1 : 1
            isTrackingDaySwipe = true
        }

        if activeDaySwipeOffset == -1 {
            dayDragOffset = min(max(horizontalDistance, 0), containerWidth)
        } else {
            dayDragOffset = max(min(horizontalDistance, 0), -containerWidth)
        }
    }

    private func handleDaySwipeEnded(
        _ value: DragGesture.Value,
        containerWidth: CGFloat
    ) {
        guard isTrackingDaySwipe,
              let dayOffset = activeDaySwipeOffset,
              !isCompletingDaySwipe else {
            isTrackingDaySwipe = false
            activeDaySwipeOffset = nil
            return
        }

        let verticalDistance = value.translation.height
        isTrackingDaySwipe = false
        activeDaySwipeOffset = nil

        guard abs(dayDragOffset) >= swipeThreshold,
              abs(dayDragOffset) > abs(verticalDistance) * 1.5 else {
            // A spring can overshoot zero and briefly reveal the page on the
            // opposite side. Ease back monotonically to keep the preview stable.
            withAnimation(.easeOut(duration: 0.2)) {
                dayDragOffset = 0
            }
            return
        }

        completeDaySwipe(
            by: dayOffset,
            containerWidth: containerWidth
        )
    }

    private var adjacentDateForCurrentDrag: Date? {
        guard dayDragOffset != 0 else { return nil }

        return Calendar.current.date(
            byAdding: .day,
            value: dayDragOffset < 0 ? 1 : -1,
            to: selectedDate
        )
    }

    private func completeDaySwipe(by dayOffset: Int, containerWidth: CGFloat) {
        guard let newDate = Calendar.current.date(
            byAdding: .day,
            value: dayOffset,
            to: selectedDate
        ) else {
            dayDragOffset = 0
            return
        }

        isCompletingDaySwipe = true
        dayNavigationDirection = dayOffset < 0 ? .backward : .forward

        withAnimation(.easeOut(duration: 0.22)) {
            dayDragOffset = dayOffset > 0 ? -containerWidth : containerWidth
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            var transaction = Transaction()
            transaction.disablesAnimations = true

            withTransaction(transaction) {
                selectedDate = newDate
                dayDragOffset = 0
                isCompletingDaySwipe = false
            }
        }
    }

    private func moveSelectedDate(by dayOffset: Int) {
        guard let newDate = Calendar.current.date(
            byAdding: .day,
            value: dayOffset,
            to: selectedDate
        ) else { return }

        dayNavigationDirection = dayOffset < 0 ? .backward : .forward

        withAnimation(.easeInOut(duration: 0.28)) {
            selectedDate = newDate
        }
    }

    private func selectDate(_ newDate: Date) {
        let comparison = Calendar.current.compare(
            newDate,
            to: selectedDate,
            toGranularity: .day
        )

        guard comparison != .orderedSame else { return }
        dayNavigationDirection = comparison == .orderedAscending ? .backward : .forward

        withAnimation(.easeInOut(duration: 0.28)) {
            selectedDate = newDate
        }
    }

    private var dayTransition: AnyTransition {
        let insertionEdge: Edge = dayNavigationDirection == .forward ? .trailing : .leading
        let removalEdge: Edge = dayNavigationDirection == .forward ? .leading : .trailing

        return .asymmetric(
            insertion: .move(edge: insertionEdge),
            removal: .move(edge: removalEdge)
        )
    }
}
