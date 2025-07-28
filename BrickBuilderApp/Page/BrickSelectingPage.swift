import SwiftUI

// MARK: - Page
struct BrickSelectingPage: View {
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            VStack{
                Text("Hello, I'm BrickSeclectingPage")
            }
            
            Button("完成") {
                dismiss() // 点击后关闭这个全屏页面
            }
            .padding()
            .background(.white)
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color(hex: "#FFFFF8"))
    }
}
