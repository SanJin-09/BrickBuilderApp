import SwiftUI
import SceneKit

// MARK: - Exrension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension BrickColor {
    var displayName: String {
        switch self {
        case .red: return "红色"
        case .blue: return "蓝色"
        case .yellow: return "黄色"
        case .green: return "绿色"
        case .white: return "白色"
        case .black: return "黑色"
        case .orange: return "橙色"
        case .purple: return "紫色"
        case .gray: return "灰色"
        case .brown: return "棕色"
        case .pink: return "粉色"
        case .lightBlue: return "浅蓝"
        }
    }
}

// MARK: - CustomSceneView
struct CustomSceneView: UIViewRepresentable {
    let sceneCoordinator: SceneCoordinator

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = sceneCoordinator.scene
        scnView.pointOfView = sceneCoordinator.cameraNode
        scnView.allowsCameraControl = true
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(sceneCoordinator: sceneCoordinator)
    }

    class Coordinator: NSObject {
        private var sceneCoordinator: SceneCoordinator
        init(sceneCoordinator: SceneCoordinator) { self.sceneCoordinator = sceneCoordinator }
        @objc func handleTap(_ gestureRecognize: UIGestureRecognizer) {
            let scnView = gestureRecognize.view as! SCNView
            let location = gestureRecognize.location(in: scnView)
            sceneCoordinator.handleTap(at: location, in: scnView)
        }
    }
}

// MARK: - ContentView
struct ContentView: View {
    // 状态管理
    @StateObject private var sceneCoordinator = SceneCoordinator()
    @State private var showingGroundSettings = false
    @State private var showingBrickSettings = false
    @State private var showingProjectManager = false
    
    // UI颜色常量
    private let textColor = Color(hex: "#1f2b2e")
    
    var body: some View {
        ZStack {
            // 3D 场景视图
            CustomSceneView(sceneCoordinator: sceneCoordinator)
                .ignoresSafeArea()
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            sceneCoordinator.handleZoom(value)
                        }
                )
            // UI 界面叠加层
            uiOverlay
            
            // 删除按钮
            if let pos = sceneCoordinator.deleteButtonPosition {
                DeleteButton {
                    sceneCoordinator.deleteSelectedBrick()
                }
                .position(pos)
            }
        }
        .sheet(isPresented: $showingGroundSettings) {
            GroundSettingsView(sceneCoordinator: sceneCoordinator)
        }
        .sheet(isPresented: $showingBrickSettings) {
            BrickSettingsView(sceneCoordinator: sceneCoordinator)
        }
        .sheet(isPresented: $showingProjectManager) { ProjectManagementView(sceneCoordinator: sceneCoordinator) }
        .onDisappear {
            // 清理选择状态
            sceneCoordinator.deselectBrick()
        }
        .overlay(toastOverlay)
    }
    
    // UI 叠加层
    private var uiOverlay: some View {
        VStack(spacing: 0) {
            TopHeaderView(sceneCoordinator: sceneCoordinator, textColor: textColor)
                .padding(.horizontal)
                .padding(.top, 10)
            
            Spacer()
            
            HStack(alignment: .bottom) {
                FloatingActionButton(
                    icon: "square.grid.3x3.middle.filled",
                    color: Color(hex: "#267c86"),
                    action: { showingGroundSettings = true }
                )
                Spacer()
                FloatingActionButton(icon: "folder.fill", color: Color(hex: "#f0ad4e")) { showingProjectManager = true }
                Spacer()
                FloatingActionButton(
                    icon: "shippingbox.fill",
                    color: Color(hex: "#38c3d3"),
                    action: { showingBrickSettings = true }
                )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
    }
    
    @ViewBuilder
    private var toastOverlay: some View {
        if let message = sceneCoordinator.projectMessage {
            VStack {
                Spacer()
                Text(message)
                    .padding()
                    .background(Color.black.opacity(0.75))
                    .foregroundColor(.white)
                    .font(.headline)
                    .cornerRadius(15)
                    .transition(.opacity.animation(.easeIn))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            sceneCoordinator.projectMessage = nil
                        }
                    }
            }
            .padding(.bottom, 120)
        }
    }
}

