import SwiftUI
import ReplayKit

/// System ka broadcast picker button (isi se extension start hota hai).
struct BroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 90, height: 90))
        // Yuno USB Mirror Extension Bundle ID
        picker.preferredExtension = "com.yuno.USBMirror.BroadcastExtension"
        picker.showsMicrophoneButton = false
        return picker
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("USB Mirror").font(.largeTitle).bold()
            Text("1. iPhone ko USB se PC me lagao\n2. Neeche wala button dabao\n3. 'Start Broadcast' dabao\n4. PC par mirror_viewer.py chalao")
                .multilineTextAlignment(.center)
            BroadcastPicker().frame(width: 90, height: 90)
        }
        .padding()
    }
}
