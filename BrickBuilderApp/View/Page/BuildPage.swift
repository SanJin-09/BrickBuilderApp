import SwiftUI
import SceneKit

// MARK: - Extensions
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
            (a, r, g, b) = (255, 0, 0, 0)
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

// MARK: - Page
struct BuildPage: View {
    
    @ObservedObject var sceneCoordinator: SceneCoordinator

    var body: some View {
        ZStack(alignment: .top) {
            // 1.渲染积木搭建区域
            CustomSceneComponent(sceneCoordinator: sceneCoordinator)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            sceneCoordinator.handleZoom(value)
                        }
                )
                .ignoresSafeArea(.container, edges: .bottom)
            
            // 2.渲染顶部组件视图
            TopInfoComponent(sceneCoordinator: sceneCoordinator)
            
            // 3.渲染中央菜单按钮
            MenuButtonComponent()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: "#FFFFF8"))
    }
}

// MARK: - Custom Components
struct CustomSceneComponent: UIViewRepresentable {
    let sceneCoordinator: SceneCoordinator
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = sceneCoordinator.scene
        scnView.pointOfView = sceneCoordinator.cameraNode
        scnView.allowsCameraControl = true
        sceneCoordinator.scnView = scnView
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        return scnView
    }
    func updateUIView(_ uiView: SCNView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(sceneCoordinator: sceneCoordinator) }
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

struct TopInfoComponent: View {
    let sceneCoordinator: SceneCoordinator
    var body: some View {
        // 1.顶部视图
        VStack(spacing: 0.0) {
            VStack {
                // 1.1 当前积木视图
                VStack{
                    if let template = sceneCoordinator.currentBrickTemplate {
                        CurrentBrickInfoComponent(sceneCoordinator: sceneCoordinator, template: template)
                    } else {
                        Text("未确定当前积木")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#FFFFF8"))
                    }
                }
                .padding(.top, 50)
                .padding(.bottom, 20)
                
                // 1.2 积木计数器
                BrickCountComponent(count: sceneCoordinator.brickCount)
            }
            .frame(width: 300.0, height: 150.0, alignment: .top)
            .background(Color(hex: "#3A3A3A"))
            .clipShape(RoundedRectangle(cornerRadius: 32.0, style: .circular))
            .shadow(color: Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 0.65), radius: 2.0, y: 2.0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200.0)
    }
}

struct CurrentBrickInfoComponent: View {
    @ObservedObject var sceneCoordinator: SceneCoordinator
    @State private var isDragging = false
    let template: BrickTemplate
    
    private let textColor = Color(hex: "#FFFFF8")

    var body: some View {
        HStack(spacing: 15) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(template.color.uiColor))
                    .frame(width: 50, height: 50)
                    .overlay(StudsPatternComponent(size: template.size, rotation: sceneCoordinator.currentRotation))
                VStack(alignment: .leading) {
                    Text(template.size.displayName)
                        .font(.headline).fontWeight(.bold).foregroundColor(textColor)
                    Text(template.color.displayName)
                        .font(.subheadline).foregroundColor(textColor.opacity(0.8))
                }
            }
            
            Rectangle().fill(textColor.opacity(0.5)).frame(width: 1, height: 40)
            
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                sceneCoordinator.rotateCurrentBrick()
            }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title).foregroundColor(textColor).frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .gesture(
            DragGesture(coordinateSpace: .global)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
                    if let scnView = sceneCoordinator.scnView {
                        sceneCoordinator.handleDragUpdate(at: value.location, with: template, in: scnView)
                    }
                }
                .onEnded { value in
                    isDragging = false
                    if let scnView = sceneCoordinator.scnView {
                        sceneCoordinator.handleBrickDrop(at: value.location, with: template, in: scnView)
                    }
                }
        )
        .simultaneousGesture(TapGesture().onEnded { _ in
            if isDragging {
                isDragging = false
                sceneCoordinator.handleDragCancel()
            }
        })
    }
}

struct MenuButtonComponent: View {
    
    @State private var translateY: Double = 0.0
    @State private var cornerRadius: Double = 100.0
    @State private var hidden: Bool = false
    @State private var width: Double = 70.0
    @State private var height: Double = 70.0

