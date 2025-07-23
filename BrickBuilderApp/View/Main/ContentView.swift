import SwiftUI
import SceneKit

enum MainTab {
    case buildPage
    case savesPage
}

// MARK: - View
struct ContentView: View{
    
    @StateObject private var sceneCoordinator = SceneCoordinator()
    
    @State private var currentTab: MainTab = .buildPage
    @State private var isSettingsPanelPresented = false
    
    var body: some View{
        ZStack(alignment: .top) {
            // 根据当前选择展示页面，默认buildPage为主页面
            if currentTab == .buildPage {
                BuildPage(sceneCoordinator: sceneCoordinator)
            }else if currentTab == .savesPage {
                SavesPage()
            }
            
            // 底部导航栏
            VStack{
                Spacer()
                BottomNavbarComponent(currentTab: $currentTab)
            }
            .ignoresSafeArea()
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
                                RoundedRectangle(cornerRadius: 32.0, style: .circular))
                            .overlay {
                                RoundedRectangle(cornerRadius: 32.0, style: .circular)
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
