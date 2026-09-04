import SwiftUI

struct PanelSwitchEditorView: View {
    let isOn: Binding<Bool>

    var body: some View {
        Toggle("", isOn: isOn)
            .toggleStyle(.switch)
            .labelsHidden()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
