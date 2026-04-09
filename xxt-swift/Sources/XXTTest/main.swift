import Foundation
import XXTCore

@main
struct XXTTest {
    static func main() async {
        let service = XXTService()
        let phone = "15981825878"
        let password = "iunomywife1@"
        
        print("🚀 正在测试登录: \(phone)...")
        
        do {
            let success = try await service.login(phone: phone, pass: password)
            if success {
                print("✅ 登录成功！")
                
                print("📥 正在导出全量作业页 HTML...")
                let path = try await service.debugSaveAllHomeworkHTML()
                print("✅ HTML 已导出至: \(path)")
            } else {
                print("❌ 登录失败，请检查账号密码")
            }
        } catch {
            print("💥 运行出错: \(error.localizedDescription)")
        }
    }
}