// MARK: - TopHeaderView
struct TopHeaderView: View {
    @ObservedObject var sceneCoordinator: SceneCoordinator
    let textColor: Color
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 弧形背景
            HeaderArcShape()
                .fill(Color(hex: "#38c3d3"))
                .frame(height: 180)
                .shadow(color: Color(hex: "#267c86").opacity(0.6), radius: 10, x: 0, y: 6)
                .overlay(
                    // 弧形内的内容
                    VStack(spacing: 100) {
                        if let template = sceneCoordinator.currentBrickTemplate{
                            CurrentBrickInfoView(
                                sceneCoordinator: sceneCoordinator,
                                textColor: textColor,
                                template: template,
                            )
                            .padding(.top, 50)
                        }
                        Spacer()
                    }
                )
            // 砖块数量显示
            BrickCountView(count: sceneCoordinator.brickCount, textColor: textColor)
                .offset(y: -30)
        }
        .ignoresSafeArea()
    }
}

// MARK: - CurrentBrickInfoView
struct CurrentBrickInfoView: View {
    
    @ObservedObject var sceneCoordinator: SceneCoordinator
    @State private var isDragging = false
    
    let textColor: Color
    let template: BrickTemplate
    
    var body: some View {
        VStack(spacing: 5) {
            Text("当前砖块")
                .font(.caption)
                .foregroundColor(textColor.opacity(0.7))
            
            HStack(spacing: 15) {
                // 砖块信息和预览
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(template.color.uiColor))
                        .frame(width: 50, height: 50)
                        .overlay(
                            // 传入旋转状态
                            StudsPatternView(
                                size: template.size,
                                rotation: sceneCoordinator.currentRotation
                            )
                        )
                    
                    VStack(alignment: .leading) {
                        Text(template.size.displayName)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(textColor)
                        Text(template.color.displayName)
                            .font(.subheadline)
                            .foregroundColor(textColor.opacity(0.8))
                    }
                }
                
                // 分隔线
                Rectangle()
                    .fill(Color(hex: "#c4d1d3").opacity(0.5))
                    .frame(width: 1, height: 40)
                
                // 旋转按钮
                Button(action: {
                    // 触觉反馈
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    sceneCoordinator.rotateCurrentBrick()
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title)
                        .foregroundColor(textColor)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(Color(hex: "#effbfd"))
        .cornerRadius(15)
        .shadow(color: Color(hex: "#c4d1d3"), radius: 8, x: 0, y: 4)
        .gesture(
            DragGesture(coordinateSpace: .global)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        // 触觉反馈
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
                    // 更新虚影位置
                    sceneCoordinator.handleDragUpdate(at: value.location, with: template)
                }
                .onEnded { value in
                    isDragging = false
                    // 处理放置
                    sceneCoordinator.handleBrickDrop(at: value.location, with: template)
                }
        )
        .simultaneousGesture(
            // 添加取消手势处理
            TapGesture()
                .onEnded { _ in
                    if isDragging {
                        isDragging = false
                        sceneCoordinator.handleDragCancel()
                    }
                }
        )
    }
}

struct DeleteButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "trash.circle.fill")
                .font(.largeTitle)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .red)
                .shadow(radius: 5)
        }
        .transition(.scale.animation(.spring()))
    }
}

// MARK: - BrickCountView
struct BrickCountView: View {
    let count: Int
    let textColor: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "shippingbox.circle.fill")
            Text("砖块数: \(count)")
        }
        .font(.footnote)
        .fontWeight(.medium)
        .foregroundColor(textColor)
        .padding(.horizontal, 15)
        .padding(.vertical, 8)
        .background(Color(hex: "#effbfd"))
        .cornerRadius(20)
        .shadow(color: Color(hex: "#267c86").opacity(0.7), radius: 5, x: 0, y: 3)
    }
}

// MARK: - FloatingActionButton
struct FloatingActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                .background(color)
                .clipShape(Circle())
                .shadow(color: color.opacity(0.5), radius: 10, x: 0, y: 5)
        }
    }
}

// MARK: - StudsPatternView
struct StudsPatternView: View {
    let size: BrickSize
    let rotation: Int
    
    var body: some View {
        let effectiveSize = (rotation == 1 || rotation == 3) ?
            BrickSize(width: size.height, height: size.width) : size
        
        VStack(spacing: 3) {
            ForEach(0..<effectiveSize.height, id: \.self) { _ in
                HStack(spacing: 3) {
                    ForEach(0..<effectiveSize.width, id: \.self) { _ in
                        Circle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
    }
}

// MARK: - HeaderArcShape
struct HeaderArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 40))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - 40),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    ContentView()
}
