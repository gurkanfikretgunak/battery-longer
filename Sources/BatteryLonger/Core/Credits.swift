import Foundation

/// Who made this.
enum Credits {
    static let appName = "Battery Longer"

    static let authorName = "Gürkan Fikret Günak"
    static let authorHandle = "gurkanfikretgunak"
    static let authorGitHub = URL(string: "https://github.com/gurkanfikretgunak")!

    static let companyName = "MasterFabric LLC"
    static let companyHandle = "MasterFabric"
    static let companyGitHub = URL(string: "https://github.com/MasterFabric")!

    static let repositoryPath = "gurkanfikretgunak/battery-longer"
    static let repository = URL(string: "https://github.com/\(repositoryPath)")!

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    static var copyright: String {
        "© \(Calendar.current.component(.year, from: Date())) \(companyName)"
    }
}
