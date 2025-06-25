import SceneKit
import SwiftUI

class SceneCoordinator: ObservableObject {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    private var groundNode: SCNNode?
    
    @Published var brickCount = 0
    
    // 相机缩放控制
    private var initialCameraPosition: SCNVector3 = SCNVector3(x: 0, y: 8, z: 15)
    private let minZoom: Float = 0.3
    private let maxZoom: Float = 3.0
    private var currentZoom: Float = 1.0
    
    init() {
        setupScene()
        setupCamera()
        setupLighting()
        setupGround()
    }
    
    // MARK: - Scene Setup
    
    private func setupScene() {
        scene.background.contents = [
            UIColor.systemBlue.withAlphaComponent(0.3),
            UIColor.white
        ]
    }
    
    private func setupCamera() {
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 60
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
        directionalLight.shadowSampleCount = 32
        directionalLight.shadowRadius = 3
        let directionalLightNode = SCNNode()
        directionalLightNode.light = directionalLight
        directionalLightNode.position = SCNVector3(x: 5, y: 10, z: 5)
        directionalLightNode.look(at: SCNVector3(x: 0, y: 0, z: 0))
        scene.rootNode.addChildNode(directionalLightNode)
        
        // 补充光
        let fillLight = SCNLight()
        fillLight.type = .directional
        fillLight.color = UIColor(white: 0.3, alpha: 1.0)
        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight
        fillLightNode.position = SCNVector3(x: -5, y: 8, z: -5)
        fillLightNode.look(at: SCNVector3(x: 0, y: 0, z: 0))
        scene.rootNode.addChildNode(fillLightNode)
    }
    
    private func setupPhysicsWorld() {
        scene.physicsWorld.gravity = SCNVector3(0, -9.8, 0)
    }
    
    private func setupGround() {
        updateGround(width: 8, length: 8, color: .gray)
    }
    
    // MARK: - Ground Management
    public func updateGround(width: Int, length: Int, color: GroundColor) {
        // 移除现有地面
        groundNode?.removeFromParentNode()
        
        // 创建新的砖块地面
        groundNode = createBaseplate(width: width, length: length, color: color)
        scene.rootNode.addChildNode(groundNode!)
    }
    
    private func createBaseplate(width: Int, length: Int, color: GroundColor) -> SCNNode {
        let studSize: CGFloat = 0.8
        let plateHeight: CGFloat = 0.6
        let plateWidth = CGFloat(width) * studSize
        let plateLength = CGFloat(length) * studSize
        
        let plateGeometry = SCNBox(width: plateWidth, height: plateHeight, length: plateLength, chamferRadius: 0.05)
        let plateMaterial = SCNMaterial()
        plateMaterial.diffuse.contents = color.uiColor
        plateMaterial.specular.contents = UIColor.white
        plateGeometry.materials = [plateMaterial]
        
        let plateNode = SCNNode(geometry: plateGeometry)
        plateNode.position = SCNVector3(x: 0, y: -Float(plateHeight/2), z: 0)
        
        // 添加柱子网格
        addStudsToBaseplate(plateNode, width: width, length: length, color: color, plateHeight: plateHeight)
                
        // 添加物理体
        plateNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        plateNode.physicsBody?.restitution = 0.1
        plateNode.physicsBody?.friction = 0.9
                
        
        return plateNode
    }
    
    private func addStudsToBaseplate(_ plateNode: SCNNode, width: Int, length: Int, color: GroundColor, plateHeight: CGFloat) {
        let studRadius: CGFloat = 0.25
        let studHeight: CGFloat = 0.15
        let studSpacing: CGFloat = 0.8
        
        let startX = -CGFloat(width - 1) * studSpacing / 2
        let startZ = -CGFloat(length - 1) * studSpacing / 2
        
        for row in 0..<length {
            for col in 0..<width {
                // 外圈圆柱
                let outerStudGeometry = SCNCylinder(radius: studRadius, height: studHeight)
                let studMaterial = SCNMaterial()
                studMaterial.diffuse.contents = color.uiColor
                studMaterial.specular.contents = UIColor.white
                outerStudGeometry.materials = [studMaterial]
                
                let studNode = SCNNode(geometry: outerStudGeometry)
                studNode.position = SCNVector3(
                    x: Float(startX + CGFloat(col) * studSpacing),
                    y: Float(plateHeight / 2 + studHeight / 2),
                    z: Float(startZ + CGFloat(row) * studSpacing)
                )
                
                // 内圈圆柱
                let innerStudGeometry = SCNCylinder(radius: studRadius * 0.6, height: studHeight + 0.02)
                let innerStudMaterial = SCNMaterial()
                innerStudMaterial.diffuse.contents = UIColor.clear
                innerStudGeometry.materials = [innerStudMaterial]
                               
                plateNode.addChildNode(studNode)
            }
        }
        
    }
    
    // MARK: - Camera Control
    func handleZoom(_ scale: CGFloat) {
        
        let newZoom = currentZoom * Float(scale)
        let clampedZoom = max(minZoom, min(maxZoom, newZoom))
        
        let scaleFactor = clampedZoom / currentZoom
        let currentPosition = cameraNode.position
        let direction = SCNVector3(
            x: currentPosition.x * scaleFactor,
            y: currentPosition.y * scaleFactor,
            z: currentPosition.z * scaleFactor
        )
                
        cameraNode.position = direction
        currentZoom = clampedZoom
        
    }
    
