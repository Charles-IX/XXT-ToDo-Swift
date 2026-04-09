import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import SwiftSoup

public final class XXTService: NSObject, @unchecked Sendable, URLSessionDelegate {
    private let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36"
    private var session: URLSession!
    
    public override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - Login
    public func login(phone: String, pass: String) async throws -> Bool {
        guard let phoneEnc = XXTEncryption.encrypt(phone),
              let passEnc = XXTEncryption.encrypt(pass) else {
            return false
        }
        
        let url = URL(string: "http://passport2.chaoxing.com/fanyalogin")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("passport2.chaoxing.com", forHTTPHeaderField: "Host")
        request.setValue("http://passport2.chaoxing.com", forHTTPHeaderField: "Origin")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let formData = [
            "uname": phoneEnc,
            "password": passEnc,
            "t": "true",
            "doubleFactorLogin": "0",
            "independentId": "0"
        ]
        
        let bodyString = formData.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (data, _) = try await session.data(for: request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = json["status"] as? Bool {
            return status
        }
        return false
    }
    
    // MARK: - Fetch Courses
    public func fetchCourses() async throws -> [Course] {
        let url = URL(string: "https://mooc2-ans.chaoxing.com/mooc2-ans/visit/courses/list?v=\(Date().timeIntervalSince1970)&start=0&size=500&catalogId=0&superstarClass=0")!
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else { return [] }
        
        let doc = try SwiftSoup.parse(html)
        let courseLis = try doc.select("li.course")
        var courses: [Course] = []
        
        for li in courseLis {
            let nameSpan = try li.select("span.course-name").first()
            let name = try nameSpan?.attr("title") ?? "未知课程"
            
            let link = try li.select("a.color1").first()
            let courseUrl = try link?.attr("href") ?? ""
            
            let teacherP = try li.select("p.line2.color3").first()
            let teacher = try teacherP?.attr("title") ?? "未知老师"
            
            let courseId = courseUrl.components(separatedBy: "courseid=").last?.components(separatedBy: "&").first ?? UUID().uuidString
            
            courses.append(Course(id: courseId, name: name, teacher: teacher, url: courseUrl))
        }
        return courses
    }

    // MARK: - Debug: Save Course Folders HTML
    public func debugFetchAndAnalyzeCourseFolders() async throws {
        // 尝试两个潜在的 URL
        let urls = [
            "https://mooc2-ans.chaoxing.com/mooc2-ans/visit/courses/list?v=\(Date().timeIntervalSince1970)&start=0&size=500&catalogId=0&superstarClass=0",
            "https://i.chaoxing.com/base"
        ]
        
        for urlStr in urls {
            print("🔍 [XXTService] Debug fetching URL: \(urlStr)")
            guard let url = URL(string: urlStr) else { continue }
            var request = URLRequest(url: url)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            
            let (data, _) = try await session.data(for: request)
            if let html = String(data: data, encoding: .utf8) {
                XXTParserDebugger.analyzeCoursePage(html: html)
            }
        }
    }

    // MARK: - Fetch Course Folders
    public func fetchCourseFolders() async throws -> [CourseFolder] {
        let url = URL(string: "https://mooc2-ans.chaoxing.com/mooc2-ans/visit/courses/list?v=\(Date().timeIntervalSince1970)&start=0&size=500&catalogId=0&superstarClass=0")!
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else { return [] }
        
        print("🔍 [XXTService] HTML fetched, length: \(html.count)")
        
        let doc = try SwiftSoup.parse(html)
        var folders: [CourseFolder] = []
        
        // 1. 获取所有的文件夹定义 (位于 ul.file-list li[fileid])
        let folderLis = try doc.select("ul.file-list li[fileid]")
        print("🔍 [XXTService] Found \(folderLis.size()) folder definitions.")
        
        for folderLi in folderLis {
            let folderName = try (folderLi.select("h3.file-name").first()?.text() ?? "未知文件夹").trimmingCharacters(in: .whitespacesAndNewlines)
            let folderId = try folderLi.attr("fileid")
            if folderId.isEmpty { continue }
            
            // 2. 核心：查找该文件夹内部的内容
            // 内部课程是以 li.course 形式存在，且带有一个类似 'catalog_FOLDERID' 的类名
            let coursesInFolder = try parseCourses(from: doc.select("li.course.catalog_\(folderId)"))
            
            folders.append(CourseFolder(id: folderId, name: folderName, courses: coursesInFolder))
            print("📁 [XXTService] Parsed folder: \(folderName) (ID: \(folderId)) with \(coursesInFolder.count) courses.")
        }
        
        // 3. 获取所有展示出的课程项目 (排除已归类文件夹的)
        let allCourseElements = try doc.select("li.course")
        let allParsedCourses = try parseCourses(from: allCourseElements)
        
        // 4. 确定哪些课程属于“未分类” (通常带有 catalog_0 类名)
        let folderCourseIds = Set(folders.flatMap { $0.courses.map { $0.id } })
        let rootCourses = allParsedCourses.filter { !folderCourseIds.contains($0.id) }
        
        if !rootCourses.isEmpty {
            folders.insert(CourseFolder(id: "root", name: "未分类课程", courses: rootCourses), at: 0)
            print("📁 [XXTService] Added \(rootCourses.count) root courses.")
        }
        
        return folders
    }

    private func parseCourses(from elements: Elements) throws -> [Course] {
        var courses: [Course] = []
        for el in elements {
            // 排除文件夹节点本身
            if try el.hasAttr("fileid") || el.hasClass("folder") { continue }
            
            // 提取课程名称
            let nameSpan = try el.select("span.course-name").first()
            let name = try nameSpan?.attr("title") ?? nameSpan?.text() ?? "未知课程"
            if name == "未知课程" || name.isEmpty { continue }
            
            // 提取课程 URL (通常在 a.color1 或 h3 内部)
            let link = try el.select("div.course-info h3 a, div.course-cover a").first()
            let courseUrl = try link?.attr("href") ?? ""
            if courseUrl.isEmpty || !courseUrl.contains("courseid=") { continue }
            
            // 提取教师名称
            let teacherP = try el.select("p.line2.color3").first()
            let teacher = try teacherP?.attr("title") ?? teacherP?.text() ?? "未知老师"
            
            // 提取 CourseId
            let courseId = courseUrl.components(separatedBy: "courseid=").last?.components(separatedBy: "&").first ?? UUID().uuidString
            
            if !courses.contains(where: { $0.id == courseId }) {
                // 替换 HTML 实体
                let cleanTeacher = teacher.replacingOccurrences(of: "&nbsp;", with: " ")
                courses.append(Course(id: courseId, name: name, teacher: cleanTeacher, url: courseUrl))
            }
        }
        return courses
    }
    
    // MARK: - Fetch Homework
    public func fetchHomework(for course: Course) async throws -> [Homework] {
        guard let courseURL = URL(string: course.url) else { return [] }
        
        // 1. Visit course page to get workEnc and params
        var request = URLRequest(url: courseURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (pageData, response) = try await session.data(for: request)
        guard let html = String(data: pageData, encoding: .utf8),
              let finalURL = response.url else { return [] }
              
        let doc = try SwiftSoup.parse(html)
        let workEnc = try doc.select("input#workEnc").attr("value")
        
        let components = URLComponents(url: finalURL, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems
        let courseId = queryItems?.first(where: { $0.name == "courseid" })?.value ?? ""
        let classId = queryItems?.first(where: { $0.name == "clazzid" })?.value ?? ""
        let cpi = queryItems?.first(where: { $0.name == "cpi" })?.value ?? ""
        
        // 2. Fetch work list
        var workUrlComponents = URLComponents(string: "https://mooc1.chaoxing.com/mooc2/work/list")!
        workUrlComponents.queryItems = [
            URLQueryItem(name: "courseId", value: courseId),
            URLQueryItem(name: "classId", value: classId),
            URLQueryItem(name: "cpi", value: cpi),
            URLQueryItem(name: "ut", value: "s"),
            URLQueryItem(name: "enc", value: workEnc)
        ]
        
        var workRequest = URLRequest(url: workUrlComponents.url!)
        workRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        workRequest.setValue("mooc1.chaoxing.com", forHTTPHeaderField: "Host")
        workRequest.setValue("https://mooc2-ans.chaoxing.com/", forHTTPHeaderField: "Referer")
        
        let (workData, _) = try await session.data(for: workRequest)
        guard let workHtml = String(data: workData, encoding: .utf8) else { return [] }
        
        let workDoc = try SwiftSoup.parse(workHtml)
        let workItems = try workDoc.select("div.bottomList li")
        var homeworks: [Homework] = []
        
        for (index, item) in workItems.enumerated() {
            let detailUrl = try item.attr("data")
            let name = try item.select("p.overHidden2").text()
            let status = try item.select("p.status").text()
            
            // Generate a more unique ID using course URL and item index
            let cId = course.url.components(separatedBy: "courseid=").last?.components(separatedBy: "&").first ?? "0"
            let hwId = "\(cId)_\(index + 1)"
            
            // Only fetch deadline for unfinished works
            let unfinished = ["未交", "未完成", "未提交", "待互评"]
            var deadline = "暂无截止时间"
            if unfinished.contains(where: { status.contains($0) }) {
                deadline = try await fetchDeadline(workUrl: detailUrl)
            }
            
            if let index = homeworks.firstIndex(where: {$0.id == hwId && $0.name == name && $0.courseName == course.name}) {
                homeworks[index] = Homework(id: hwId, name: name, status: status, courseName: course.name, courseId: cId, deadline: deadline)
            } else {
                homeworks.append(Homework(id: hwId, name: name, status: status, courseName: course.name, courseId: cId, deadline: deadline))
            }
        }
        
        return homeworks
    }
    
    // MARK: - Fetch All Homework (规避风控)
    public func fetchAllHomework() async throws -> [Homework] {
        print("🔍 [Homework] Starting to fetch all homework...")
        let url = URL(string: "https://mooc1.chaoxing.com/work/stu-work")!
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            print("❌ [Homework] Failed to decode homework HTML")
            return []
        }
        
        let doc = try SwiftSoup.parse(html)
        let workLis = try doc.select("li[onclick^=goTask]")
        
        var finalLis = workLis
        if finalLis.isEmpty() {
            finalLis = try doc.select("ul.nav li")
        }
        
        print("🔍 [Homework] Found \(finalLis.size()) homework list items in HTML")
        
        var tempHomeworkData: [(id: String, name: String, status: String, courseName: String, deadline: String, courseId: String, detailUrl: String)] = []
        var needsCourseRepair = false
        
        for li in finalLis {
            let dataUrl = try li.attr("data")
            let divRoleOption = try li.select("div[role=option]").first()
            guard let div = divRoleOption else { continue }
            
            let name = try div.select("p").first()?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? "未知作业"
            
            var status = ""
            if let statusSpan = try div.select("span.status").first() {
                status = try statusSpan.text()
            } else {
                let spans = try div.select("span:not([aria-label])")
                for span in spans {
                    let text = try span.text().trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty && !text.contains("《") && !text.contains("剩余") {
                        status = text
                        break
                    }
                }
            }
            
            var courseName = "未知课程"
            for span in try div.select("span") {
                let text = try span.text()
                if text.contains("《") {
                    courseName = text.replacingOccurrences(of: "《", with: "").replacingOccurrences(of: "》", with: "")
                    break
                }
            }
            
            if courseName.contains("...") || courseName.hasSuffix("…") {
                needsCourseRepair = true
                print("⚠️ [Homework] Found truncated course name: '\(courseName)'")
            }
            
            var deadline = "暂无截止时间"
            if let frSpan = try div.select("span.fr").first() {
                deadline = try frSpan.text()
            }
            
            var hwId = UUID().uuidString
            var courseId = ""
            var detailUrl = ""
            if let urlComponents = URLComponents(string: dataUrl) {
                if let refId = urlComponents.queryItems?.first(where: { $0.name == "taskrefId" })?.value {
                    hwId = refId
                }
                // 大小写不敏感查找 courseId
                courseId = urlComponents.queryItems?.first(where: { $0.name.caseInsensitiveCompare("courseid") == .orderedSame })?.value ?? ""
                detailUrl = dataUrl
            }
            
            tempHomeworkData.append((id: hwId, name: name, status: status, courseName: courseName, deadline: deadline, courseId: courseId, detailUrl: detailUrl))
            print("📝 [Homework] Parsed: \(name) | Status: \(status) | cId: \(courseId) | Course: \(courseName)")
        }
        
        var courseMap: [String: String] = [:]
        var fullCourseList: [Course] = []
        
        if needsCourseRepair {
            print("🔍 [Homework] Detected truncated course names, fetching full course list...")
            let fullCourses = try? await fetchCourses()
            if let fullCourses = fullCourses {
                fullCourseList = fullCourses
                print("🔍 [Homework] Fetched \(fullCourses.count) courses.")
                for c in fullCourses {
                    if let cURL = URLComponents(string: c.url),
                       let realId = cURL.queryItems?.first(where: { $0.name.caseInsensitiveCompare("courseid") == .orderedSame })?.value {
                        courseMap[realId] = c.name
                    }
                }
            }
            print("🔍 [Homework] Course map built with \(courseMap.count) entries.")
        }
        
        var homeworks: [Homework] = []
        let unfinished = ["未交", "未完成", "未提交", "待互评"]
        
        // 1. 加载本地已有的作业，用于检查 isPreciseDeadline
        let savedHomeworks = Homework.loadHomework()
        
        // 用于缓存通过详情页反查到的课程名，避免同一门课重复请求
        var resolvedCourseNames: [String: String] = [:]

        for item in tempHomeworkData {
            var finalCourseName = courseMap[item.courseId]
            
            // 核心修复逻辑：
            // 1. 如果ID映射失败，检查缓存是否已解决
            if finalCourseName == nil {
                finalCourseName = resolvedCourseNames[item.courseId]
            }

            // 2. 如果缓存也没有，且课程名残缺，尝试 fuzzy match
            if finalCourseName == nil && needsCourseRepair {
                let cleanName = item.courseName.replacingOccurrences(of: "...", with: "")
                                               .replacingOccurrences(of: "…", with: "")
                                               .trimmingCharacters(in: .whitespaces)
                
                if cleanName.count < item.courseName.count {
                    if let match = fullCourseList.first(where: { $0.name.hasPrefix(cleanName) }) {
                        finalCourseName = match.name
                        print("✅ [Homework] Fuzzy matched: '\(item.courseName)' -> '\(match.name)'")
                        // 存入缓存
                        resolvedCourseNames[item.courseId] = match.name
                    } else if !item.detailUrl.isEmpty {
                        // 3. 终极兜底：Fuzzy match 也失败（说明不在活跃课程列表），尝试访问详情页反查
                        // 为了防止风控，这里加一个简单的随机延时，并且只对每个courseId做一次
                        print("🔍 [Homework] Fuzzy failed. Fetching detail to resolve course name for ID: \(item.courseId)")
                        if let resolvedName = try? await fetchCourseNameFromDetail(workUrl: item.detailUrl) {
                            if !resolvedName.isEmpty {
                                finalCourseName = resolvedName
                                resolvedCourseNames[item.courseId] = resolvedName
                                print("✅ [Homework] Resolved via detail page: '\(item.courseName)' -> '\(resolvedName)'")
                            }
                        }
                    }
                }
            }
            
            let displayCourseName = finalCourseName ?? item.courseName
            var finalDeadline = item.deadline
            var isPrecise = false
            
            // 检查该作业是否已经在本地存在
            let saved = savedHomeworks.first(where: { $0.id == item.id })
            
            // 如果本地已有且状态未变，且已经具有精确时间，则保留
            if let saved = saved, saved.status == item.status && saved.isPreciseDeadline {
                finalDeadline = saved.deadline
                isPrecise = true
            }
            
            // 只有不是精确时间，且属于待处理状态时，才去执行爬虫单点抓取
            if !isPrecise && unfinished.contains(where: { item.status.contains($0) }) && !item.detailUrl.isEmpty {
                print("🕸️ [Homework] Fetching precise deadline for '\(item.name)'...")
                if let exactDeadline = try? await fetchDeadline(workUrl: item.detailUrl), exactDeadline != "暂无截止时间" {
                    finalDeadline = exactDeadline
                    isPrecise = true
                    print("✅ [Homework] Precise deadline found: \(exactDeadline)")
                }
            }
            
            // 2. 兜底逻辑：如果最终获取到的还是原生文本（如“剩余94小时”），将其转换为一个近似的过期时间点字符串
            // 这样模型层解析出的 deadlineDate 就不为 nil，从而实现动态倒计时。
            if finalDeadline.contains("剩余") {
                let raw = finalDeadline
                let daysMatch = raw.range(of: #"(\d+)天"#, options: .regularExpression)
                let hoursMatch = raw.range(of: #"(\d+)小时"#, options: .regularExpression)
                let minutesMatch = raw.range(of: #"(\d+)分钟?"#, options: .regularExpression)
                
                var totalSeconds: TimeInterval = 0
                if let range = daysMatch {
                    let val = Double(raw[range].replacingOccurrences(of: "天", with: "")) ?? 0
                    totalSeconds += val * 86400
                }
                if let range = hoursMatch {
                    let val = Double(raw[range].replacingOccurrences(of: "小时", with: "")) ?? 0
                    totalSeconds += val * 3600
                }
                if let range = minutesMatch {
                    let val = Double(raw[range].replacingOccurrences(of: "分", with: "").replacingOccurrences(of: "钟", with: "")) ?? 0
                    totalSeconds += val * 60
                }
                
                if totalSeconds > 0 {
                    let expireDate = Date().addingTimeInterval(totalSeconds)
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm"
                    finalDeadline = formatter.string(from: expireDate)
                }
            }
            
            homeworks.append(Homework(id: item.id, name: item.name, status: item.status, courseName: displayCourseName, courseId: item.courseId, deadline: finalDeadline, detailUrl: item.detailUrl, isPreciseDeadline: isPrecise))
        }
        
        print("🏁 [Homework] Finished fetching homework. Total parsed: \(homeworks.count)")
        return homeworks
    }
    
    // Helper: 从作业详情页反查课程名称
    private func fetchCourseNameFromDetail(workUrl: String) async throws -> String? {
        var finalUrlStr = workUrl
        if !workUrl.lowercased().hasPrefix("http") {
             finalUrlStr = "https://mooc1.chaoxing.com" + (workUrl.hasPrefix("/") ? "" : "/") + workUrl
        }
        guard let url = URL(string: finalUrlStr) else { return nil }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else { return nil }
        let doc = try SwiftSoup.parse(html)
        
        // 尝试从网页标题或特定元素获取课程名
        // 通常详情页包含 <h3 class="courseName"> 或者 title
        if let h3 = try doc.select("h3.f14").first() {
            // mooc2 work detail header
             let text = try h3.text()
             // 格式往往是 "课程：XXXX 班级：..."
             if let range = text.range(of: "课程：") {
                 let after = text[range.upperBound...]
                 let stopNodes = ["班级", "教师", "　"] // 全角空格
                 var endIdx = after.endIndex
                 for stop in stopNodes {
                     if let r = after.range(of: stop) {
                         if r.lowerBound < endIdx { endIdx = r.lowerBound }
                     }
                 }
                 return String(after[..<endIdx]).trimmingCharacters(in: .whitespaces)
             }
        }
        
        // 备选：从网页 title 尝试提取? (通常不仅包含课程名，较难)
        return nil
    }

    public func updateDeadline(for homework: Homework) async throws -> Homework {
        guard let url = homework.detailUrl, !url.isEmpty else {
            return homework
        }
        var newDeadline = try await fetchDeadline(workUrl: url)
        var isPrecise = homework.isPreciseDeadline
        
        if newDeadline != "暂无截止时间" {
            isPrecise = true
        } else if homework.deadline != "暂无截止时间" {
             // 如果抓取失败（返回暂无截止时间），尽量保留原有信息，而不是覆盖为无效
            newDeadline = homework.deadline
        }
        
        // Return a new homework instance with updated deadline
        return Homework(
            id: homework.id,
            name: homework.name,
            status: homework.status,
            courseName: homework.courseName,
            courseId: homework.courseId,
            deadline: newDeadline,
            detailUrl: homework.detailUrl,
            isPreciseDeadline: isPrecise
        )
    }

    private func fetchDeadline(workUrl: String) async throws -> String {
        var finalUrlStr = workUrl
        if !workUrl.lowercased().hasPrefix("http") {
             finalUrlStr = "https://mooc1.chaoxing.com" + (workUrl.hasPrefix("/") ? "" : "/") + workUrl
        }
        
        guard let url = URL(string: finalUrlStr) else { return "暂无截止时间" }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else { return "暂无截止时间" }
        
        let doc = try SwiftSoup.parse(html)
        let currentYear = Calendar.current.component(.year, from: Date())
        
        // 优先检查隐藏域中的时间戳 (mooc2常见，可靠性最高)
        if let endTimeInput = try doc.select("input#endTime").first() {
            let val = try endTimeInput.attr("value")
            if let ts = Double(val), ts > 0 {
                 let date = Date(timeIntervalSince1970: ts / 1000)
                 let formatter = DateFormatter()
                 formatter.dateFormat = "yyyy-MM-dd HH:mm"
                 return formatter.string(from: date)
            }
        }
        
        // 方法1: 查找互评时间 (hpInfo)
        if let peerTimeP = try doc.select("p.hpInfo").first() {
            let text = try peerTimeP.text()
            if text.contains("互评时间") {
                // 提取 "至" 后面的时间，支持 MM-DD HH:MM
                let regex = try NSRegularExpression(pattern: "至\\s*(\\d{1,2}-\\d{1,2}\\s+\\d{1,2}:\\d{2})")
                if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                    if let range = Range(match.range(at: 1), in: text) {
                        return "\(currentYear)-\(text[range])"
                    }
                }
            }
        }
        
        // 方法2: 查找作答时间 (rightBord) - 常见于普通作业
        if let timeP = try doc.select("p.rightBord").first() {
            let ems = try timeP.select("em")
            if ems.size() >= 2 {
                let deadline = try ems.get(1).text().trimmingCharacters(in: .whitespaces)
                if !deadline.hasPrefix("20") {
                    return "\(currentYear)-\(deadline)"
                }
                return deadline
            }
        }
        
        // 方法3: 通用正则匹配
        let allText = try doc.text()
        
        // 关键修复：增加对不带年份日期的支持
        let regexPatterns = [
            // 带年份 (yyyy-MM-dd HH:mm)
            "至\\s*(\\d{4}[-年]\\d{1,2}[-月]\\d{1,2}[日]?\\s+\\d{1,2}:\\d{2})",
            "截止时间[:：]?\\s*(\\d{4}[-年]\\d{1,2}[-月]\\d{1,2}[日]?\\s+\\d{1,2}:\\d{2})",
            "截止[:：]?\\s*(\\d{4}[-年]\\d{1,2}[-月]\\d{1,2}[日]?\\s+\\d{1,2}:\\d{2})",
            "结束时间[:：]?\\s*(\\d{4}[-年]\\d{1,2}[-月]\\d{1,2}[日]?\\s+\\d{1,2}:\\d{2})",
            "(\\d{4}[-年]\\d{1,2}[-月]\\d{1,2}[日]?\\s+\\d{1,2}:\\d{2})\\s*截止",
            
            // 不带年份 (MM-dd HH:mm)，默认补全当前年份
            "至\\s*(\\d{1,2}[-月]\\d{1,2}[日]?\\s+\\d{1,2}:\\d{2})",
            "截止时间[:：]?\\s*(\\d{1,2}[-月]\\d{1,2}[日]?\\s+\\d{1,2}:\\d{2})",
            "截止[:：]?\\s*(\\d{1,2}[-月]\\d{1,2}[日]?\\s+\\d{1,2}:\\d{2})",
            "结束时间[:：]?\\s*(\\d{1,2}[-月]\\d{1,2}[日]?\\s+\\d{1,2}:\\d{2})"
        ]
        
        for pattern in regexPatterns {
            let regex = try NSRegularExpression(pattern: pattern)
            if let match = regex.firstMatch(in: allText, range: NSRange(allText.startIndex..., in: allText)) {
                if let range = Range(match.range(at: 1), in: allText) {
                    var deadline = String(allText[range])
                    
                    deadline = deadline.replacingOccurrences(of: "年", with: "-")
                        .replacingOccurrences(of: "月", with: "-")
                        .replacingOccurrences(of: "日", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // 如果解析出来没有年份前缀(例如 not 20xx)，则补充当前年份
                    if !deadline.hasPrefix("20") {
                        return "\(currentYear)-\(deadline)"
                    }
                    return deadline
                }
            }
        }
        
        return "暂无截止时间"
    }
    
    // MARK: - Debug: Save All Homework HTML
    public func debugSaveAllHomeworkHTML() async throws -> String {
        let url = URL(string: "https://mooc1-api.chaoxing.com/work/stu-work")!
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "XXTService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode HTML"])
        }
        
        // Write to a temporary file for analysis
        let filePath = "/tmp/stu-work.html"
        try html.write(toFile: filePath, atomically: true, encoding: .utf8)
        return filePath
    }

    // MARK: - Debug: Save All Exams HTML
    public func debugSaveAllExamsHTML() async throws -> String {
        let url = URL(string: "https://mooc1-api.chaoxing.com/exam-ans/exam/phone/examcode")!
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "XXTService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode HTML"])
        }
        
