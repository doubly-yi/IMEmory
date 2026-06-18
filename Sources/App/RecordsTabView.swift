import SwiftUI
import UniformTypeIdentifiers
import IMEmoryCore
import Combine

/// 更新时间显示格式:yyyy年MM月dd日 HH:mm。
private let recordDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy年MM月dd日 HH:mm"
    return f
}()

/// Tab1:已记录 / 排除的应用统一列表(删除/排除),实时刷新。
struct RecordsTabView: View {
    @EnvironmentObject var state: AppState
    @State private var rows: [AppRow] = []

    // 监听 store 变更通知,一变就刷新(后台自动切换写入新记录时立即反映,无需轮询)。
    private let storeChanged = NotificationCenter.default
        .publisher(for: .imemoryStoreChanged).receive(on: RunLoop.main)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("已记录 / 排除的应用").font(.headline)
                Spacer()
                Button("添加") { addExcluded() }
            }
            Table(rows) {
                // 应用列不设宽度→自适应占满剩余空间,避免横向滚动条。
                TableColumn("应用") { r in Text(r.displayName) }
                TableColumn("状态") { r in
                    Text(r.mode.map { ModeGlyph.symbol(for: $0) } ?? "—")
                }
                .width(40)
                TableColumn("更新时间") { r in
                    Text(r.updatedAt.map { recordDateFormatter.string(from: $0) } ?? "—")
                }
                .width(150)
                TableColumn("排除") { r in
                    Toggle("", isOn: Binding(
                        get: { r.excluded },
                        set: { state.controller.store.setExcluded(r.bundleId, $0); reload() }))
                        .labelsHidden()
                }
                .width(40)
                TableColumn("操作") { r in
                    Button(role: .destructive) {
                        state.controller.store.delete(bundleId: r.bundleId)
                        state.controller.store.setExcluded(r.bundleId, false)
                        reload()
                    } label: { Text("删除") }
                    .buttonStyle(.bordered)
                }
                .width(64)
            }
            .frame(maxHeight: .infinity)
            Text("勾「排除」= 该 App 不自动切换;「删除」= 同时清掉记录与排除。")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding()
        .onAppear(perform: reload)
        .onReceive(storeChanged) { _ in reload() }
    }

    private func reload() {
        let newRows = AppListPresenter.rows(
            records: state.controller.store.allRecords(),
            excluded: state.controller.store.excludedList(),
            displayName: { AppInfoUI.displayName(forBundleId: $0) })
        // 内容没变就不重建表格,避免定时刷新把正在滚动的列表打乱(最后一行够不到)。
        if newRows != rows { rows = newRows }
    }

    private func addExcluded() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url,
           let bid = Bundle(url: url)?.bundleIdentifier {
            state.controller.store.setExcluded(bid, true)
            reload()
        }
    }
}