    var body: some View {
        ZStack {}
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    if hidden {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // 菜单展开时，点击屏幕其他区域使菜单复原
                                collapseAnim()
                            }
                    }
                    GeometryReader { geometry in
                        VStack(spacing: 0.0) {
                            
                            // 中央菜单按钮核心
                            VStack(spacing: 0.0) {
                                
                                if hidden {
                                    // 地面设置按钮
                                    Button(action: {}) {
                                        HStack(spacing: 8.0) {
                                            Image(systemName: "square.grid.3x3.middle.filled")
                                                .font(.system(size: 26.0))
                                                .imageScale(.small)
                                            Text("地面设置")
                                                .font(.system(.headline, weight: .semibold))
                                                .foregroundStyle(Color(hex: "#FFFFF8"))
                                        }
                                        .frame(width: 160.0, height: 50.0)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .buttonBorderShape(.capsule)
                                    .tint(Color(hex: "#3A3A3A"))
                                    
                                    // 积木设置按钮
                                    Button(action: {}) {
                                        HStack(spacing: 8.0) {
                                            Image(systemName: "shippingbox.fill")
                                                .font(.system(size: 26.0))
                                                .imageScale(.small)
                                            Text("积木设置")
                                                .font(.system(.headline, weight: .semibold))
                                                .foregroundStyle(Color(hex: "#FFFFF8"))
                                        }
                                        .frame(width: 160.0, height: 50.0)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .buttonBorderShape(.capsule)
                                    .tint(Color(hex: "#3A3A3A"))
                                }
                                
                                Image(systemName: "xmark.triangle.circle.square.fill")
                                    .font(.system(size: 32.0, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#FFFFF8"))
                                    .frame(width: 50.0, height: 50.0)
                                    .opacity(hidden ? 0:1)
                            }
                            .frame(width: width, height: height, alignment: .center)
                            .background(Color(hex: "#3A3A3A"), ignoresSafeAreaEdges: [])
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .circular))
                            .shadow(color: Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 0.75), radius: 2.0, y: 2.0)
                            .offset(y: geometry.size.height * 0.18 + translateY)
                            .onTapGesture {
                                // 菜单未展开时，点击菜单按钮使菜单展开
                                if !hidden {
                                    expandAnim()
                                }
                            }
                        }
                        .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                        .clipped()
                        .zIndex(10.0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 400.0)
                    .onTapGesture {
                        if hidden {
                            collapseAnim()
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .all)
    }
    
    // 点击展开动画
    private func expandAnim() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            translateY = -65
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6).delay(0.1)) {
            cornerRadius = 32.0
            width = 160.0
            height = 200.0
        }
        hidden = true
    }
    
    // 点击还原动画
    private func collapseAnim() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            cornerRadius = 100.0
            width = 70.0
            height = 70.0
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
            translateY = 0.0
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.2)){
            hidden = false
        }
    }
}

struct DeleteButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "trash.circle.fill")
                .font(.largeTitle).symbolRenderingMode(.palette).foregroundStyle(.white, .red).shadow(radius: 5)
        }
        .transition(.scale.animation(.spring()))
    }
}

struct BrickCountComponent: View {
    let count: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "shippingbox.circle.fill")
            Text("积木数: \(count)")
        }
        .font(.footnote).fontWeight(.medium)
        .foregroundColor(Color(hex: "#3A3A3A"))
        .padding(.horizontal, 15)
        .padding(.vertical, 8)
        .background(Color(hex: "#FFFFF8"))
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
}

struct StudsPatternComponent: View {
    let size: BrickSize
    let rotation: Int
    var body: some View {
        let effectiveSize = (rotation == 1 || rotation == 3) ? BrickSize(width: size.height, height: size.width) : size
        VStack(spacing: 3) {
            ForEach(0..<effectiveSize.height, id: \.self) { _ in
                HStack(spacing: 3) {
                    ForEach(0..<effectiveSize.width, id: \.self) { _ in
                        Circle().fill(Color.white.opacity(0.5)).frame(width: 6, height: 6)
                    }
                }
            }
        }
    }
}
