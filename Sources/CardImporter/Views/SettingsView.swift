import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Text("Ledger files are stored in each destination under .card-importer/imports.sqlite.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 420)
    }
}
