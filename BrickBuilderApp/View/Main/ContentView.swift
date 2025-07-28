import SwiftUI
import SceneKit

enum MainTab {
    case buildPage
    case savesPage
}

extension Color {
    var hsb: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b, a)
    }

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
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - View
struct ContentView: View{
    
    enum PresentedSheet {
        case ground, blocks
    }
    
    @StateObject private var sceneCoordinator = SceneCoordinator()
    
    @State private var currentTab: MainTab = .buildPage
    @State private var isSettingsPanelPresented = false
    @State private var sheetToPresent: PresentedSheet?
    
    @State private var showingGroundSettings = false
    @State private var showingBrickSettings = false

    
    var body: some View{
        ZStack(alignment: .top) {
            // 根据当前选择展示页面，默认buildPage为主页面
            if currentTab == .buildPage {
                BuildPage(sceneCoordinator: sceneCoordinator,
                          showGroundSettings:{showingGroundSettings = true},
                          showBrickSettings:{showingBrickSettings = true}
                )
            }else if currentTab == .savesPage {
                SavesPage()
            }
            
            // 底部导航栏
            VStack{
                Spacer()
                BottomNavbarComponent(currentTab: $currentTab)
            }
            .ignoresSafeArea()
            
            // 其他设置页面
            .fullScreenCover(isPresented: $showingGroundSettings) {
                GroundSettingPage(sceneCoordinator: sceneCoordinator)
            }
            .fullScreenCover(isPresented: $showingBrickSettings) {
                BrickSelectingPage()
            }
        }
    }
}

// MARK: - Custom Components
struct BottomNavbarComponent: View {
    
    @Binding var currentTab: MainTab
    private let navBarColor = Color(hex: "#FFFFF8")
    private let buttonColor = Color(hex: "#3A3A3A")
    private let borderColor = Color(hex: "#D6D6D2")
    
    var body: some View {
        ZStack {}
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    GeometryReader { geometry in
                        VStack(alignment: .leading, spacing: 0.0) {
                            // 底部导航栏
                            HStack(alignment: .top) {
                                // 搭建页面按钮
                                VStack{
                                    Button(action: { currentTab = .buildPage }) {
                                        VStack {
                                            Image(systemName: "hammer.fill")
                                                .font(.title3)
                                            Text("搭建")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(buttonColor.opacity(currentTab == .buildPage ? 1.0 : 0.5))
                                    }
                                }
                                .frame(width: geometry.size.width * 0.25, height: 90.0)
                                .clipped()
                                
                                // 空按钮
                                VStack{
                                    
                                }
                                .frame(width: geometry.size.width * 0.25, height: 90.0)
                                .clipped()
                                
                                // 空按钮
                                VStack{
                                    
                                }
                                .frame(width: geometry.size.width * 0.25, height: 90.0)
                                .clipped()
                                
                                // 存档页面按钮
                                VStack{
                                    Button(action: { currentTab = .savesPage }) {
                                        VStack {
                                            Image(systemName: "folder.fill")
                                                .font(.title3)
                                            Text("存档")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(buttonColor.opacity(currentTab == .savesPage ? 1.0 : 0.5))
                                    }
                                }
                                .frame(width: geometry.size.width * 0.25, height: 90.0)
                                .clipped()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 150.0, alignment: .top)
                            .background(navBarColor, ignoresSafeAreaEdges: [])
                            .clipShape(
                                RoundedRectangle(cornerRadius: 40.0, style: .circular))
                            .overlay {
                                RoundedRectangle(cornerRadius: 40.0, style: .circular)
                                    .stroke(borderColor)
                            }
                            .offset(y: geometry.size.height * 0.4)
                        }
                        .frame(minWidth: geometry.size.width, minHeight: geometry.size.height,alignment: .bottom)
                        .clipped()
                        .zIndex(10.0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 150.0)
                }
            }
            .ignoresSafeArea(edges: .all)
    }
}


#Preview {
    ContentView()
}
