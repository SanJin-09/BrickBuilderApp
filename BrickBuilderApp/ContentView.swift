//
//  ContentView.swift
//  BrickBuilderApp
//
//  Created by San 金 on 2025/6/25.
//

import SwiftUI
import SceneKit

struct ContentView: View {
    @StateObject private var sceneCoordinator = SceneCoordinator()
    
    var body: some View {
            ZStack {
                // SceneKit 视图
                SceneView(
                    scene: sceneCoordinator.scene,
                    pointOfView: sceneCoordinator.cameraNode,
                    options: [.allowsCameraControl, .autoenablesDefaultLighting]
                )
                .ignoresSafeArea()
                
                // UI 控件
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        // 添加砖块按钮
                        Button(action: {
                            sceneCoordinator.addLegoBrick()
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        .padding(.trailing, 30)
                        .padding(.bottom, 50)
                    }
                }
                
                // 顶部信息栏
                VStack {
                    HStack {
                        Text("乐高积木搭建器")
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
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                }
            }
    }
}

#Preview {
    ContentView()
}
