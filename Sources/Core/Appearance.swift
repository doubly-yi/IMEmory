import CoreFoundation

public enum Appearance: String {
    case light
    case dark

    /// 实时读取当前系统外观(每次调用都会重新同步)。
    public static func current() -> Appearance {
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        let v = CFPreferencesCopyAppValue("AppleInterfaceStyle" as CFString,
                                          kCFPreferencesAnyApplication) as? String
        return v == "Dark" ? .dark : .light
    }
}
