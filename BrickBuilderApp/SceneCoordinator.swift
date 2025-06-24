//
//  SceneCoordinator.swift
//  BrickBuilderApp
//
//  Created by San 金 on 2025/6/25.
//
import SceneKit
import SwiftUI

class SceneCoordinator: ObservableObject {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    
    @Published var brickCount = 0
    
    init() {
        setupScene()
        setupCamera()
        setupLighting()
        setupGround()
    }
    
    // MARK: - Scene Setup
    
    private func setupScene() {
        scene.background.contents = UIColor.systemBlue
    }
    
    private func setupCamera() {
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 5, z: 10)
        cameraNode.look(at: SCNVector3(x: 0, y: 0, z: 0))
        scene.rootNode.addChildNode(cameraNode)
    }
    
    private func setupLighting() {
        // 环境光
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = UIColor(white: 0.6, alpha: 1.0)
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)
        
        // 定向光
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.color = UIColor(white: 0.8, alpha: 1.0)
        directionalLight.castsShadow = true
        directionalLight.shadowMode = .deferred
        let directionalLightNode = SCNNode()
        directionalLightNode.light = directionalLight
        directionalLightNode.position = SCNVector3(x: 5, y: 10, z: 5)
        directionalLightNode.look(at: SCNVector3(x: 0, y: 0, z: 0))
        scene.rootNode.addChildNode(directionalLightNode)
    }
    
    private func setupGround() {
        // 创建地面几何体
        let groundGeometry = SCNPlane(width: 20, height: 20)
        
        // 创建地面材质
        let groundMaterial = SCNMaterial()
        groundMaterial.diffuse.contents = UIColor.lightGray
        groundMaterial.specular.contents = UIColor.white
        groundGeometry.materials = [groundMaterial]
        
        // 创建地面节点
        let groundNode = SCNNode(geometry: groundGeometry)
        groundNode.rotation = SCNVector4(x: 1, y: 0, z: 0, w: -Float.pi / 2) // 旋转90度使其水平
        groundNode.position = SCNVector3(x: 0, y: -1, z: 0)
        
        // 添加物理体（可选，用于碰撞检测）
        groundNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        groundNode.physicsBody?.restitution = 0.2
        
        scene.rootNode.addChildNode(groundNode)
    }
    
    // MARK: - Brick Creation
    
    func addLegoBrick() {
        let brick = createLegoBrick()
        
        // 随机位置放置砖块
        let x = Float.random(in: -3...3)
        let z = Float.random(in: -3...3)
        brick.position = SCNVector3(x: x, y: 2, z: z)
        
        // 添加到场景
        scene.rootNode.addChildNode(brick)
        
        // 更新砖块计数
        DispatchQueue.main.async {
            self.brickCount += 1
        }
        
        // 添加掉落动画
        addDropAnimation(to: brick)
    }
    
    private func createLegoBrick() -> SCNNode {
        // 主要砖块体 (2x2x1 尺寸)
        let brickWidth: CGFloat = 2.0   // 2个单位宽度
        let brickLength: CGFloat = 2.0  // 2个单位长度
        let brickHeight: CGFloat = 1.0  // 1个单位高度
        
        let brickGeometry = SCNBox(width: brickWidth, height: brickHeight, length: brickLength, chamferRadius: 0.1)
        
        // 砖块材质
        let brickMaterial = SCNMaterial()
        brickMaterial.diffuse.contents = randomBrickColor()
        brickMaterial.specular.contents = UIColor.white
        brickMaterial.shininess = 0.8
        brickGeometry.materials = [brickMaterial]
        
        let brickNode = SCNNode(geometry: brickGeometry)
        
        // 添加顶部的连接柱 (2x2 = 4个柱子)
        addStudsToBrick(brickNode, rows: 2, columns: 2, brickHeight: brickHeight)
        
        // 添加物理体
        brickNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        brickNode.physicsBody?.restitution = 0.3
        brickNode.physicsBody?.friction = 0.8
        brickNode.physicsBody?.mass = 1.0
        
        return brickNode
    }
    
    private func addStudsToBrick(_ brickNode: SCNNode, rows: Int, columns: Int, brickHeight: CGFloat) {
        let studRadius: CGFloat = 0.15
        let studHeight: CGFloat = 0.2
        let spacing: CGFloat = 1.0 // 柱子之间的间距
        
        // 计算起始偏移量，使柱子居中
        let startX = -CGFloat(columns - 1) * spacing / 2
        let startZ = -CGFloat(rows - 1) * spacing / 2
        
        for row in 0..<rows {
            for col in 0..<columns {
                // 创建连接柱几何体
                let studGeometry = SCNCylinder(radius: studRadius, height: studHeight)
                let studMaterial = SCNMaterial()
                studMaterial.diffuse.contents = brickNode.geometry?.materials.first?.diffuse.contents
                studGeometry.materials = [studMaterial]
                
                let studNode = SCNNode(geometry: studGeometry)
                studNode.position = SCNVector3(
                    x: Float(startX + CGFloat(col) * spacing),
                    y: Float(brickHeight / 2 + studHeight / 2),
                    z: Float(startZ + CGFloat(row) * spacing)
                )
                
                brickNode.addChildNode(studNode)
            }
        }
    }
    
    private func randomBrickColor() -> UIColor {
        let colors: [UIColor] = [
            .systemRed,
            .systemBlue,
            .systemGreen,
            .systemYellow,
            .systemOrange,
            .systemPurple,
            .white,
            .black
        ]
        return colors.randomElement() ?? .systemRed
    }
    
    private func addDropAnimation(to node: SCNNode) {
        // 创建掉落动画
        let dropAction = SCNAction.move(to: SCNVector3(node.position.x, 0, node.position.z), duration: 1.0)
        dropAction.timingMode = .easeIn
        
        // 添加弹跳效果
        let bounceAction = SCNAction.sequence([
            SCNAction.move(by: SCNVector3(0, 0.3, 0), duration: 0.1),
            SCNAction.move(by: SCNVector3(0, -0.3, 0), duration: 0.1)
        ])
        
        let completeAction = SCNAction.sequence([dropAction, bounceAction])
        node.runAction(completeAction)
    }
}

