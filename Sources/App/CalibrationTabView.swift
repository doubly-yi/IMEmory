import SwiftUI
import IMEmoryCore

/// Tab2:每个输入法的模板校准状态 + 进入校准向导入口。
struct CalibrationTabView: View {
    @EnvironmentObject var state: AppState
    @State private var wizardDef: IMEDef?
    @State private var refreshTick = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("输入法模板").font(.headline)
            ForEach(IMERegistry.all) { def in
                HStack {
                    Text(def.displayName)
                    Spacer()
                    Text(statusText(def))
                        .foregroundStyle(missing(def).isEmpty ? .green : .orange)
                    Button("校准…") { wizardDef = def }
                }
            }
            Text("说明:每个输入法在系统浅色、深色下各校准一次。")
                .font(.footnote).foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .id(refreshTick)
        .sheet(item: $wizardDef, onDismiss: { refreshTick += 1 }) { def in
            CalibrationWizardView(def: def).environmentObject(state)
        }
    }

    private func missing(_ def: IMEDef) -> [Appearance] {
        CalibrationStatus.missing(store: state.controller.templates, def: def)
    }

    private func statusText(_ def: IMEDef) -> String {
        let m = missing(def)
        if m.isEmpty { return "✅ 浅/深已校准" }
        let names = m.map { $0 == .light ? "浅色" : "深色" }.joined(separator: "、")
        return "⚠️ 待校准:\(names)"
    }
}
