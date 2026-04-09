//
//  HomeworkToDoApp.swift
//  HomeworkToDo
//
//  Created by Charles on 2026/3/11.
//

import SwiftUI
import WidgetKit
import XXTCore
#if os(iOS)
import BackgroundTasks
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

@main
struct HomeworkToDoApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @State private var forceShowWindow = false
    @State private var isBackgroundLaunched: Bool = {
        CommandLine.arguments.contains("--background")
    }()

    static let bgTaskIdentifier = "charles-ix.HomeworkToDo.refresh"

    init() {
        #if os(iOS)
        registerBackgroundTask()
        #endif
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                #if os(macOS)
                .frame(minWidth: 320, idealWidth: 340, maxWidth: 450, minHeight: 600, maxHeight: 1200)
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowMainWindow"))) { _ in
                    forceShowWindow = true
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    
                    // Show all app windows
                    for window in NSApp.windows {
                        window.makeKeyAndOrderFront(nil)
                        window.setIsVisible(true)
                    }
                }
                #endif
                #if os(iOS)
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.didEnterBackgroundNotification)
                ) { _ in
                    HomeworkToDoApp.scheduleBackgroundRefresh()
                }
                #endif
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }

    // MARK: - iOS 后台任务

    #if os(iOS)
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: HomeworkToDoApp.bgTaskIdentifier,
            using: nil
        ) { task in
            HomeworkToDoApp.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }

    /// 调度下一次后台刷新。可从 App 外部调用（例如 ContentView 保存设置后）。
    static func scheduleBackgroundRefresh() {
        let stored = UserDefaults.standard.double(forKey: "refresh_interval")
        let intervalSeconds = max(stored > 0 ? stored : 30, 10) * 60

        let request = BGAppRefreshTaskRequest(identifier: bgTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: intervalSeconds)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("⚠️ [BGTask] Failed to schedule background refresh: \(error)")
        }
    }

    private static func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // 立即调度下一轮，保持循环
        scheduleBackgroundRefresh()

        let phone    = UserDefaults.standard.string(forKey: "phone") ?? ""
        let password = UserDefaults.standard.string(forKey: "password") ?? ""

        guard !phone.isEmpty, !password.isEmpty else {
            task.setTaskCompleted(success: false)
            return
        }

        let fetchTask = Task {
            do {
                let service = XXTService()
                let success = try await service.login(phone: phone, pass: password)
                guard success else {
                    task.setTaskCompleted(success: false)
                    return
                }
                let homeworks = try await service.fetchAllHomework()
                Homework.saveHomework(homeworks)
                WidgetCenter.shared.reloadAllTimelines()
                task.setTaskCompleted(success: true)
                print("✅ [BGTask] Background refresh completed, \(homeworks.count) homeworks saved.")
            } catch {
                print("❌ [BGTask] Background refresh failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }

        // 系统在超时前取消任务
        task.expirationHandler = {
            fetchTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
    #endif
}

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--background") {
            // Hide windows immediately after finish launching
            DispatchQueue.main.async {
                NSApp.hide(nil)
                for window in NSApp.windows {
                    window.orderOut(nil)
                }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Restore visibility when user clicks Dock icon
            NotificationCenter.default.post(name: NSNotification.Name("ShowMainWindow"), object: nil)
        }
        return true
    }
}
#endif
