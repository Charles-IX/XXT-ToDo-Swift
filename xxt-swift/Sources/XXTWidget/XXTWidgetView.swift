import SwiftUI
import WidgetKit
import XXTCore

struct XXTEntry: TimelineEntry {
    let date: Date
    let homeworks: [Homework]
}

struct XXTWidgetView : View {
    var entry: XXTEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("学习通待办")
                .font(.headline)
                .foregroundColor(.cyan)
            
            if entry.homeworks.isEmpty {
                Text("暂无未完成作业")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(entry.homeworks.prefix(3)) { hw in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(hw.name)
                                .font(.caption)
                                .lineLimit(1)
                            Text(hw.courseName)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(hw.status)
                            .font(.system(size: 10))
                            .padding(2)
                            .background(hw.isOverdue ? Color.red.opacity(0.1) : Color.yellow.opacity(0.1))
                            .foregroundColor(hw.isOverdue ? Color.red : Color.yellow)
                            .cornerRadius(4)
                    }
                }
            }
            Spacer()
        }
        .padding()
    }
}
