import SwiftUI
import LiuYaoCore

struct ClassicsReferenceView: View {
    @State private var library: ClassicsKnowledge?
    @State private var loading = true
    var body: some View {
        List {
            if loading {
                ProgressView("正在读取古籍目录…")
            } else if let library {
                Section("六爻古籍经典合集") {
                    Text("\(library.books.count) 部典籍，\(library.pageCount) 页").font(.headline)
                        .accessibilityIdentifier("classics-status")
                    Text("已建立本机参考索引。解卦时按事项和卦象选择相关段落，保留完整分析与一句话总结。")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                }
                Section("已导入") {
                    ForEach(library.books) { book in
                        VStack(alignment: .leading, spacing: 5) {
                            Text("《\(book.title)》").font(.headline)
                            Text("合集 PDF 第 \(book.startPage)–\(book.endPage) 页").font(.caption).foregroundStyle(Theme.muted)
                        }.padding(.vertical, 4)
                    }
                }
                Section("如何使用") {
                    Text("优先参考《增删卜易》《卜筮正宗》的取用、日月及动变论述，其他典籍保留各自观点。合集含后人按语，解读须区分原典与注释。")
                    Text("AI 回答下方可展开本卦参考书摘，核对原文、书名和页码。页码按这份合集的 PDF 页序，不同于其他版本。")
                    Text("这是解卦时查阅参考资料，不是训练或永久修改 DeepSeek 模型。古籍中的历史卦例不代表当前事项必然发生。")
                }.font(.subheadline).foregroundStyle(Theme.muted)
            } else {
                Text("公开版未附带书籍正文。请按项目 README 导入你有权使用的 PDF，重新构建后启用古籍参考。")
                    .accessibilityIdentifier("classics-empty")
                    .foregroundStyle(Theme.muted)
            }
        }.scrollContentBackground(.hidden).background(Theme.paper).foregroundStyle(Theme.ink)
            .navigationTitle("古籍资料").navigationBarTitleDisplayMode(.inline)
            .task { library = await Task.detached { ClassicsKnowledge.bundled }.value; loading = false }
    }
}

struct KnowledgeSourcesView: View {
    let references: [KnowledgeExcerpt]
    var body: some View {
        DisclosureGroup("本卦参考书摘（\(references.count) 段）") {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(references) { reference in
                    VStack(alignment: .leading, spacing: 7) {
                        Text("《\(reference.book)》\(reference.chapter)").font(.subheadline.weight(.semibold))
                        Text("合集 PDF 第 \(reference.pdfPage) 页 [\(reference.id)]").font(.caption).foregroundStyle(Theme.accent)
                        Text(reference.text).font(.subheadline).lineSpacing(5).textSelection(.enabled)
                    }
                }
            }.padding(.top, 12)
        }.font(.subheadline).accessibilityIdentifier("knowledge-sources")
    }
}
