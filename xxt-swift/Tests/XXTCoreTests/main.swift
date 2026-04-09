import Foundation
import XXTCore

@main
struct XXTTest {
    static func main() async {
        let service = XXTService()
        let phone = "15515777079"
        let password = "Ruipeng2025"
        
        print("🚀 正在测试登录: \(phone)...")
        
        do {
            let success = try await service.login(phone: phone, pass: password)
            if success {
                print("✅ 登录成功！")
                
                print("📚 正在获取课程列表...")
                let courses = try await service.fetchCourses()
                print("找到 \(courses.count) 个课程")
                
                var totalHomeworkCount = 0
                for course in courses {
                    print("📖 正在获取课程作业: \(course.name)...")
                    let homeworks = try await service.fetchHomework(for: course)
                    print("  - 找到 \(homeworks.count) 个作业")
                    totalHomeworkCount += homeworks.count
                    
                    for hw in homeworks.prefix(3) {
                        print("    - [\(hw.status)] \(hw.name) (截止: \(hw.deadline))")
                    }
                }
                print("\n✅ 所有课程作业获取完成，总计 \(totalHomeworkCount) 个作业")
            } else {
                print("❌ 登录失败，请检查账号密码")
            }
        } catch {
            print("💥 运行出错: \(error.localizedDescription)")
        }
    }
}
