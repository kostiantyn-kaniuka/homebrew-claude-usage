import SwiftUI
import WidgetKit
import ServiceManagement

@main
struct ClaudeUsageApp: App {
    @StateObject private var model = UsageModel()

    var body: some Scene {
        MenuBarExtra {
            if let s = model.snapshot {
                ForEach(s.limits) { l in
                    Text("\(l.title): \(Int(l.effectivePercent(at: Date())))% · \(UsageFormat.resetText(l.resetsAt))")
                }
                Text("Updated \(UsageFormat.time(s.updatedAt))")
                if let e = s.error { Text("⚠︎ \(e)") }
                Divider()
            }
            Button("Refresh Now") { Task { await model.refresh() } }
                .keyboardShortcut("r")
            Toggle("Open at Login", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))
            Divider()
            Button("Quit Claude Usage") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Text(model.menuTitle)
        }
    }
}

@MainActor
final class UsageModel: ObservableObject {
    @Published var snapshot: UsageSnapshot? = UsageStore.load()
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    private var timer: Timer?

    init() {
        // Turn on "Open at Login" the first time so the widget keeps updating.
        if !UserDefaults.standard.bool(forKey: "didSetupLogin") {
            UserDefaults.standard.set(true, forKey: "didSetupLogin")
            setLaunchAtLogin(true)
        }
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    var menuTitle: String {
        guard let s = snapshot?.limits.first else { return "✱" }
        return "✱ \(Int(s.effectivePercent(at: Date())))%"
    }

    func refresh() async {
        let new: UsageSnapshot
        do {
            new = UsageSnapshot(updatedAt: Date(), limits: try await UsageFetcher.fetch(), error: nil)
        } catch {
            // Keep the last good numbers, just flag the problem.
            let msg = (error as? LocalizedError)?.errorDescription ?? "Offline"
            new = UsageSnapshot(updatedAt: snapshot?.updatedAt ?? Date(), limits: snapshot?.limits ?? [], error: msg)
        }
        snapshot = new
        try? UsageStore.save(new)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {}
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