        // Write to a temporary file for analysis
        let filePath = "/tmp/exams.html"
        try html.write(toFile: filePath, atomically: true, encoding: .utf8)
        return filePath
    }
    
    // MARK: - Fetch All Exams
    public func fetchAllExams() async throws -> [Exam] {
        print("🔍 [Exam] Starting to fetch all exams...")
        let url = URL(string: "https://mooc1-api.chaoxing.com/exam-ans/exam/phone/examcode")!
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            print("❌ [Exam] Failed to decode exam HTML")
            return []
        }
        
        let doc = try SwiftSoup.parse(html)
        let examLis = try doc.select("li[onclick^=goTask], li[data]")
        print("🔍 [Exam] Found \(examLis.size()) exam list items in HTML. Total HTML Length: \(html.count)")
        
        if examLis.isEmpty() {
            print("⚠️ [Exam] No items found with selector 'li[onclick^=goTask], li[data]'. Printing snippet of body:")
            print(try doc.body()?.html().prefix(1000) ?? "No body")
        } else {
            print("🔍 [Exam] First item snippet: \(try examLis.first()?.outerHtml().prefix(500) ?? "Empty")")
        }
        
        var tempExamData: [(id: String, name: String, status: String, courseName: String, deadline: String, courseId: String, detailUrl: String)] = []
        var needsCourseRepair = false
        
        for li in examLis {
            let dataUrl = (try? li.attr("data")) ?? ""
            if dataUrl.isEmpty { continue }

            // 从 <dt> 获取考试名称
            let name = try li.select("dt").first()?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? "未知考试"
            
            // 从 <span class="ks_state"> 获取状态
            var status = try li.select("span.ks_state").first()?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            // 如果 ks_state 没拿到，尝试从 aria-label 兜底
            if status.isEmpty, let dl = try li.select("dl[aria-label]").first() {
                let ariaLabel = try dl.attr("aria-label")
                if let range = ariaLabel.range(of: "考试状态：") {
                    let after = ariaLabel[range.upperBound...]
                    if let endIdx = after.firstIndex(of: ";") {
                        status = String(after[..<endIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        status = String(after).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
            
            // 默认课程名（HTML snippet 中通常不直接包含课程名，后续靠NeedsCourseRepair修复）
            var courseName = "未知课程"
            
            if name.contains("...") || name.hasSuffix("…") {
                needsCourseRepair = true
            }
            
            var deadline = "暂无截止时间"
            // 尝试在 li 查找可能的时间显示
            if let timeSpan = try li.select("span.fr, span.time").first() {
                deadline = try timeSpan.text()
            }
            
            var examId = UUID().uuidString
            var courseId = ""
            
            // 关键：从 data 属性解析 ID
            let cleanUrl = dataUrl.replacingOccurrences(of: "&amp;", with: "&")
            if let urlComponents = URLComponents(string: cleanUrl) {
                // 考试列表中通常是 taskrefId
                examId = urlComponents.queryItems?.first(where: { $0.name == "taskrefId" })?.value ??
                         urlComponents.queryItems?.first(where: { $0.name == "examId" })?.value ??
                         UUID().uuidString
                         
                courseId = urlComponents.queryItems?.first(where: { $0.name.caseInsensitiveCompare("courseid") == .orderedSame })?.value ?? ""
            }
            
            tempExamData.append((id: examId, name: name, status: status, courseName: courseName, deadline: deadline, courseId: courseId, detailUrl: cleanUrl))
            print("📝 [Exam] Parsed exam: \(name) | Status: \(status) | cId: \(courseId)")
        }
        
        var courseMap: [String: String] = [:]
        // 考试列表一般没有课程名，需要全量使用课程列表映射
        needsCourseRepair = true
        if needsCourseRepair {
            print("🔍 [Exam] Needs course name mapping, fetching full course list...")
            if let fullCourses = try? await fetchCourses() {
                for c in fullCourses {
                    if let cURL = URLComponents(string: c.url),
                       let realId = cURL.queryItems?.first(where: { $0.name.caseInsensitiveCompare("courseid") == .orderedSame })?.value {
                        courseMap[realId] = c.name
                    }
                }
                print("🔍 [Exam] Course map built with \(courseMap.count) entries.")
            }
        }
        
        var exams: [Exam] = []
        let savedExams = Exam.loadExams()
        let unfinishedStatuses = ["待考试", "进行中", "未完成", "未开始"]
        
        for item in tempExamData {
            let finalCourseName = courseMap[item.courseId] ?? item.courseName
            var finalDeadline = item.deadline
            var isPrecise = false
            
            if let saved = savedExams.first(where: { $0.id == item.id }), saved.status == item.status && saved.isPreciseDeadline {
                finalDeadline = saved.deadline
                isPrecise = true
            }
            
            // Only fetch for unfinished items and if not already precise
            if !isPrecise && unfinishedStatuses.contains(where: { item.status.contains($0) }) {
                print("🕸️ [Exam] Fetching precise deadline for exam: \(item.name)")
                if let exactDeadline = try? await fetchExamDeadline(detailUrl: item.detailUrl), exactDeadline != "暂无截止时间" {
                    finalDeadline = exactDeadline
                    isPrecise = true
                    print("✅ [Exam] Got precise deadline: \(exactDeadline)")
                }
            }

            // Fallback for "Remaining time" text
            if finalDeadline.contains("剩余") {
                let raw = finalDeadline
                let daysMatch = raw.range(of: #"(\d+)天"#, options: .regularExpression)
                let hoursMatch = raw.range(of: #"(\d+)小时"#, options: .regularExpression)
                let minutesMatch = raw.range(of: #"(\d+)分钟?"#, options: .regularExpression)
                var totalSeconds: TimeInterval = 0
                if let range = daysMatch {
                    totalSeconds += (Double(raw[range].replacingOccurrences(of: "天", with: "")) ?? 0) * 86400
                }
                if let range = hoursMatch {
                    totalSeconds += (Double(raw[range].replacingOccurrences(of: "小时", with: "")) ?? 0) * 3600
                }
                if let range = minutesMatch {
                    totalSeconds += (Double(raw[range].replacingOccurrences(of: "分", with: "").replacingOccurrences(of: "钟", with: "")) ?? 0) * 60
                }
                if totalSeconds > 0 {
                    let expireDate = Date().addingTimeInterval(totalSeconds)
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm"
                    finalDeadline = formatter.string(from: expireDate)
                }
            }
            
            exams.append(Exam(id: item.id, name: item.name, status: item.status, courseName: finalCourseName, courseId: item.courseId, deadline: finalDeadline, detailUrl: item.detailUrl, isPreciseDeadline: isPrecise))
        }
        
        print("🏁 [Exam] Finished fetching exams. Total parsed: \(exams.count)")
        return exams
    }

    public func updateExamDeadline(for exam: Exam) async throws -> Exam {
        guard let url = exam.detailUrl, !url.isEmpty else { return exam }
        let newDeadline = try await fetchExamDeadline(detailUrl: url)
        var isPrecise = exam.isPreciseDeadline
        var deadline = newDeadline
        if newDeadline != "暂无截止时间" {
            isPrecise = true
        } else if exam.deadline != "暂无截止时间" {
            deadline = exam.deadline
        }
        
        return Exam(id: exam.id, name: exam.name, status: exam.status, courseName: exam.courseName, courseId: exam.courseId, deadline: deadline, detailUrl: exam.detailUrl, isPreciseDeadline: isPrecise)
    }

    private func fetchExamDeadline(detailUrl: String) async throws -> String {
        var finalUrlStr = detailUrl
        if !detailUrl.lowercased().hasPrefix("http") {
             finalUrlStr = "https://mooc1.chaoxing.com" + (detailUrl.hasPrefix("/") ? "" : "/") + detailUrl
        }
        guard let url = URL(string: finalUrlStr) else { return "暂无截止时间" }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else { return "暂无截止时间" }
        let doc = try SwiftSoup.parse(html)
        let currentYear = Calendar.current.component(.year, from: Date())

        // Logic for Exam Detail Scraper
        // 1. Check for specific time elements in Exam page
        if let timeElement = try doc.select("span#endTime, .endTime, .time").first() {
             let text = try timeElement.text().trimmingCharacters(in: .whitespacesAndNewlines)
             if !text.isEmpty && text.range(of: #"(\d+)"#, options: .regularExpression) != nil {
                 return text.hasPrefix("20") ? text : "\(currentYear)-\(text)"
             }
        }

        // 2. Generic regex match in full text
        let allText = try doc.text()
        let patterns = [
            "截止时间[:：]?\\s*(\\d{4}[-年]\\d{1,2}[-月]\\d{1,2}[日]?\\s+\\d{1,2}:\\d{2})",
            "结束时间[:：]?\\s*(\\d{4}[-年]\\d{1,2}[-月]\\d{1,2}[日]?\\s+\\d{1,2}:\\d{2})",
            "至\\s*(\\d{1,2}[-月]\\d{1,2}[日]?\\s+\\d{1,2}:\\d{2})",
            "截止[:：]?\\s*(\\d{1,2}[-月]\\d{1,2}[日]?\\s+\\d{1,2}:\\d{2})"
        ]

        for pattern in patterns {
            let regex = try NSRegularExpression(pattern: pattern)
            if let match = regex.firstMatch(in: allText, range: NSRange(allText.startIndex..., in: allText)) {
                if let range = Range(match.range(at: 1), in: allText) {
                    var d = String(allText[range]).replacingOccurrences(of: "年", with: "-").replacingOccurrences(of: "月", with: "-").replacingOccurrences(of: "日", with: "")
                    return d.hasPrefix("20") ? d : "\(currentYear)-\(d)"
                }
            }
        }
        
        return "暂无截止时间"
    }
}
