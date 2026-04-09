//
//  ContentView.swift
//  HomeworkToDo
//
//  Created by Charles on 2026/3/11.
//

import SwiftUI
import WidgetKit
import XXTCore

struct ContentView: View {
    @State private var homeworks: [Homework] = []
    @State private var exams: [Exam] = []
    @State private var isLoading = false
    @State private var currentHomeworkCount: Int = 0
    @State private var isShowingSettings = false
    @State private var errorMessage: String?
    @State private var updatingHomeworkId: String?
    @State private var updatingExamId: String?
    @State private var selectedHomework: Homework?
    @State private var selectedExam: Exam?
    
    @AppStorage("phone") private var phone = ""
    @AppStorage("password") private var password = ""
    @AppStorage("refresh_interval") private var refreshInterval: Double = 30 // Minutes
    @AppStorage("notification_thresholds") private var notificationThresholdsData: String = "60,1440" // Default: 1h, 24h
    @AppStorage("selected_course_ids") private var selectedCourseIdsData: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section(header: HStack {
                    Text("考试列表")
                    if isLoading && !exams.isEmpty {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.leading, 4)
                    }
                }) {
                    if exams.isEmpty {
                        if isLoading {
                            HStack {
                                ProgressView()
                                Text(" 正在加载作业...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        } else {
                             Text("暂无未完成考试")
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        }
                    } else {
                        TimelineView(.periodic(from: .now, by: 60)) { context in
                            ForEach(exams) { exam in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exam.name)
                                            .font(.headline)
                                            .lineLimit(2)
                                        Text(exam.courseName)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                        
                                        let timeStr = exam.remainingTime(at: context.date)
                                        if !timeStr.isEmpty {
                                            Text(timeStr)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(exam.isOverdue ? .red : .secondary)
                                        }
                                    }
                                    
                                    if updatingExamId == exam.id {
                                        Spacer()
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    
                                    Spacer(minLength: 10)
                                    Text(exam.isOverdue ? "已超期" : exam.status)
                                        .font(.caption)
                                        .padding(4)
                                        .background(exam.isCompleted ? Color.green.opacity(0.1) : (exam.isOverdue ? Color.red.opacity(0.1) : Color.orange.opacity(0.1)))
                                        .foregroundColor(exam.isCompleted ? .green : (exam.isOverdue ? .red : .orange))
                                        .cornerRadius(4)
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedExam = exam
                                }
                                .simultaneousGesture(TapGesture(count: 2).onEnded {
                                    Task {
                                        await updateExamDeadline(exam)
                                    }
                                })
                            }
                        }
                    }
                }

                Section(header: HStack {
                    Text("作业列表")
                    if isLoading && !homeworks.isEmpty {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.leading, 4)
                    }
                }) {
                    if let error = errorMessage, !isLoading {
                        Text("错误: \(error)")
                            .foregroundColor(.red)
                    } else if homeworks.isEmpty {
                        if isLoading {
                            HStack {
                                ProgressView()
                                Text(" 正在加载作业...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 16) {
                                Text("暂无未完成作业")
                                    .foregroundColor(.secondary)
                                
                                if (phone.isEmpty || password.isEmpty) {
                                    Button("去设置账号") {
                                        isShowingSettings = true
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.vertical, 40)
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        TimelineView(.periodic(from: .now, by: 60)) { context in
                            ForEach(homeworks) { hw in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(hw.name)
                                            .font(.headline)
                                            .lineLimit(2)
                                        HStack(alignment: .top) {
                                            Text(hw.courseName)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                                .layoutPriority(0)
                                            
//                                            Spacer(minLength: 10)
//
//                                            Text(hw.isOverdue ? "已超期" : hw.status)
//                                                .font(.caption)
//                                                .padding(4)
//                                                .background(hw.isCompleted ? Color.green.opacity(0.1) : (hw.isOverdue ? Color.red.opacity(0.1) : Color.orange.opacity(0.1)))
//                                                .foregroundColor(hw.isCompleted ? .green : (hw.isOverdue ? .red : .orange))
//                                                .cornerRadius(4)
//                                                .layoutPriority(1)
                                        }
                                        
                                        let timeStr = hw.remainingTime(at: context.date)
                                        if !timeStr.isEmpty {
                                            Text(timeStr)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(hw.isOverdue ? .red : .secondary)
                                        }
                                    }
                                    
                                    if updatingHomeworkId == hw.id {
                                        Spacer()
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    
                                    Spacer(minLength: 10)
                                    Text(hw.isOverdue ? "已超期" : hw.status)
                                        .font(.caption)
                                        .padding(4)
                                        .background(hw.isCompleted ? Color.green.opacity(0.1) : (hw.isOverdue ? Color.red.opacity(0.1) : Color.orange.opacity(0.1)))
                                        .foregroundColor(hw.isCompleted ? .green : (hw.isOverdue ? .red : .orange))
                                        .cornerRadius(4)
                                }
                                
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedHomework = hw
                                }
                                .simultaneousGesture(TapGesture(count: 2).onEnded {
                                    Task {
                                        await updateHomeworkDeadline(hw)
                                    }
                                })
                            }
                        }
                    }
                }
            }
            .refreshable {
                await loadData()
            }
            .navigationTitle("学习通待办")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: { isShowingSettings = true }) {
                        Label("设置", systemImage: "gearshape")
                    }
                    
                    Button(action: {
                        Task { await loadData() }
                    }) {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(refreshInterval: $refreshInterval, phone: $phone, password: $password)
                #if os(macOS)
                    .frame(width: 450, height: 600)
                #endif
            }
            .alert("作业详情", isPresented: Binding(
                get: { selectedHomework != nil },
                set: { if !$0 { selectedHomework = nil } }
            )) {
                Button("确定", role: .cancel) {}
                Button("更新截止时间") {
                    if let hw = selectedHomework {
                        Task { await updateHomeworkDeadline(hw) }
                    }
                }
            } message: {
                if let hw = selectedHomework,
                   let latestHw = homeworks.first(where: { $0.id == hw.id }) {
                    Text("\(latestHw.courseName)\n\(latestHw.name)\n\n当前截止时间：\n\(latestHw.deadline)")
                }
            }
            .alert("考试详情", isPresented: Binding(
                get: { selectedExam != nil },
                set: { if !$0 { selectedExam = nil } }
            )) {
                Button("确定", role: .cancel) {}
                Button("更新截止时间") {
                    if let exam = selectedExam {
                        Task { await updateExamDeadline(exam) }
                    }
                }
            } message: {
                if let exam = selectedExam,
                   let latestExam = exams.first(where: { $0.id == exam.id }) {
                    Text("\(latestExam.courseName)\n\(latestExam.name)\n\n当前截止时间：\n\(latestExam.deadline)")
                }
            }
        }
        .onAppear {
            NotificationCenter.default.addObserver(forName: NSNotification.Name("RefreshHomeworkList"), object: nil, queue: .main) { _ in
                applyFiltering()
            }
            
            // Check if we have data before loading
            let localHomeworkData = Homework.loadHomework()
            let localExamData = Exam.loadExams()
            if !localHomeworkData.isEmpty || !localExamData.isEmpty {
                applyFiltering(homeworks: localHomeworkData, exams: localExamData)
            } else {
                Task {
                    await loadData()
                }
            }
        }
        // Auto-refresh timer based on settings
        .task(id: refreshInterval) {
            if refreshInterval > 0 {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: UInt64(refreshInterval * 60 * 1_000_000_000))
                    await loadData()
                }
            }
        }
    }
    
    func updateHomeworkDeadline(_ hw: Homework) async {
        guard updatingHomeworkId == nil else { return }
        updatingHomeworkId = hw.id
        
        let service = XXTService()
        do {
            let success = try await service.login(phone: phone, pass: password)
            if success {
                let updatedHw = try await service.updateDeadline(for: hw)
                
                await MainActor.run {
                    if let index = homeworks.firstIndex(where: { $0.id == hw.id }) {
                        homeworks[index] = updatedHw
                        Homework.saveHomework(homeworks)
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
            }
        } catch {
            print("Update failed: \(error)")
        }
        
        updatingHomeworkId = nil
    }
    
    func updateExamDeadline(_ exam: Exam) async {
        guard updatingExamId == nil else { return }
        updatingExamId = exam.id
        
        let service = XXTService()
        do {
            let success = try await service.login(phone: phone, pass: password)
            if success {
                let updatedExam = try await service.updateExamDeadline(for: exam)
                
                await MainActor.run {
                    if let index = exams.firstIndex(where: { $0.id == exam.id }) {
                        exams[index] = updatedExam
                        Exam.saveExams(exams)
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
            }
        } catch {
            print("Update failed: \(error)")
        }
        
        updatingExamId = nil
    }
    
    func loadData() async {
        guard !phone.isEmpty && !password.isEmpty else {
            errorMessage = "请在设置中配置账号密码"
            isShowingSettings = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        let service = XXTService()
        
        do {
            let success = try await service.login(phone: phone, pass: password)
            if success {
                async let homeworkTask = service.fetchAllHomework()
                async let examTask = service.fetchAllExams()
                
                let (allHomework, allExams) = try await (homeworkTask, examTask)
                
                await MainActor.run {
                    self.currentHomeworkCount = allHomework.count
                    
                    // 1. Deduplication for Homework
                    var orderedHomeworks: [Homework] = []
                    var seenHwKeys: Set<String> = []
                    for hw in allHomework {
                        if !seenHwKeys.contains(hw.id) {
                            orderedHomeworks.append(hw)
                            seenHwKeys.insert(hw.id)
                        }
                    }
                    let sortedHomeworks = orderedHomeworks.sorted { (h1, h2) -> Bool in
                        let h1Actionable = !h1.isCompleted && !h1.isOverdue
                        let h2Actionable = !h2.isCompleted && !h2.isOverdue
                        if h1Actionable && !h2Actionable { return true }
                        if !h1Actionable && h2Actionable { return false }
                        if h1Actionable && h2Actionable {
                            return (h1.deadlineDate ?? .distantFuture) < (h2.deadlineDate ?? .distantFuture)
                        }
                        return false
                    }

                    // 2. Deduplication for Exams
                    var orderedExams: [Exam] = []
                    var seenExamKeys: Set<String> = []
                    for exam in allExams {
                        if !seenExamKeys.contains(exam.id) {
                            orderedExams.append(exam)
                            seenExamKeys.insert(exam.id)
                        }
                    }
                    let sortedExams = orderedExams.sorted { (e1, e2) -> Bool in
                        let e1Actionable = !e1.isCompleted && !e1.isOverdue
                        let e2Actionable = !e2.isCompleted && !e2.isOverdue
                        if e1Actionable && !e2Actionable { return true }
                        if !e1Actionable && e2Actionable { return false }
                        if e1Actionable && e2Actionable {
                            return (e1.deadlineDate ?? .distantFuture) < (e2.deadlineDate ?? .distantFuture)
                        }
                        return false
                    }

                    Homework.saveHomework(sortedHomeworks)
                    Exam.saveExams(sortedExams)
                    
                    applyFiltering(homeworks: sortedHomeworks, exams: sortedExams)
                    
                    if selectedCourseIdsData.isEmpty {
                        let allHwCourseIds = Set(sortedHomeworks.map { $0.courseId })
                        let allExamCourseIds = Set(sortedExams.map { $0.courseId })
                        let allIds = allHwCourseIds.union(allExamCourseIds).joined(separator: ",")
                        selectedCourseIdsData = allIds
                    }
                    
                    WidgetCenter.shared.reloadAllTimelines()
                }
            } else {
                errorMessage = "登录失败，请检查账号密码"
            }
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func applyFiltering(homeworks: [Homework]? = nil, exams: [Exam]? = nil) {
        let hwSource = homeworks ?? Homework.loadHomework()
        let examSource = exams ?? Exam.loadExams()
        
        let thresholds = notificationThresholdsData.components(separatedBy: ",").compactMap { Int($0) }
        NotificationManager.shared.scheduleNotifications(for: hwSource, exams: examSource, thresholdsInMinutes: thresholds)

        print("🔍 [Homework] Filter count before=\(hwSource.count) selectedIds=\(selectedCourseIdsData)")
        print("🔍 [Exam] Filter count before=\(examSource.count) selectedIds=\(selectedCourseIdsData)")

        if selectedCourseIdsData.isEmpty {
            self.homeworks = hwSource
            self.exams = examSource
        } else {
            let selectedIds = Set(selectedCourseIdsData.components(separatedBy: ","))
            self.homeworks = hwSource.filter { selectedIds.contains($0.courseId) }
            self.exams = examSource.filter { selectedIds.contains($0.courseId) }
        }
        
        print("🔍 [Homework] Filter count after=\(self.homeworks.count)")
        print("🔍 [Exam] Filter count after=\(self.exams.count)")
    }
}

#Preview {
    ContentView()
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var refreshInterval: Double
    @Binding var phone: String
    @Binding var password: String
    
    @AppStorage("notification_thresholds") private var notificationThresholdsData: String = "60,1440"
    @State private var thresholds: [Int] = [60, 1440]
    @State private var newThreshold: String = ""
    
    @State private var isShowingCourseSelection = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("账号设置")) {
                    TextField("手机号", text: $phone)
                    #if os(iOS)
                        .keyboardType(.phonePad)
                    #endif
                    SecureField("密码", text: $password)
                }

                Section(header: Text("内容控制")) {
                    Button(action: { isShowingCourseSelection = true }) {
                        HStack {
                            Text("编辑显示的课程")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                
                Section(header: Text("通知提醒")) {
                    Text("当作业剩余下列时间时发送提醒：")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(thresholds, id: \.self) { mins in
                        HStack {
                            Text(formatMinutes(mins))
                            Spacer()
                            Button(role: .destructive) {
                                thresholds.removeAll { $0 == mins }
                                saveThresholds()
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                        }
                    }
                    
                    HStack {
                        TextField("新增提醒时间 (分钟)", text: $newThreshold)
                        #if os(iOS)
                            .keyboardType(.numberPad)
                        #endif
                        Button("添加") {
                            if let val = Int(newThreshold), val > 0, !thresholds.contains(val) {
                                thresholds.append(val)
                                thresholds.sort()
                                saveThresholds()
                                newThreshold = ""
                            }
                        }
                        .disabled(newThreshold.isEmpty)
                    }
                }
                
                Section(header: Text("自动刷新")) {
                    VStack(alignment: .leading) {
                        Text("刷新间隔: \(Int(refreshInterval)) 分钟")
                        Slider(value: $refreshInterval, in: 5...120, step: 5) {
                            Text("刷新间隔")
                        } minimumValueLabel: {
                            Text("5")
                        } maximumValueLabel: {
                            Text("120")
                        }
                    }
                }
                
                Section(footer: Text("为避免触发风控，建议刷新间隔不低于 10 分钟。")) {
                    // Placeholder for aesthetics or info
                }
            }
            .formStyle(.grouped)
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $isShowingCourseSelection) {
                CourseSelectionView(phone: phone, password: password)
                #if os(macOS)
                    .frame(width: 500, height: 700)
                #endif
            }
            #if os(macOS)
            .padding()
            #endif
            .onAppear {
                loadThresholds()
                NotificationManager.shared.requestAuthorization()
            }
        }
    }
    
    private func loadThresholds() {
        thresholds = notificationThresholdsData.components(separatedBy: ",").compactMap { Int($0) }
        if thresholds.isEmpty { thresholds = [60, 1440] }
    }
    
    private func saveThresholds() {
        notificationThresholdsData = thresholds.map { String($0) }.joined(separator: ",")
        // 立即重新触发通知安排
        NotificationManager.shared.scheduleNotifications(for: Homework.loadHomework(), exams: Exam.loadExams(), thresholdsInMinutes: thresholds)
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 1440 {
            return "\(minutes / 1440) 天"
        } else if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h) 小时 \(m) 分钟" : "\(h) 小时"
        } else {
            return "\(minutes) 分钟"
        }
    }
}

struct CourseSelectionView: View {
    let phone: String
    let password: String
    @Environment(\.dismiss) var dismiss
    
    @State private var folders: [CourseFolder] = []
    @State private var selectedCourseIds: Set<String> = []
    @State private var isLoading = false
    @State private var expandedFolders: Set<String> = ["root"]
    
    @AppStorage("selected_course_ids") private var selectedCourseIdsData: String = ""

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("正在获取课程结构...")
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(folders) { folder in
                        Section {
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedFolders.contains(folder.id) },
                                    set: { isExpanded in
                                        if isExpanded { expandedFolders.insert(folder.id) }
                                        else { expandedFolders.remove(folder.id) }
                                    }
                                )
                            ) {
                                ForEach(folder.courses) { course in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(course.name)
                                                .font(.body)
                                            Text(course.teacher)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if selectedCourseIds.contains(course.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        toggleCourse(course.id)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(folder.name)
                                        .font(.headline)
                                    Spacer()
                                    Button(isAllSelected(in: folder) ? "取消全选" : "全选") {
                                        toggleFolder(folder)
                                    }
                                    .font(.caption)
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("课程显示设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveSelection()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                loadInitialData()
            }
        }
    }
    
    private func toggleCourse(_ id: String) {
        if selectedCourseIds.contains(id) {
            selectedCourseIds.remove(id)
        } else {
            selectedCourseIds.insert(id)
        }
    }
    
    private func isAllSelected(in folder: CourseFolder) -> Bool {
        folder.courses.allSatisfy { selectedCourseIds.contains($0.id) }
    }
    
    private func toggleFolder(_ folder: CourseFolder) {
        let allSelected = isAllSelected(in: folder)
        for course in folder.courses {
            if allSelected {
                selectedCourseIds.remove(course.id)
            } else {
                selectedCourseIds.insert(course.id)
            }
        }
    }
    
    private func loadInitialData() {
        // Load saved selection
        if !selectedCourseIdsData.isEmpty {
            let ids = selectedCourseIdsData.components(separatedBy: ",")
            selectedCourseIds = Set(ids)
        }
        
        // Fetch folders
        Task {
            isLoading = true
            let service = XXTService()
            if try await service.login(phone: phone, pass: password) {
                if let fetchedFolders = try? await service.fetchCourseFolders() {
                    self.folders = fetchedFolders
                    // Debug print to console to see structure
                    print("🔍 [CourseSelectionView] Fetched \(fetchedFolders.count) folders.")
                    for f in fetchedFolders {
                        print("📁 Folder: \(f.name) (\(f.courses.count) courses)")
                    }

                    // If selection is empty, default to all selected
                    if selectedCourseIds.isEmpty {
                        selectedCourseIds = Set(fetchedFolders.flatMap { $0.courses.map { $0.id } })
                    }
                }
            }
            isLoading = false
        }
    }
    
    private func saveSelection() {
        selectedCourseIdsData = Array(selectedCourseIds).joined(separator: ",")
        WidgetCenter.shared.reloadAllTimelines()
        
        // 通知主视图刷新列表，过滤掉不显示的课程
        NotificationCenter.default.post(name: NSNotification.Name("RefreshHomeworkList"), object: nil)
    }
}
