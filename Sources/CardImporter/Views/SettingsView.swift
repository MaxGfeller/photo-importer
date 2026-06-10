import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Text("The import ledger is stored at ~/Library/Application Support/CardImporter/imports.sqlite.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 420)
    }
}
