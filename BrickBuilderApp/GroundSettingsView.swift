import SwiftUI

struct GroundSettingsView: View {
    @ObservedObject var sceneCoordinator: SceneCoordinator
    @Environment(\.dismiss) private var dismiss
    
    @State private var groundWidth: Double = 8
    @State private var groundLength: Double = 8
    @State private var selectedColor: GroundColor = .gray
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("地面设置")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("尺寸设置")
                        .font(.headline)
                    
                    HStack {
                        Text("宽度: \(Int(groundWidth))")
                            .frame(width: 80, alignment: .leading)
                        
                        Slider(value: $groundWidth, in: 1...100, step: 2)
                    }
                    
                    HStack {
                        Text("长度: \(Int(groundLength))")
                            .frame(width: 80, alignment: .leading)
                        
                        Slider(value: $groundLength, in: 1...100, step: 2)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("颜色设置")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                        ForEach(GroundColor.allCases, id: \.self) { color in
                            Button(action: {
                                selectedColor = color
                            }) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(color.uiColor))
                                    .frame(height: 40)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedColor == color ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                Spacer()
                
                Button(action: {
                    sceneCoordinator.updateGround(
                        width: Int(groundWidth),
                        length: Int(groundLength),
                        color: selectedColor
                    )
                    dismiss()
                }) {
                    Text("应用设置")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.bottom)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }
}
