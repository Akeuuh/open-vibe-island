import SwiftUI

struct ContentView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager

    var body: some View {
        NavigationStack {
            Group {
                if sessionManager.pendingEvents.isEmpty {
                    emptyState
                } else {
                    eventList
                }
            }
            .navigationTitle("Open Island")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundStyle(.blue)

            Text("一切就绪")
                .font(.headline)

            Text(sessionManager.isPhoneReachable ? "iPhone 已连接" : "iPhone 未连接")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var eventList: some View {
        List(sessionManager.pendingEvents.sorted(by: { $0.receivedAt > $1.receivedAt })) { event in
            EventCardView(event: event)
        }
    }
}
