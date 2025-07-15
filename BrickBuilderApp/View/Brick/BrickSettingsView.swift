import SwiftUI

struct BrickSettingsView: View {
    @ObservedObject var sceneCoordinator: SceneCoordinator
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSize: BrickSize = BrickSize.availableSizes[0]
    @State private var selectedColor: BrickColor = .red
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("积木设置")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // 尺寸选择
                VStack(alignment: .leading, spacing: 15) {
                    Text("尺寸选择")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                        ForEach(BrickSize.availableSizes, id: \.self) { size in
                            Button(action: {
                                selectedSize = size
                            }) {
                                VStack {
                                    Text(size.displayName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(height: 40)
                                .frame(maxWidth: .infinity)
                                .background(selectedSize == size ? Color.blue : Color(.systemGray5))
                                .foregroundColor(selectedSize == size ? .white : .primary)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // 颜色选择
                VStack(alignment: .leading, spacing: 15) {
                    Text("颜色选择")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                        ForEach(BrickColor.allCases, id: \.self) { color in
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
                                    .overlay(
                                        Text(color.rawValue)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(color == .white || color == .yellow ? .black : .white)
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
                    let template = BrickTemplate(size: selectedSize, color: selectedColor)
                    sceneCoordinator.setCurrentBrickTemplate(template)
                    dismiss()
                }) {
                    Text("确认选择")
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

