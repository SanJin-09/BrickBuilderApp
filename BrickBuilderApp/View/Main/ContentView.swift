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

// MARK: - ContentView
struct ContentView: View {
    // 状态管理
    @StateObject private var sceneCoordinator = SceneCoordinator()
    @State private var showingGroundSettings = false
    @State private var showingBrickSettings = false
    
    // UI颜色常量
    private let textColor = Color(hex: "#1f2b2e")
    
    var body: some View {
        ZStack {
            // 3D 场景视图
            SceneView(
                scene: sceneCoordinator.scene,
                pointOfView: sceneCoordinator.cameraNode,
                options: [.allowsCameraControl]
            )
            .ignoresSafeArea()
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        sceneCoordinator.handleZoom(value)
                    }
            )
            
            // UI 界面叠加层
            uiOverlay
        }
        .sheet(isPresented: $showingGroundSettings) {
            GroundSettingsView(sceneCoordinator: sceneCoordinator)
        }
        .sheet(isPresented: $showingBrickSettings) {
            BrickSettingsView(sceneCoordinator: sceneCoordinator)
        }
    }
    
    // UI 叠加层
    private var uiOverlay: some View {
        VStack(spacing: 0) {
            TopHeaderView(sceneCoordinator: sceneCoordinator, textColor: textColor)
                .padding(.horizontal)
                .padding(.top, 10)
            
            Spacer()
            
            HStack {
                FloatingActionButton(
                    icon: "square.grid.3x3.middle.filled",
                    color: Color(hex: "#267c86"),
                    action: { showingGroundSettings = true }
                )
                
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
                                template: template,
                                sceneCoordinator: sceneCoordinator,
                                textColor: textColor
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
    let template: BrickTemplate
    @ObservedObject var sceneCoordinator: SceneCoordinator
    let textColor: Color
    
    var body: some View {
        VStack(spacing: 5) {
            Text("当前砖块")
                .font(.caption)
                .foregroundColor(textColor.opacity(0.7))
            
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(template.color.uiColor))
                    .frame(width: 50, height: 50)
                    .overlay(
                        StudsPatternView(size: template.size)
                    )
                
                // 砖块信息
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
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
        }
        .background(Color(hex: "#effbfd"))
        .cornerRadius(15)
        .shadow(color: Color(hex: "#c4d1d3"), radius: 8, x: 0, y: 4)
        .gesture(
            DragGesture(coordinateSpace: .global)
                .onEnded { value in
                    sceneCoordinator.handleBrickDrop(at: value.location, with: template)
                }
        )
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
    
    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<size.height, id: \.self) { _ in
                HStack(spacing: 3) {
                    ForEach(0..<size.width, id: \.self) { _ in
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
