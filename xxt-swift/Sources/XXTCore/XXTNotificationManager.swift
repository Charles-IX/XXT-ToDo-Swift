import Foundation
import UserNotifications
import XXTCore

public final class NotificationManager {
    public static let shared = NotificationManager()
    
    private init() {}
    
    /// 请求通知权限
    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ [NotificationManager] Auth error: \(error)")
            }
        }
    }
    
    /// 根据作业和考试列表及用户设置的阈值安排通知
    /// - Parameters:
    ///   - homeworks: 作业列表
    ///   - exams: 考试列表
    ///   - thresholdsInMinutes: 预警阈值（分钟），例如 [60, 1440] 表示 1 小时和 24 小时
    public func scheduleNotifications(for homeworks: [Homework], exams: [Exam] = [], thresholdsInMinutes: [Int]) {
        // 先移除所有待处理的通知，避免重复
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let unfinishedHw = homeworks.filter { !$0.isCompleted && !$0.isOverdue }
        let unfinishedExams = exams.filter { !$0.isCompleted && !$0.isOverdue }
        
        for hw in unfinishedHw {
            guard let deadlineDate = hw.deadlineDate else { continue }
            
            for folderMinutes in thresholdsInMinutes {
                let triggerDate = deadlineDate.addingTimeInterval(TimeInterval(-folderMinutes * 60))
                
                // 如果触发时间已经在过去，则跳过
                if triggerDate < Date() { continue }
                
                let content = UNMutableNotificationContent()
                content.title = "作业截止提醒"
                let timeStr = formatMinutes(folderMinutes)
                content.body = "课程：\(hw.courseName)\n作业：\(hw.name)\n离截止时间还有约 \(timeStr)。"
                content.sound = .default
                
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                
                let identifier = "hw_\(hw.id)_\(folderMinutes)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("❌ [NotificationManager] Error scheduling homework notification: \(error)")
                    }
                }
            }
        }
        
        for exam in unfinishedExams {
            guard let deadlineDate = exam.deadlineDate else { continue }
            
            for folderMinutes in thresholdsInMinutes {
                let triggerDate = deadlineDate.addingTimeInterval(TimeInterval(-folderMinutes * 60))
                
                if triggerDate < Date() { continue }
                
                let content = UNMutableNotificationContent()
                content.title = "考试截止提醒"
                let timeStr = formatMinutes(folderMinutes)
                content.body = "课程：\(exam.courseName)\n考试：\(exam.name)\n离截止时间还有约 \(timeStr)。"
                content.sound = .default
                
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                
                let identifier = "exam_\(exam.id)_\(folderMinutes)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("❌ [NotificationManager] Error scheduling exam notification: \(error)")
                    }
                }
            }
        }
        
        print("✅ [NotificationManager] Scheduled notifications for \(unfinishedHw.count) homework(s) and \(unfinishedExams.count) exam(s) with \(thresholdsInMinutes.count) thresholds.")
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 1440 {
            let days = minutes / 1440
            let hours = (minutes % 1440) / 60
            return hours > 0 ? "\(days)天\(hours)小时" : "\(days)天"
        } else if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)小时\(mins)分钟" : "\(hours)小时"
        } else {
            return "\(minutes)分钟"
        }
    }
}
