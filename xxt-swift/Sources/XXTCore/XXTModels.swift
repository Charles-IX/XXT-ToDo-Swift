import Foundation

public struct Course: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let teacher: String
    public let url: String
    
    public init(id: String, name: String, teacher: String, url: String) {
        self.id = id
        self.name = name
        self.teacher = teacher
        self.url = url
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Course, rhs: Course) -> Bool {
        lhs.id == rhs.id
    }
}

public struct CourseFolder: Identifiable, Codable {
    public let id: String
    public let name: String
    public var courses: [Course]
    
    public init(id: String, name: String, courses: [Course] = []) {
        self.id = id
        self.name = name
        self.courses = courses
    }
}

public struct Homework: Identifiable, Codable {
    public let id: String
    public let name: String
    public let status: String
    public let courseName: String
    public let courseId: String
    public let deadline: String
    public let detailUrl: String?
    public let isPreciseDeadline: Bool // 新增：记录是否经过具体爬取（截止时间是否精确）
    
    public var deadlineDate: Date? {
        let formats = [
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy/MM/dd HH:mm",
            "yyyy年MM月dd日 HH:mm"
        ]
        let formatter = DateFormatter()
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: deadline) {
                return date
            }
        }
        return nil
    }
    
    public var isCompleted: Bool {
        let completedStatuses = ["已完成", "已批阅", "已提交", "待批阅", "已互评"]
        return completedStatuses.contains { status.contains($0) }
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.charles-ix.HomeworkToDo")
    }

    public static func saveHomework(_ homeworks: [Homework]) {
        if let encoded = try? JSONEncoder().encode(homeworks) {
            (sharedDefaults ?? UserDefaults.standard).set(encoded, forKey: "saved_homeworks")
        }
    }

    public static func loadHomework() -> [Homework] {
        if let data = (sharedDefaults ?? UserDefaults.standard).data(forKey: "saved_homeworks"),
           let decoded = try? JSONDecoder().decode([Homework].self, from: data) {
            return decoded
        }
        return []
    }
    
    public var isOverdue: Bool {
        guard !isCompleted, let date = deadlineDate else { return false }
        return date < Date()
    }
    
    public init(id: String, name: String, status: String, courseName: String, courseId: String, deadline: String, detailUrl: String? = nil, isPreciseDeadline: Bool = false) {
        self.id = id
        self.name = name
        self.status = status
        self.courseName = courseName
        self.courseId = courseId
        self.deadline = deadline
        self.detailUrl = detailUrl
        self.isPreciseDeadline = isPreciseDeadline
    }

    public func remainingTime(at date: Date = Date()) -> String {
        // 1. 如果已完成，不显示时间
        if isCompleted {
            return ""
        }
        
        // 2. 如果是标准的日期格式
        if let dDate = deadlineDate {
            let diff = dDate.timeIntervalSince(date)
            
            if diff <= 0 {
                // 已超期：正计时显示超期时长
                let overdueSeconds = abs(diff)
                let days = Int(overdueSeconds) / 86400
                let hours = (Int(overdueSeconds) % 86400) / 3600
                let minutes = (Int(overdueSeconds) % 3600) / 60
                
                if days > 0 {
                    return "已超期\(days)天\(hours)小时"
                } else if hours > 0 {
                    return "已超期\(hours)小时\(minutes)分钟"
                } else {
                    return "已超期\(minutes)分钟"
                }
            }
            
            let days = Int(diff) / 86400
            let hours = (Int(diff) % 86400) / 3600
            let minutes = (Int(diff) % 3600) / 60
            
            if days > 0 {
                return "剩余\(days)天\(hours)小时"
            } else if hours > 0 {
                return "剩余\(hours)小时\(minutes)分钟"
            } else {
                return "剩余\(minutes)分钟"
            }
        }
        
        // 3. 处理原生文本内容 (兜底逻辑)
        if deadline != "暂无截止时间" && deadline.contains("剩余") {
            // 解析类似 "剩余94小时4分钟" 或 "剩余3天5小时" 并重新格式化
            let raw = deadline
            let daysMatch = raw.range(of: #"(\d+)天"#, options: .regularExpression)
            let hoursMatch = raw.range(of: #"(\d+)小时"#, options: .regularExpression)
            let minutesMatch = raw.range(of: #"(\d+)分钟?"#, options: .regularExpression)
            
            var d: Int = 0
            var h: Int = 0
            var m: Int = 0
            
            if let range = daysMatch {
                d = Int(raw[range].replacingOccurrences(of: "天", with: "")) ?? 0
            }
            if let range = hoursMatch {
                h = Int(raw[range].replacingOccurrences(of: "小时", with: "")) ?? 0
            }
            if let range = minutesMatch {
                m = Int(raw[range].replacingOccurrences(of: "分", with: "").replacingOccurrences(of: "钟", with: "")) ?? 0
            }
            
            // 将总小时换算为天
            if h >= 24 {
                d += h / 24
                h = h % 24
            }
            
            if d > 0 {
                return "剩余\(d)天\(h)小时"
            } else if h > 0 {
                return "剩余\(h)小时\(m)分钟"
            } else if m > 0 {
                return "剩余\(m)分钟"
            }
            return raw
        }
        
        return ""
    }
}

public struct Exam: Identifiable, Codable {
    public let id: String
    public let name: String
    public let status: String
    public let courseName: String
    public let courseId: String
    public let deadline: String
    public let detailUrl: String?
    public let isPreciseDeadline: Bool

    public var deadlineDate: Date? {
        let formats = [
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy/MM/dd HH:mm",
            "yyyy年MM月dd日 HH:mm"
        ]
        let formatter = DateFormatter()
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: deadline) {
                return date
            }
        }
        return nil
    }

    public var isCompleted: Bool {
        let completedStatuses = ["已完成", "已批阅", "已提交", "待批阅", "已互评", "已结束", "查看卷子"]
        return completedStatuses.contains { status.contains($0) }
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.charles-ix.HomeworkToDo")
    }

    public static func saveExams(_ exams: [Exam]) {
        if let encoded = try? JSONEncoder().encode(exams) {
            (sharedDefaults ?? UserDefaults.standard).set(encoded, forKey: "saved_exams")
        }
    }

    public static func loadExams() -> [Exam] {
        if let data = (sharedDefaults ?? UserDefaults.standard).data(forKey: "saved_exams"),
           let decoded = try? JSONDecoder().decode([Exam].self, from: data) {
            return decoded
        }
        return []
    }

    public var isOverdue: Bool {
        guard !isCompleted, let date = deadlineDate else { return false }
        return date < Date()
    }

    public init(id: String, name: String, status: String, courseName: String, courseId: String, deadline: String, detailUrl: String? = nil, isPreciseDeadline: Bool = false) {
        self.id = id
        self.name = name
        self.status = status
        self.courseName = courseName
        self.courseId = courseId
        self.deadline = deadline
        self.detailUrl = detailUrl
        self.isPreciseDeadline = isPreciseDeadline
    }

    public func remainingTime(at date: Date = Date()) -> String {
        if isCompleted {
            return ""
        }
        
        if let dDate = deadlineDate {
            let diff = dDate.timeIntervalSince(date)
            
            if diff <= 0 {
                let overdueSeconds = abs(diff)
                let days = Int(overdueSeconds) / 86400
                let hours = (Int(overdueSeconds) % 86400) / 3600
                let minutes = (Int(overdueSeconds) % 3600) / 60
                
                if days > 0 {
                    return "已超期\(days)天\(hours)小时"
                } else if hours > 0 {
                    return "已超期\(hours)小时\(minutes)分钟"
                } else {
                    return "已超期\(minutes)分钟"
                }
            }
            
            let days = Int(diff) / 86400
            let hours = (Int(diff) % 86400) / 3600
            let minutes = (Int(diff) % 3600) / 60
            
            if days > 0 {
                return "剩余\(days)天\(hours)小时"
            } else if hours > 0 {
                return "剩余\(hours)小时\(minutes)分钟"
            } else {
                return "剩余\(minutes)分钟"
            }
        }
        
        if deadline != "暂无截止时间" && deadline.contains("剩余") {
            let raw = deadline
            let daysMatch = raw.range(of: #"(\d+)天"#, options: .regularExpression)
            let hoursMatch = raw.range(of: #"(\d+)小时"#, options: .regularExpression)
            let minutesMatch = raw.range(of: #"(\d+)分钟?"#, options: .regularExpression)
            
            var d: Int = 0
            var h: Int = 0
            var m: Int = 0
            
            if let range = daysMatch {
                d = Int(raw[range].replacingOccurrences(of: "天", with: "")) ?? 0
            }
            if let range = hoursMatch {
                h = Int(raw[range].replacingOccurrences(of: "小时", with: "")) ?? 0
            }
            if let range = minutesMatch {
                m = Int(raw[range].replacingOccurrences(of: "分", with: "").replacingOccurrences(of: "钟", with: "")) ?? 0
            }
            
            if h >= 24 {
                d += h / 24
                h = h % 24
            }
            
            if d > 0 {
                return "剩余\(d)天\(h)小时"
            } else if h > 0 {
                return "剩余\(h)小时\(m)分钟"
            } else if m > 0 {
                return "剩余\(m)分钟"
            }
            return raw
        }
        
        return ""
    }
}
