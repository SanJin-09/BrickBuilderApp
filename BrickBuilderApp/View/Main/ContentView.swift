import SwiftUI
import SceneKit

// MARK: - Color Extension
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

// MARK: - Data Model Extensions
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

// MARK: - View Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

// MARK: - Helper Shape
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Enums
enum MainTab {
    case build
    case saves
}

// MARK: - ContentView
struct ContentView: View {
    
    @StateObject private var sceneCoordinator = SceneCoordinator()
    
    @State private var currentTab: MainTab = .build
    @State private var isSettingsPanelPresented = false
    @State private var showingGroundSettings = false
    @State private var showingBrickSettings = false
    
    var body: some View {
        ZStack {
            mainContent
            
            bottomUIOverlay
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showingGroundSettings) {
            GroundSettingsView(sceneCoordinator: sceneCoordinator)
        }
        .sheet(isPresented: $showingBrickSettings) {
            BrickSettingsView(sceneCoordinator: sceneCoordinator)
        }
        .onDisappear {
            sceneCoordinator.deselectBrick()
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if currentTab == .build {
            BuildView(sceneCoordinator: sceneCoordinator)
        } else {
            ProjectManagementView(sceneCoordinator: sceneCoordinator)
        }
    }
    
    @ViewBuilder
    private var bottomUIOverlay: some View {
        VStack {
            Spacer()
            ZStack(alignment: .bottom) {
                BottomNavBar(currentTab: $currentTab)
                
                ZStack {
                    if isSettingsPanelPresented {
                        SettingsPanelView(
                            showGroundSettings: { showingGroundSettings = true },
                            showBrickSettings: { showingBrickSettings = true }
                        )
                        .offset(y: -120)
                        .transition(.scale(0.95, anchor: .bottom).combined(with: .opacity))
                    }
                    
                    if currentTab == .build {
                        SettingsButton(isPresented: $isSettingsPanelPresented)
                            .offset(y: -42.5)
                    }
                }
            }
        }
    }
}

// MARK: - BuildView
struct BuildView: View {
    @ObservedObject var sceneCoordinator: SceneCoordinator
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "#FFFFF8").ignoresSafeArea()
            
            CustomSceneView(sceneCoordinator: sceneCoordinator)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            sceneCoordinator.handleZoom(value)
                        }
                )
                .ignoresSafeArea(.container, edges: .bottom)
            
            uiOverlay
            
            if let pos = sceneCoordinator.deleteButtonPosition {
                DeleteButton {
                    sceneCoordinator.deleteSelectedBrick()
                }
                .position(pos)
            }
            
            toastOverlay
        }
    }
    
    private var uiOverlay: some View {
        VStack(spacing: 0) {
            TopHeaderView(sceneCoordinator: sceneCoordinator)
                .padding(.top, 60)
            Spacer()
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
    
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 32)
                .fill(Color(hex: "#3A3A3A"))
                .frame(width: 300, height: 130)
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 8)

            VStack {
                if let template = sceneCoordinator.currentBrickTemplate {
                    CurrentBrickInfoView(sceneCoordinator: sceneCoordinator, template: template)
                } else {
                    Text("未确定当前积木")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#FFFFF8"))
                }
            }
            .padding(.bottom, 50)

            BrickCountView(count: sceneCoordinator.brickCount)
                .offset(y: -10)
        }
    }
}

// MARK: - BottomNavBar
struct BottomNavBar: View {
    @Binding var currentTab: MainTab
    private let navBarColor = Color(hex: "#FFFFF8")
    private let itemColor = Color(hex: "#3A3A3A")
    private let borderColor = Color(hex: "#D6D6D2")

    var body: some View {
        HStack {
            Button(action: { currentTab = .build }) {
                VStack(spacing: 4) {
                    Image(systemName: "hammer.fill")
                        .font(.title3)
                    Text("搭建")
                        .font(.caption2)
                }
                .foregroundColor(itemColor.opacity(currentTab == .build ? 1.0 : 0.5))
            }
            
            Spacer()
            
            Button(action: { currentTab = .saves }) {
                VStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.title3)
                    Text("存档")
                        .font(.caption2)
                }
                 .foregroundColor(itemColor.opacity(currentTab == .saves ? 1.0 : 0.5))
            }
        }
        .frame(height: 85)
        .padding(.horizontal, 50)
        .background(navBarColor)
        .cornerRadius(35, corners: [.topLeft, .topRight])
        .overlay(
            RoundedCorner(radius: 35, corners: [.topLeft, .topRight])
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 5, y: -5)
    }
}

// MARK: - SettingsButton
struct SettingsButton: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isPresented.toggle()
            }
        }) {
            ZStack {
                CenterButtonIcon()
                    .foregroundColor(Color(hex: "#FFFFF8"))
                    .opacity(isPresented ? 0 : 1)
                
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "#FFFFF8"))
                    .opacity(isPresented ? 1 : 0)
            }
            .frame(width: 60, height: 60)
            .background(Color(hex: "#3A3A3A"))
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
            .rotationEffect(.degrees(isPresented ? 90 : 0))
        }
    }
}

// MARK: - CenterButtonIcon
struct CenterButtonIcon: View {
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .black))
                Image(systemName: "triangle.fill")
                    .font(.system(size: 9))
            }
            HStack(spacing: 4) {
                Circle().stroke(lineWidth: 2).frame(width: 10, height: 10)
                Rectangle().stroke(lineWidth: 2).frame(width: 10, height: 10)
            }
        }
    }
}

// MARK: - SettingsPanelView
struct SettingsPanelView: View {
    let showGroundSettings: () -> Void
    let showBrickSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            Button(action: showGroundSettings) {
                HStack(spacing: 15) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 25)
                    Text("地面设置")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                }
            }
            
            Button(action: showBrickSettings) {
                HStack(spacing: 15) {
                    Image(systemName: "hexagon.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 25)
                    Text("积木设置")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                }
            }
            Spacer()
        }
        .padding(.top, 40)
        .padding(.horizontal, 20)
        .frame(width: 180, height: 200)
        .background(Color(hex: "#3A3A3A"))
        .foregroundColor(Color(hex: "#FFFFF8"))
        .cornerRadius(32)
        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 0)
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

// MARK: - CurrentBrickInfoView
struct CurrentBrickInfoView: View {
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
                    .overlay(StudsPatternView(size: template.size, rotation: sceneCoordinator.currentRotation))
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

// MARK: - DeleteButton
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

// MARK: - BrickCountView
struct BrickCountView: View {
    let count: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "shippingbox.circle.fill")
            Text("积木数: \(count)")
        }
        .font(.footnote).fontWeight(.medium)
        .foregroundColor(Color(hex: "#3A3A3A"))
        .padding(.horizontal, 15).padding(.vertical, 8)
        .background(Color(hex: "#FFFFF8"))
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
}

// MARK: - StudsPatternView
struct StudsPatternView: View {
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


#Preview {
    ContentView()
}
