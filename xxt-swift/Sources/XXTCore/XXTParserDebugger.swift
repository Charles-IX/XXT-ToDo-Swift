import Foundation
import SwiftSoup

public final class XXTParserDebugger {
    
    /// 抓取并分析课程页面结构
    public static func analyzeCoursePage(html: String) {
        print("--------------------------------------------------")
        print("🔍 [XXTDebugger] Starting HTML structure analysis...")
        print("📄 [XXTDebugger] HTML length: \(html.count)")
        
        do {
            let doc = try SwiftSoup.parse(html)
            
            // 1. 保存到本地文件供人工检查
            let filePath = "/tmp/xxt_course_list.html"
            try html.write(toFile: filePath, atomically: true, encoding: .utf8)
            print("📄 [XXTDebugger] RAW HTML saved to: \(filePath)")
            
            // 2. 扫描可能的文件夹特征
            print("📁 [XXTDebugger] Scanning for folder patterns...")
            let possibleFolders = try doc.select("div, li, ul").filter { el in
                let className = try el.className().lowercased()
                let id = try el.id().lowercased()
                let onclick = try el.attr("onclick").lowercased()
                return className.contains("folder") || id.contains("folder") || onclick.contains("folder") || el.hasAttr("fileid")
            }
            
            for (index, folder) in possibleFolders.enumerated() {
                print("  [\(index)] Tag: <\(folder.tagName())> | Class: '\(try folder.className())' | ID: '\(try folder.id())' | fileid: '\(try folder.attr("fileid"))'")
                print("      Text: \(try folder.ownText())")
            }
            
            // 3. 打印简易 DOM 树 (仅限 body 下的前几层)
            print("🌳 [XXTDebugger] Partial DOM Tree:")
            if let body = doc.body() {
                printNode(body, depth: 0)
            }
            
        } catch {
            print("❌ [XXTDebugger] Analysis failed: \(error)")
        }
        print("--------------------------------------------------")
    }
    
    private static func printNode(_ element: Element, depth: Int) {
        if depth > 5 { return } // 限制深度，防止日志爆炸
        
        let indent = String(repeating: "  ", count: depth)
        let tag = element.tagName()
        let className = (try? element.className()) ?? ""
        let id = (try? element.id()) ?? ""
        
        if !className.isEmpty || !id.isEmpty {
            print("\(indent)[\(tag.uppercased())] class='\(className)' id='\(id)'")
        }
        
        for child in element.children() {
            printNode(child, depth: depth + 1)
        }
    }
}
