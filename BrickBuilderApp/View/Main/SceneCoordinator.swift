import SceneKit
import SwiftUI

// MARK: - SCNVector3 Extensions
extension SCNVector3 {
    static func + (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
        return SCNVector3(left.x + right.x, left.y + right.y, left.z + right.z)
    }
    
    static func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
        return SCNVector3(left.x - right.x, left.y - right.y, left.z - right.z)
    }
    
    static func * (vector: SCNVector3, scalar: Float) -> SCNVector3 {
        return SCNVector3(vector.x * scalar, vector.y * scalar, vector.z * scalar)
    }
    
    static func += (left: inout SCNVector3, right: SCNVector3) {
        left = left + right
    }
    
    var length: Float {
        return sqrt(x * x + y * y + z * z)
    }
    
    func normalized() -> SCNVector3 {
        let len = length
        if len == 0 { return SCNVector3Zero }
        return SCNVector3(x / len, y / len, z / len)
    }
}

class SceneCoordinator: ObservableObject {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    private var groundNode: SCNNode?
    
    @Published var brickCount = 0
    @Published var currentBrickTemplate: BrickTemplate?
    
    // 相机缩放控制
    private var initialCameraPosition: SCNVector3 = SCNVector3(x: 0, y: 8, z: 15)
    private let minZoom: Float = 0.3
    private let maxZoom: Float = 3.0
    private var currentZoom: Float = 1.0
    
    // 连接检测参数
    private let studSize: Float = 0.8
    private let connectionTolerance: Float = 0.1
    
    
    init() {
        setupScene()
        setupCamera()
        setupLighting()
        setupGround()
        setupPhysicsWorld()
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
    
    // MARK: - Brick Template Management
    func setCurrentBrickTemplate(_ template: BrickTemplate) {
        DispatchQueue.main.async {
            self.currentBrickTemplate = template
        }
    }
    
    // MARK: - Brick Drop Handling
    func handleBrickDrop(at location: CGPoint, with template: BrickTemplate) {
        // 获取屏幕尺寸
        let screenSize = UIScreen.main.bounds.size
        print("Screen size: \(screenSize)")
        
        // 将屏幕坐标转换为归一化坐标 (0-1)
        let normalizedPoint = CGPoint(
            x: location.x / screenSize.width,
            y: location.y / screenSize.height
        )
        print("Normalized point: \(normalizedPoint)")
        
        if let worldPosition = raycastToWorld(normalizedPoint: normalizedPoint) {
            // 检查连接点
            if let validPosition = findValidConnectionPoint(worldPosition, for: template) {

                // 创建并放置砖块
                let brick = createBrick(from: template)
                brick.position = validPosition
                
                // 物理效果暂时禁用
                brick.physicsBody?.type = .kinematic
                
                scene.rootNode.addChildNode(brick)
                
                DispatchQueue.main.async {
                    self.brickCount += 1
                }
                
                // 添加放置动画
                addPlaceAnimation(to: brick)
                
                // 0.5秒后重新启用物理
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    brick.physicsBody?.type = .dynamic
                }
                
            } else {
                // 如果没有有效连接点，播放失败动画
                showPlacementFailed(at: worldPosition)
            }
        }
    }
    
    private func raycastToWorld(normalizedPoint: CGPoint) -> SCNVector3? {
        // 简化方法：直接将屏幕坐标映射到地面
        _ = UIScreen.main.bounds.size
        
        // 获取相机信息
        let cameraPos = cameraNode.position
        let cameraTarget = SCNVector3(0, 0, 0)
        
        let cameraDistance = (cameraPos - cameraTarget).length
        
        let mapRange: Float = cameraDistance * 0.8
        
        // 将归一化坐标转换为世界坐标
        let worldX = Float(normalizedPoint.x - 0.5) * mapRange * 2.0
        let worldZ = Float(normalizedPoint.y - 0.5) * mapRange * 2.0
        let worldY: Float = 0.1
        
        let worldPosition = SCNVector3(x: worldX, y: worldY, z: worldZ)
        print("Simple world position: \(worldPosition)")
        
        return worldPosition
    }
    
    private func findValidConnectionPoint(_ worldPosition: SCNVector3, for template: BrickTemplate) -> SCNVector3? {
        print("Checking connection for position: \(worldPosition)")
        
        // 首先检查地面连接
        if let groundConnection = checkGroundConnection(worldPosition, for: template) {
            print("Found ground connection: \(groundConnection)")
            return groundConnection
        }
        
        // 然后检查其他砖块连接
        if let brickConnection = checkBrickConnection(worldPosition, for: template) {
            print("Found brick connection: \(brickConnection)")
            return brickConnection
        }
        
        print("No valid connection found")
        return nil
    }
    
