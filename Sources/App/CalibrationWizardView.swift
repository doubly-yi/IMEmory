import SwiftUI
import IMEmoryCore

/// 校准向导:引导用户按 Shift 切到中/英,逐一抓取 HUD 像素并保存为模板。
/// 一次会话采集"当前系统外观"下的中、英两套;搜狗等敏感输入法需切换系统外观后再跑一次。
struct CalibrationWizardView: View {
    let sourceID: String
    let displayName: String
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    private enum Phase { case captureZh, captureEn, done }
    @State private var phase: Phase = .captureZh
    @State private var zhSig: [Double]?
    @State private var enSig: [Double]?
    @State private var zhPreview: NSImage?
    @State private var enPreview: NSImage?
    @State private var preview: NSImage?
    @State private var hint: String = ""
    @State private var sampleText: String = ""   // 给用户点击获取输入焦点用

    private var appearance: Appearance { Appearance.current() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题 + 一句话说明
            Text("校准 \(displayName)").font(.headline)
            Text("校准 = 教 IMEmory 认识「\(displayName)」的中/英长什么样。")
                .font(.callout).foregroundStyle(.secondary)

            Divider()

            // ① 获取焦点 + 确认输入法
            Text("① 点下面输入框获取焦点,并确认已切到「\(displayName)」(用 Ctrl+空格 或地球键切换输入法):")
                .font(.callout)
            TextField("在这里点一下,再按 Shift 切中/英", text: $sampleText)
                .textFieldStyle(.roundedBorder)

            // ②/③ 分步抓取
            switch phase {
            case .captureZh:
                stepBlock(step: "第 1 步 / 共 2 步",
                          title: "按 Shift 切到【中】,让中/英小窗弹出后点按钮抓取:",
                          action: "抓取【中】样本") {
                    capture { zhSig = $0; zhPreview = preview; phase = .captureEn; preview = nil; hint = "" }
                }
            case .captureEn:
                stepBlock(step: "第 2 步 / 共 2 步",
                          title: "再按 Shift 切到【英】,点按钮抓取:",
                          action: "抓取【英】样本") {
                    capture { enSig = $0; enPreview = preview; phase = .done; preview = nil; hint = "" }
                }
            case .done:
                VStack(alignment: .leading, spacing: 8) {
                    Text("✅ 「\(displayName)」的【中】【英】两张样本都抓好了:").foregroundStyle(.green)
                    HStack(spacing: 16) { thumb("中", zhPreview); thumb("英", enPreview) }
                    Text("点【保存模板】完成校准——保存后菜单栏就能识别「\(displayName)」的中/英。不保存则本次作废。")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // 当前步刚抓到的预览
            if let preview, phase != .done {
                HStack { Text("刚抓到:").font(.caption)
                    Image(nsImage: preview).interpolation(.none).frame(width: 48, height: 48).border(.secondary) }
            }
            if !hint.isEmpty {
                Text(hint).foregroundStyle(.red).font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("取消") { dismiss() }
                Spacer()
                if phase == .done {
                    Button("保存模板") { save() }.keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private func stepBlock(step: String, title: String, action: String,
                           onCapture: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step).font(.caption.bold()).foregroundStyle(.blue)
            Text("② " + title).font(.callout)
            Button(action, action: onCapture)
        }
    }

    private func thumb(_ label: String, _ img: NSImage?) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption)
            if let img {
                Image(nsImage: img).interpolation(.none).frame(width: 48, height: 48).border(.secondary)
            } else {
                Rectangle().fill(.quaternary).frame(width: 48, height: 48)
            }
        }
    }

    /// 抓取一帧:校验当前活跃输入源==目标 → 定位 HUD → 截图 → 生成签名;失败给出提示。
    private func capture(_ store: ([Double]) -> Void) {
        let srcID = IMEResolver.currentInputSourceID()
        guard let r = IMEResolver.resolve(), r.sourceID == sourceID else {
            hint = "当前活跃输入法不是 \(displayName)。实际读到:\(srcID.isEmpty ? "(空)" : srcID)。"
                 + "请点上面输入框、在框内切到 \(displayName) 再抓取。"
            return
        }
        guard let win = HUDLocator.findOnScreen(pid: r.pid),
              let img = ScreenCapture.captureWindow(win) else {
            hint = "没找到「\(displayName)」的中英小窗。请确认刚按过 Shift 让小窗弹出、且已授予屏幕录制权限;"
                 + "若反复失败,可能这个输入法不弹提示窗,暂不支持。"
            return
        }
        preview = NSImage(cgImage: img, size: NSSize(width: img.width, height: img.height))
        store(Fingerprint.signature(img))
    }

    private func save() {
        guard let zh = zhSig, let en = enSig else { return }
        do {
            try state.controller.templates.save(zh: zh, en: en, forSource: sourceID, appearance: appearance)
            dismiss()
        } catch {
            hint = "保存失败:\(error.localizedDescription)"
        }
    }
}