    // MARK: - Brick Creation
    func addBrick() {
        let brick = createBrick()
        
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
    
    private func createBrick() -> SCNNode {
        // 主要砖块体 (2x2x1 尺寸)
        let brickWidth: CGFloat = 1.6
        let brickLength: CGFloat = 1.6
        let brickHeight: CGFloat = 0.92
        
        let brickGeometry = SCNBox(width: brickWidth, height: brickHeight, length: brickLength, chamferRadius: 0.08)
        
        // 砖块材质
        let brickMaterial = SCNMaterial()
        brickMaterial.diffuse.contents = randomBrickColor()
        brickMaterial.specular.contents = UIColor.white
        brickMaterial.shininess = 0.8
        brickMaterial.roughness.contents = 0.2
        brickGeometry.materials = [brickMaterial]
        
        let brickNode = SCNNode(geometry: brickGeometry)
        
        addStudsToBrick(brickNode, rows: 2, columns: 2, brickHeight: brickHeight, brickColor: brickMaterial.diffuse.contents as! UIColor)
        addHollowBottomToBrick(brickNode, brickHeight: brickHeight)
                
                
        // 添加物理体
        brickNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        brickNode.physicsBody?.restitution = 0.2
        brickNode.physicsBody?.friction = 0.8
        brickNode.physicsBody?.mass = 0.5
        
        return brickNode
    }
    
    private func addStudsToBrick(_ brickNode: SCNNode, rows: Int, columns: Int, brickHeight: CGFloat, brickColor: UIColor) {
        let studRadius: CGFloat = 0.24
        let studHeight: CGFloat = 0.18
        let spacing: CGFloat = 0.8
        
        // 计算起始偏移量，使柱子居中
        let startX = -CGFloat(columns - 1) * spacing / 2
        let startZ = -CGFloat(rows - 1) * spacing / 2
        
        for row in 0..<rows {
            for col in 0..<columns {
                // 外圈圆柱
                let outerStudGeometry = SCNCylinder(radius: studRadius, height: studHeight)
                let studMaterial = SCNMaterial()
                studMaterial.diffuse.contents = brickColor
                studMaterial.specular.contents = UIColor.white
                studMaterial.shininess = 0.8
                outerStudGeometry.materials = [studMaterial]
                
                let studNode = SCNNode(geometry: outerStudGeometry)
                studNode.position = SCNVector3(
                    x: Float(startX + CGFloat(col) * spacing),
                    y: Float(brickHeight / 2 + studHeight / 2),
                    z: Float(startZ + CGFloat(row) * spacing)
                )
                
                // 内部hollow圆柱
                let innerStudGeometry = SCNCylinder(radius: studRadius * 0.7, height: studHeight + 0.02)
                let innerStudMaterial = SCNMaterial()
                innerStudMaterial.diffuse.contents = UIColor.clear
                innerStudMaterial.transparency = 0.0
                innerStudGeometry.materials = [innerStudMaterial]
                
                let innerStudNode = SCNNode(geometry: innerStudGeometry)
                innerStudNode.position = SCNVector3(x: 0, y: 0, z: 0)
                
                studNode.addChildNode(innerStudNode)
                brickNode.addChildNode(studNode)
            }
        }
    }
    
    private func addHollowBottomToBrick(_ brickNode: SCNNode, brickHeight: CGFloat) {
        // 在砖块底部添加hollow结构，用于连接其他砖块
        let tubeRadius: CGFloat = 0.2
        let tubeHeight: CGFloat = 0.3
        
        let positions = [
            SCNVector3(x: -0.4, y: -Float(brickHeight/2 - tubeHeight/2), z: -0.4),
            SCNVector3(x: 0.4, y: -Float(brickHeight/2 - tubeHeight/2), z: -0.4),
            SCNVector3(x: -0.4, y: -Float(brickHeight/2 - tubeHeight/2), z: 0.4),
            SCNVector3(x: 0.4, y: -Float(brickHeight/2 - tubeHeight/2), z: 0.4)
        ]
        
        for position in positions {
            let tubeGeometry = SCNCylinder(radius: tubeRadius, height: tubeHeight)
            let tubeMaterial = SCNMaterial()
            tubeMaterial.diffuse.contents = brickNode.geometry?.materials.first?.diffuse.contents
            tubeGeometry.materials = [tubeMaterial]
            
            let tubeNode = SCNNode(geometry: tubeGeometry)
            tubeNode.position = position
            
            brickNode.addChildNode(tubeNode)
        }
    }
    
    private func randomBrickColor() -> UIColor {
        // 随机的乐高砖块颜色
        let colors: [UIColor] = [
            UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1.0),
            UIColor(red: 0.1, green: 0.4, blue: 0.8, alpha: 1.0),
            UIColor(red: 0.2, green: 0.7, blue: 0.2, alpha: 1.0),
            UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0),
            UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0),
            UIColor(red: 0.6, green: 0.3, blue: 0.8, alpha: 1.0),
            UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0),
            UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        ]
        return colors.randomElement() ?? UIColor.systemRed
    }
    
    private func addDropAnimation(to node: SCNNode) {
        // 创建掉落动画
        let targetY: Float = 0.5
        let dropAction = SCNAction.move(to: SCNVector3(node.position.x, targetY, node.position.z), duration: 1.2)
        dropAction.timingMode = .easeIn
        
        // 添加弹跳效果
        let bounceUp = SCNAction.move(by: SCNVector3(0, 0.1, 0), duration: 0.1)
        let bounceDown = SCNAction.move(by: SCNVector3(0, -0.1, 0), duration: 0.1)
        bounceUp.timingMode = .easeOut
        bounceDown.timingMode = .easeIn
        
        let bounceSequence = SCNAction.sequence([bounceUp, bounceDown])
        let completeAction = SCNAction.sequence([dropAction, bounceSequence])
        
        node.runAction(completeAction)
    }
}