    private func checkGroundConnection(_ worldPosition: SCNVector3, for template: BrickTemplate) -> SCNVector3? {
        guard groundNode != nil else {
            print("No ground node found")
            return nil
        }
        
        // 简化地面连接检测
        let _: Float = 0.0  // 地面Y坐标
        let brickHeight: Float = 0.46  // 砖块放在地面上的高度
        
        // 将世界位置对齐到网格
        let gridSize: Float = 0.8  // stud间距
        let snappedX = round(worldPosition.x / gridSize) * gridSize
        let snappedZ = round(worldPosition.z / gridSize) * gridSize
        
        // 检查是否在地面范围内（假设地面是8x8）
        let groundSize: Float = 8.0 * gridSize / 2.0  // 地面半径
        if abs(snappedX) <= groundSize && abs(snappedZ) <= groundSize {
            let connectionPoint = SCNVector3(x: snappedX, y: brickHeight, z: snappedZ)
            print("Ground connection at: \(connectionPoint)")
            return connectionPoint
        }
        
        print("Position outside ground bounds")
        return nil
    }
    
    
    private func checkBrickConnection(_ worldPosition: SCNVector3, for template: BrickTemplate) -> SCNVector3? {
        let existingBricks = getAllBricks()
        print("Checking \(existingBricks.count) existing bricks for connection")
        
        for brick in existingBricks {
            if let connectionPoint = findConnectionOnBrick(brick, near: worldPosition, for: template) {
                print("Found connection on brick: \(connectionPoint)")
                return connectionPoint
            }
        }
        
        return nil
    }
    
    
    private func findConnectionOnBrick(_ brick: SCNNode, near position: SCNVector3, for template: BrickTemplate) -> SCNVector3? {
        // 获取砖块的大小（从名称解析）
        let brickSize = getBrickSize(brick)
        let brickPosition = brick.position
        
        // 计算砖块顶部studs的位置
        let studPositions = calculateStudPositions(at: brickPosition, size: brickSize, onTop: true)
        
        // 找到最近的stud
        var closestStud: SCNVector3?
        var minDistance: Float = Float.greatestFiniteMagnitude
        let maxConnectionDistance: Float = 1.0
        
        for studPos in studPositions {
            let distance = distanceBetween(position, studPos)
            if distance < minDistance && distance < maxConnectionDistance {
                minDistance = distance
                closestStud = studPos
            }
        }
        
        if let stud = closestStud {
            // 计算新砖块的位置（在找到的stud之上）
            let brickHeight: Float = 0.92
            let newPosition = SCNVector3(x: stud.x, y: stud.y + brickHeight, z: stud.z)
            
            // 检查是否可以在此位置放置新砖块
            if canPlaceBrickAt(newPosition, size: template.size, excluding: brick) {
                return newPosition
            }
        }
        
        return nil
    }
    
    private func calculateStudPositions(at brickPosition: SCNVector3, size: BrickSize, onTop: Bool) -> [SCNVector3] {
        var positions: [SCNVector3] = []
        
        let studSpacing: Float = 0.8
        let brickHeight: Float = 0.92
        let studHeight: Float = onTop ? (brickHeight / 2 + 0.18 / 2) : 0.0
        
        let startX = brickPosition.x - Float(size.width - 1) * studSpacing / 2
        let startZ = brickPosition.z - Float(size.height - 1) * studSpacing / 2
        
        for row in 0..<size.height {
            for col in 0..<size.width {
                let studX = startX + Float(col) * studSpacing
                let studZ = startZ + Float(row) * studSpacing
                let studY = brickPosition.y + studHeight
                
                positions.append(SCNVector3(x: studX, y: studY, z: studZ))
            }
        }
        
        return positions
    }
    
    private func canPlaceBrickAt(_ position: SCNVector3, size: BrickSize, excluding: SCNNode? = nil) -> Bool {
        // 简化的重叠检测
        let newBrickBounds = getBrickBounds(at: position, size: size)
        
        for brick in getAllBricks() {
            if brick == excluding { continue }
            
            let existingSize = getBrickSize(brick)
            let existingBounds = getBrickBounds(at: brick.position, size: existingSize)
            
            if boundsIntersect(newBrickBounds, existingBounds) {
                print("Brick would overlap with existing brick")
                return false
            }
        }
        
        return true
    }
    
    private func getBrickBounds(at position: SCNVector3, size: BrickSize) -> (min: SCNVector3, max: SCNVector3) {
        let brickWidth = Float(size.width) * 0.8
        let brickDepth = Float(size.height) * 0.8
        let brickHeight: Float = 0.92
        
        let min = SCNVector3(
            x: position.x - brickWidth / 2,
            y: position.y - brickHeight / 2,
            z: position.z - brickDepth / 2
        )
        
        let max = SCNVector3(
            x: position.x + brickWidth / 2,
            y: position.y + brickHeight / 2,
            z: position.z + brickDepth / 2
        )
        
        return (min, max)
    }

    private func getBrickSize(_ brick: SCNNode) -> BrickSize {
        // 从砖块名称解析尺寸
        if let name = brick.name, name.hasPrefix("brick_") {
            let components = name.components(separatedBy: "_")
            if components.count >= 3,
               let width = Int(components[1]),
               let height = Int(components[2]) {
                return BrickSize(width: width, height: height)
            }
        }
        return BrickSize(width: 2, height: 2)
    }

