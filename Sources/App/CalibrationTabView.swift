import SwiftUI
import IMEmoryCore

/// Tab2:每个系统输入法的模板校准状态 + 进入校准向导入口。
struct CalibrationTabView: View {
    @EnvironmentObject var state: AppState
    @State private var wizard: InputSourceEnumerator.Entry?
    @State private var refreshTick = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("输入法模板").font(.headline)
            ForEach(InputSourceEnumerator.selectableInputModes()) { e in
                HStack {
                    Text(e.displayName)
                    Spacer()
                    Text(statusText(e.sourceID))
                        .foregroundStyle(missing(e.sourceID).isEmpty ? .green : .orange)
                    Button("校准…") { wizard = e }
                }
            }
            Text("说明:每个输入法在系统浅色、深色下各校准一次。列表为系统当前已安装的输入法。")
                .font(.footnote).foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .id(refreshTick)
        .sheet(item: $wizard, onDismiss: { refreshTick += 1 }) { e in
            CalibrationWizardView(sourceID: e.sourceID, displayName: e.displayName)
                .environmentObject(state)
        }
    }

    private func missing(_ sourceID: String) -> [Appearance] {
        CalibrationStatus.missing(store: state.controller.templates, sourceID: sourceID)
    }

    private func statusText(_ sourceID: String) -> String {
        let m = missing(sourceID)
        if m.isEmpty { return "✅ 浅/深已校准" }
        let names = m.map { $0 == .light ? "浅色" : "深色" }.joined(separator: "、")
        return "⚠️ 待校准:\(names)"
    }
}
