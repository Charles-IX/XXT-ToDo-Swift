import SwiftUI
import WidgetKit
import XXTCore

// MARK: - Generic Task Item for Widget
enum WidgetTaskItem: Identifiable {
    case homework(Homework)
    case exam(Exam)
    
    var id: String {
        switch self {
        case .homework(let hw): return "hw_\(hw.id)"
        case .exam(let ex): return "exam_\(ex.id)"
        }
    }
    
    var name: String {
        switch self {
        case .homework(let hw): return hw.name
        case .exam(let ex): return ex.name
        }
    }
    
    var courseName: String {
        switch self {
        case .homework(let hw): return hw.courseName
        case .exam(let ex): return ex.courseName
        }
    }
    
    var status: String {
        switch self {
        case .homework(let hw): return hw.status
        case .exam(let ex): return ex.status
        }
    }
    
    var deadline: String {
        switch self {
        case .homework(let hw): return hw.deadline
        case .exam(let ex): return ex.deadline
        }
    }
    
    var deadlineDate: Date? {
        switch self {
        case .homework(let hw): return hw.deadlineDate
        case .exam(let ex): return ex.deadlineDate
        }
    }
    
    var isCompleted: Bool {
        switch self {
        case .homework(let hw): return hw.isCompleted
        case .exam(let ex): return ex.isCompleted
        }
    }
    
    var isOverdue: Bool {
        switch self {
        case .homework(let hw): return hw.isOverdue
        case .exam(let ex): return ex.isOverdue
        }
    }
    
    func remainingTime(at date: Date) -> String {
        switch self {
        case .homework(let hw): return hw.remainingTime(at: date)
        case .exam(let ex): return ex.remainingTime(at: date)
        }
    }
    
    var typeLabel: String {
        switch self {
        case .homework: return "作业"
        case .exam: return "考试"
        }
    }
}

// MARK: - Timeline Provider
struct HomeworkProvider: TimelineProvider {
    typealias Entry = HomeworkEntry
    
    func placeholder(in context: Context) -> HomeworkEntry {
        HomeworkEntry(date: Date(), tasks: [
            .homework(Homework(id: "1", name: "算法设计作业一", status: "未完成", courseName: "算法设计与分析", courseId: "114514", deadline: "2026-03-17 14:00")),
            .exam(Exam(id: "2", name: "单元测试二", status: "待互评", courseName: "Python程序设计", courseId: "114515", deadline: "2026-03-15 23:59"))
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (HomeworkEntry) -> ()) {
        let tasks = fetchAndSortTasks()
        let entry = HomeworkEntry(date: Date(), tasks: tasks)
        completion(entry)
    }

    // MARK: - 联动 XXTCore 的数据拉取逻辑 (HomeworkProvider 内)
    func getTimeline(in context: Context, completion: @escaping (Timeline<HomeworkEntry>) -> ()) {
        // 首先尝试从本地加载 App 抓取好的数据
        let tasks = fetchAndSortTasks()
        let entry = HomeworkEntry(date: Date(), tasks: tasks)
        
        // 设置下次刷新时间（例如 15 分钟后）
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func fetchAndSortTasks() -> [WidgetTaskItem] {
        let homeworks = Homework.loadHomework()
        let exams = Exam.loadExams()
        
        var items: [WidgetTaskItem] = []
        items.append(contentsOf: homeworks.map { .homework($0) })
        items.append(contentsOf: exams.map { .exam($0) })
        
        return items.sorted { t1, t2 in
            let t1Actionable = !t1.isCompleted && !t1.isOverdue
            let t2Actionable = !t2.isCompleted && !t2.isOverdue
            if t1Actionable && !t2Actionable { return true }
            if !t1Actionable && t2Actionable { return false }
            return (t1.deadlineDate ?? .distantFuture) < (t2.deadlineDate ?? .distantFuture)
        }
    }
}

// MARK: - Entry
struct HomeworkEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTaskItem]
}

// MARK: - Widget View
struct HomeworkWidgetEntryView : View {
    var entry: HomeworkEntry
    @Environment(\.widgetFamily) var family