    private func boundsIntersect(_ bounds1: (min: SCNVector3, max: SCNVector3), _ bounds2: (min: SCNVector3, max: SCNVector3)) -> Bool {
        return bounds1.min.x < bounds2.max.x && bounds1.max.x > bounds2.min.x &&
               bounds1.min.y < bounds2.max.y && bounds1.max.y > bounds2.min.y &&
               bounds1.min.z < bounds2.max.z && bounds1.max.z > bounds2.min.z
    }

    private func getAllBricks() -> [SCNNode] {
        return scene.rootNode.childNodes.filter { $0.name?.hasPrefix("brick_") == true }
    }

    private func distanceBetween(_ pos1: SCNVector3, _ pos2: SCNVector3) -> Float {
        let dx = pos1.x - pos2.x
        let dy = pos1.y - pos2.y
        let dz = pos1.z - pos2.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }

    private func showPlacementFailed(at position: SCNVector3) {
        print("Showing placement failed at: \(position)")
        
        guard let template = currentBrickTemplate else { return }
        
        let failedBrick = createBrick(from: template)
        failedBrick.position = position
        
        // 将材质改为红色透明
        failedBrick.geometry?.materials.forEach { material in
            material.diffuse.contents = UIColor.red.withAlphaComponent(0.5)
            material.transparency = 0.5
        }
        
        // 对所有子节点也应用红色材质
        failedBrick.childNodes.forEach { child in
            child.geometry?.materials.forEach { material in
                material.diffuse.contents = UIColor.red.withAlphaComponent(0.5)
                material.transparency = 0.5
            }
        }
        
        scene.rootNode.addChildNode(failedBrick)
        
        // 添加消失动画
        let fadeOut = SCNAction.fadeOut(duration: 1.0)
        let remove = SCNAction.removeFromParentNode()
        let sequence = SCNAction.sequence([fadeOut, remove])
        
        failedBrick.runAction(sequence)
    }
    
    // MARK: - Brick Creation
    private func createBrick(from template: BrickTemplate) -> SCNNode {
        let size = template.size
        let color = template.color
        
        // 主要砖块体
        let brickWidth = CGFloat(size.width) * 0.8
        let brickLength = CGFloat(size.height) * 0.8
        let brickHeight: CGFloat = 0.92
        
        let brickGeometry = SCNBox(width: brickWidth, height: brickHeight, length: brickLength, chamferRadius: 0.08)
        
        // 砖块材质
        let brickMaterial = SCNMaterial()
        brickMaterial.diffuse.contents = color.uiColor
        brickMaterial.specular.contents = UIColor.white
        brickMaterial.shininess = 0.8
        brickMaterial.roughness.contents = 0.2
        brickGeometry.materials = [brickMaterial]
        
        let brickNode = SCNNode(geometry: brickGeometry)
        brickNode.name = "brick_\(size.width)_\(size.height)"
        
        addStudsToBrick(brickNode, rows: size.height, columns: size.width, brickHeight: brickHeight, brickColor: color.uiColor)
        addHollowBottomToBrick(brickNode, rows: size.height, columns: size.width, brickHeight: brickHeight)
        
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
    
    private func addHollowBottomToBrick(_ brickNode: SCNNode, rows: Int, columns: Int, brickHeight: CGFloat) {
        // 在砖块底部添加hollow结构，用于连接其他砖块
        let tubeRadius: CGFloat = 0.2
        let tubeHeight: CGFloat = 0.3
        let spacing: CGFloat = 0.8
        
        let startX = -CGFloat(columns - 1) * spacing / 2
        let startZ = -CGFloat(rows - 1) * spacing / 2
        
        for row in 0..<rows {
            for col in 0..<columns {
                let tubeGeometry = SCNCylinder(radius: tubeRadius, height: tubeHeight)
                let tubeMaterial = SCNMaterial()
                tubeMaterial.diffuse.contents = brickNode.geometry?.materials.first?.diffuse.contents
                tubeGeometry.materials = [tubeMaterial]
                
                let tubeNode = SCNNode(geometry: tubeGeometry)
                tubeNode.position = SCNVector3(
                    x: Float(startX + CGFloat(col) * spacing),
                    y: -Float(brickHeight/2 - tubeHeight/2),
                    z: Float(startZ + CGFloat(row) * spacing)
                )
                tubeNode.name = "tube_\(row)_\(col)"
                
                brickNode.addChildNode(tubeNode)
            }
        }
    }
    
    private func addPlaceAnimation(to node: SCNNode) {
        // 创建放置动画
        let scaleUp = SCNAction.scale(to: 1.1, duration: 0.1)
        let scaleDown = SCNAction.scale(to: 1.0, duration: 0.1)
        let sequence = SCNAction.sequence([scaleUp, scaleDown])
        
        node.runAction(sequence)
    }
}

