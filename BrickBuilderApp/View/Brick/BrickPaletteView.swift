import SwiftUI
import SceneKit

struct BrickPaletteView: View {
    @ObservedObject var sceneCoordinator: SceneCoordinator
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    
    var body: some View {
        VStack {
            if let template = sceneCoordinator.currentBrickTemplate {
                HStack {
                    Text("当前砖块:")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    VStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(template.color.uiColor))
                            .frame(width: 40, height: 30)
                            .overlay(
                                Text(template.size.displayName)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(template.color == .white || template.color == .yellow ? .black : .white)
                            )
                        
                        Text(template.color.rawValue)
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .offset(dragOffset)
                    .scaleEffect(isDragging ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isDragging)
                    .gesture(
                        DragGesture(coordinateSpace: .global)
                            .onChanged { value in
                                dragOffset = value.translation
                                isDragging = true
                            }
                            .onEnded { value in
                                // 检查是否在有效的放置区域
                                sceneCoordinator.handleBrickDrop(at: value.location, with: template)
                                
                                // 重置拖拽状态
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    dragOffset = .zero
                                    isDragging = false
                                }
                            }
                    )
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
            }
        }
    }
}
