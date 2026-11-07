import Foundation

/// What the About screen says, read from the app's Info.plist. The build step stamps the build number and
/// `SaltmarshBuilt` with the date and time of the build; a build without the stamp leaves that line out.
public enum About {
    public static let builtKey = "SaltmarshBuilt"

    public static func lines(info: [String: Any]) -> [String] {
        var lines = [Strings.appName]
        if let version = info["CFBundleShortVersionString"] as? String { lines.append(Strings.aboutVersion(version)) }
        if let build = info["CFBundleVersion"] as? String { lines.append(Strings.aboutBuild(build)) }
        if let built = info[builtKey] as? String { lines.append(Strings.aboutBuilt(built)) }
        return lines
    }
}
