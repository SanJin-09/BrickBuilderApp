import SwiftUI
import SceneKit

struct ContentView: View {
    @StateObject private var sceneCoordinator = SceneCoordinator()
    @State private var showingGroundSettings = false
    @State private var showingBrickSettings = false
    
    var body: some View {
        ZStack {
            SceneView(
                scene: sceneCoordinator.scene,
                pointOfView: sceneCoordinator.cameraNode,
                options: [.allowsCameraControl, .autoenablesDefaultLighting]
            )
            .ignoresSafeArea()
            .gesture(
                MagnificationGesture()
                    .onChanged{
                        value in sceneCoordinator.handleZoom(value)
                    }
            )
            
            // UI 控件
            VStack {
                // 顶部砖块选择区域
                HStack {
                    VStack {
                        HStack {
                            Text("积木搭建器")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(10)
                            
                            Spacer()
                            
                            Text("砖块数: \(sceneCoordinator.brickCount)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                        }
                        
                        // 砖块调色板
                        BrickPaletteView(sceneCoordinator: sceneCoordinator)
                            .padding(.top, 5)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // 底部按钮
                HStack {
                    // 地面设置按钮
                    Button(action: {
                        showingGroundSettings = true
                    }) {
                        Image(systemName: "square.grid.3x3")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.gray)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .padding(.leading, 30)
                    
                    Spacer()
                    
                    // 砖块设置按钮
                    Button(action: {
                        showingBrickSettings = true
                    }) {
                        Image(systemName: "cube.box")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.orange)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .padding(.trailing, 30)
                }
                .padding(.bottom, 50)
            }
        }
        .sheet(isPresented: $showingGroundSettings) {
            GroundSettingsView(sceneCoordinator: sceneCoordinator)
        }
        .sheet(isPresented: $showingBrickSettings) {
            BrickSettingsView(sceneCoordinator: sceneCoordinator)
        }
    }
}

#Preview {
    ContentView()
}