    var actionableTasks: [WidgetTaskItem] {
        entry.tasks.filter { !$0.isCompleted && !$0.isOverdue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 10 : 6) {
            HStack {
                Image(systemName: "book.closed.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 12))
                Text("学习通待办")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                if !actionableTasks.isEmpty {
                    Text("\(actionableTasks.count)")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
            }
            
            Divider()

            if actionableTasks.isEmpty {
                Spacer()
                Text("暂无未完成待办")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                let displayCount: Int = {
                    switch family {
                    case .systemSmall: return 2
                    case .systemMedium: return 3
                    case .systemLarge: return 6
                    default: return 3
                    }
                }()
                
                VStack(alignment: .leading, spacing: family == .systemLarge ? 12 : 8) {
                    ForEach(actionableTasks.prefix(displayCount)) { task in
                        HomeworkRow(task: task, entryDate: entry.date)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
    }
}

struct HomeworkRow: View {
    let task: WidgetTaskItem
    let entryDate: Date
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(task.typeLabel)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(task.typeLabel == "考试" ? Color.purple.opacity(0.15) : Color.blue.opacity(0.1))
                        .foregroundColor(task.typeLabel == "考试" ? .purple : .blue)
                        .cornerRadius(3)
                    
                    Text(task.name)
                        .font(.system(size: family == .systemLarge ? 13 : 12, weight: .medium))
                        .lineLimit(1)
                }
                Text(task.courseName)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                let timeLeft = task.remainingTime(at: entryDate)
                if !timeLeft.isEmpty && timeLeft != "已超期" {
                    Text("\(task.status) · \(timeLeft)")
                        .font(.system(size: family == .systemLarge ? 11 : 10, weight: .bold))
                        .foregroundColor(statusColor)
                } else {
                    Text(timeLeft.isEmpty ? task.status : timeLeft)
                        .font(.system(size: family == .systemLarge ? 11 : 10, weight: .bold))
                        .foregroundColor(statusColor)
                }
            }
        }
    }
    
    private var statusColor: Color {
        if task.isOverdue { return .red }
        if task.isCompleted { return .green }
        return .orange
    }
    
    private var shortDeadline: String {
        // 简化截止时间显示，例如 03-17 14:00
        let parts = task.deadline.components(separatedBy: "-")
        return parts.count > 1 ? parts.dropFirst().joined(separator: "-") : task.deadline
    }
}

// MARK: - Widget
struct HomeworkWidget: Widget {
    let kind: String = "HomeworkWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HomeworkProvider()) { entry in
            HomeworkWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("学习通待办预览")
        .description("实时查看学习通未完成待办及过期时间。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    HomeworkWidget()
} timeline: {
    HomeworkEntry(date: Date(), tasks: [
        .homework(Homework(id: "1", name: "算法设计作业一", status: "未交", courseName: "算法设计与分析", courseId: "114514", deadline: "2026-03-17 14:00")),
        .exam(Exam(id: "2", name: "期中测试", status: "待考试", courseName: "Python程序设计", courseId: "114515", deadline: "2026-03-11 23:59"))
    ])
}

#Preview(as: .systemMedium) {
    HomeworkWidget()
} timeline: {
    HomeworkEntry(date: Date(), tasks: [
        .homework(Homework(id: "1", name: "算法分析与设计作业一", status: "未交", courseName: "算法设计与应用", courseId: "114514", deadline: "2026-03-17 14:00")),
        .exam(Exam(id: "2", name: "Python 进阶语法测试", status: "待考", courseName: "Python程序设计", courseId: "114515", deadline: "2026-03-12 12:00")),
        .homework(Homework(id: "3", name: "网络层协议分析报告", status: "未完成", courseName: "计算机网络", courseId: "114516", deadline: "2026-03-14 18:00"))
    ])
}

#Preview(as: .systemLarge) {
    HomeworkWidget()
} timeline: {
    HomeworkEntry(date: Date(), tasks: (1...12).map {
        if $0 % 3 == 0 {
            return .exam(Exam(id: "\($0)", name: "章节自测 \($0)", status: "待考", courseName: "示例课程名称", courseId: "11", deadline: "2026-03-17 14:00"))
        } else {
            return .homework(Homework(id: "\($0)", name: "作业项目 \($0)", status: "未交", courseName: "示例课程名称", courseId: "11", deadline: "2026-03-17 14:00"))
        }
    })
}
