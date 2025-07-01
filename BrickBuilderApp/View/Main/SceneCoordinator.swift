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

fileprivate typealias GridPoint = SIMD3<Int>
fileprivate let gridSize: Float = 0.8
fileprivate let brickBodyHeight: Float = 0.92
fileprivate let brickStackingHeight: Float = 0.96

class SceneCoordinator: ObservableObject {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    private var groundNode: SCNNode? // 视觉地面
    private var physicalGroundNode: SCNNode? // 物理地面
    
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
        // 移除旧的节点
        groundNode?.removeFromParentNode()
        physicalGroundNode?.removeFromParentNode()

        groundNode = createBaseplate(width: width, length: length, color: color)
        groundNode?.name = "ground"
        scene.rootNode.addChildNode(groundNode!)

        let plateHeight: CGFloat = 0.6
        let plateWidth = CGFloat(width) * CGFloat(gridSize)
        let plateLength = CGFloat(length) * CGFloat(gridSize)
        
        let physicsGeometry = SCNBox(width: plateWidth, height: plateHeight, length: plateLength, chamferRadius: 0.0)
        let physicsShape = SCNPhysicsShape(geometry: physicsGeometry, options: nil)
        
        physicalGroundNode = SCNNode()
        physicalGroundNode!.physicsBody = SCNPhysicsBody(type: .static, shape: physicsShape)
        physicalGroundNode!.position = SCNVector3(x: 0, y: -Float(plateHeight/2), z: 0)
        physicalGroundNode!.isHidden = true
        
        scene.rootNode.addChildNode(physicalGroundNode!)
    }
    
    private func createBaseplate(width: Int, length: Int, color: GroundColor) -> SCNNode {
        let plateHeight: CGFloat = 0.6
        let plateWidth = CGFloat(width) * CGFloat(gridSize)
        let plateLength = CGFloat(length) * CGFloat(gridSize)
        
        let plateGeometry = SCNBox(width: plateWidth, height: plateHeight, length: plateLength, chamferRadius: 0.05)
        let plateMaterial = SCNMaterial()
        plateMaterial.diffuse.contents = color.uiColor
        plateMaterial.specular.contents = UIColor.white
        plateGeometry.materials = [plateMaterial]
        
        let plateNode = SCNNode(geometry: plateGeometry)
        plateNode.position = SCNVector3(x: 0, y: -Float(plateHeight/2), z: 0)
        
        addStudsToBaseplate(plateNode, width: width, length: length, color: color, plateHeight: plateHeight)
        
        return plateNode
    }
    
    private func addStudsToBaseplate(_ plateNode: SCNNode, width: Int, length: Int, color: GroundColor, plateHeight: CGFloat) {
        let studRadius: CGFloat = 0.25
        let studHeight: CGFloat = 0.15
        
        let startX = -Float(width - 1) * gridSize / 2.0
        let startZ = -Float(length - 1) * gridSize / 2.0
        
        print("Ground studs - startX: \(startX), startZ: \(startZ)")
        
        for _ in 0..<length {
            for row in 0..<length {
                for col in 0..<width {
                    let studGeometry = SCNCylinder(radius: studRadius, height: studHeight)
                    let studMaterial = SCNMaterial()
                    studMaterial.diffuse.contents = color.uiColor
                    studMaterial.specular.contents = UIColor.white
                    studGeometry.materials = [studMaterial]
                    
                    let studNode = SCNNode(geometry: studGeometry)
                    studNode.position = SCNVector3(
                        x: startX + Float(col) * gridSize,
                        y: Float(plateHeight / 2 + studHeight / 2),
                        z: startZ + Float(row) * gridSize
                    )
                    plateNode.addChildNode(studNode)
                }
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

        // 将屏幕坐标转换为归一化坐标 (0-1)
        let normalizedPoint = CGPoint(
            x: location.x / screenSize.width,
            y: location.y / screenSize.height
        )

        if let worldPosition = raycastToWorld(normalizedPoint: normalizedPoint) {
            // 检查连接点
            if let validPosition = findValidPlacement(for: template, near: worldPosition) {

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
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    brick.physicsBody?.type = .dynamic
                }
                
            } else {
                // 播放失败动画
                showPlacementFailed(at: worldPosition)
            }
        }
    }
    
    private func raycastToWorld(normalizedPoint: CGPoint) -> SCNVector3? {
        let cameraPos = cameraNode.position
        let cameraDistance = (cameraPos - SCNVector3Zero).length
        let mapRange: Float = cameraDistance * 0.8
        
        let worldX = Float(normalizedPoint.x - 0.5) * mapRange * 2.0
        let worldZ = Float(normalizedPoint.y - 0.5) * mapRange * 2.0
        return SCNVector3(x: worldX, y: 0.1, z: worldZ)
    }
    
    private func gridPoint(from world: SCNVector3) -> GridPoint {
        let x = Int(round(world.x / gridSize))
        let z = Int(round(world.z / gridSize))
        
        let level = Int(round((world.y - (brickBodyHeight / 2.0)) / brickStackingHeight)) + 1
        return GridPoint(x, level, z)
    }
    
    private func getOccupiedVolume(for size: BrickSize, at position: SCNVector3) -> Set<GridPoint> {
        var occupied = Set<GridPoint>()
        
        // 计算砖块在当前Y层的网格
        let centerGridPoint = gridPoint(from: position)
        let brickGridY = centerGridPoint.y
        
        // 计算砖块左下角第一个网格点的世界坐标
        let startX = position.x - Float(size.width - 1) * gridSize / 2.0
        let startZ = position.z - Float(size.height - 1) * gridSize / 2.0
        
        // 遍历砖块占据的所有网格点
        for row in 0..<size.height {
            for col in 0..<size.width {
                let studWorldX = startX + Float(col) * gridSize
                let studWorldZ = startZ + Float(row) * gridSize
                
                // 将每个占据的位置转换为网格点
                let occupiedPoint = GridPoint(
                    Int(round(studWorldX / gridSize)),
                    brickGridY,
                    Int(round(studWorldZ / gridSize))
                )
                
                occupied.insert(occupiedPoint)
            }
        }
        
        return occupied
    }
    
    private func buildSceneOccupationMap() -> Set<GridPoint> {
        var occupied = Set<GridPoint>()
        for brick in getAllBricks() {
            let size = getBrickSize(brick)
            let volume = getOccupiedVolume(for: size, at: brick.position)
            occupied.formUnion(volume)
        }
        return occupied
    }
    
    private func getFootprint(for size: BrickSize, at position: SCNVector3) -> Set<GridPoint> {
        var points = Set<GridPoint>()
        
        // 计算左下角第一个连接点的世界坐标
        let startX = position.x - Float(size.width - 1) * gridSize / 2.0
        let startZ = position.z - Float(size.height - 1) * gridSize / 2.0
        
        let supportGridY = gridPoint(from: position).y - 1
        
        // 遍历所有连接点
        for row in 0..<size.height {
            for col in 0..<size.width {
                let studWorldX = startX + Float(col) * gridSize
                let studWorldZ = startZ + Float(row) * gridSize
                
                let supportPoint = GridPoint(
                    Int(round(studWorldX / gridSize)),
                    supportGridY,
                    Int(round(studWorldZ / gridSize))
                )
                
                points.insert(supportPoint)
            }
        }
        return points
    }
    
    // 获取所有可用的支撑点
    private func getAvailableStuds() -> [GridPoint: (pos: SCNVector3, owner: SCNNode)] {
        var studs = [GridPoint: (pos: SCNVector3, owner: SCNNode)]()
        
        if let ground = groundNode {
            let groundSizeW = 8
            let groundSizeL = 8
            let groundSupportLevel = 0
            
            let startX = -Float(groundSizeW - 1) * gridSize / 2.0
            let startZ = -Float(groundSizeL - 1) * gridSize / 2.0
            
            for r in 0..<groundSizeL {
                for c in 0..<groundSizeW {
                    // 计算每个凸点精确的世界坐标 (Y=0代表地面支撑面)
                    let worldPos = SCNVector3(startX + Float(c) * gridSize, 0, startZ + Float(r) * gridSize)
                    let gridKey = GridPoint(Int(round(worldPos.x / gridSize)), groundSupportLevel, Int(round(worldPos.z / gridSize)))
                    studs[gridKey] = (pos: worldPos, owner: ground)
                }
            }
        }

        for brick in getAllBricks() {
            let size = getBrickSize(brick)
            let brickLevel = gridPoint(from: brick.position).y
            let brickSupportLevel = brickLevel
            
            let startX = brick.position.x - Float(size.width - 1) * gridSize / 2.0
            let startZ = brick.position.z - Float(size.height - 1) * gridSize / 2.0
            
            // 支撑面的Y坐标是砖块的顶部
            let supportY = brick.position.y + brickBodyHeight / 2.0
            
            for row in 0..<size.height {
                for col in 0..<size.width {
                    let worldPos = SCNVector3(startX + Float(col) * gridSize, supportY, startZ + Float(row) * gridSize)
                    let gridKey = GridPoint(Int(round(worldPos.x / gridSize)), brickSupportLevel, Int(round(worldPos.z / gridSize)))
                    studs[gridKey] = (pos: worldPos, owner: brick)
                }
            }
        }
        return studs
    }
    
    private func findValidPlacement(for template: BrickTemplate, near worldPosition: SCNVector3) -> SCNVector3? {
        let newBrickSize = template.size
        let availableStuds = getAvailableStuds()
        let occupiedVolume = buildSceneOccupationMap()
        let anchorGridPoint = gridPoint(from: worldPosition)
        
        var closestStudKey: GridPoint? = nil
        var minDistance = Float.infinity
        
        for studKey in availableStuds.keys {
            let dx = Float(studKey.x - anchorGridPoint.x)
            let dy = Float(studKey.y - anchorGridPoint.y)
            let dz = Float(studKey.z - anchorGridPoint.z)
            let dist = dx*dx + dy*dy + dz*dz
            if dist < minDistance {
                minDistance = dist
                closestStudKey = studKey
            }
        }
        
        guard let targetStudKey = closestStudKey,
              let (targetStudWorldPos, supportNode) = availableStuds[targetStudKey] else {
            return nil
        }
        
        for r_offset in 0..<newBrickSize.height {
            for c_offset in 0..<newBrickSize.width {
                
                let startOffsetX = Float(c_offset) * gridSize - Float(newBrickSize.width - 1) * gridSize / 2.0
                let startOffsetZ = Float(r_offset) * gridSize - Float(newBrickSize.height - 1) * gridSize / 2.0
                
                let newBrickX = targetStudWorldPos.x - startOffsetX
                let newBrickZ = targetStudWorldPos.z - startOffsetZ
                
                let newBrickY: Float
                if supportNode.name == "ground" {
                    newBrickY = brickBodyHeight / 2.0
                } else {
                    let supportBrickTopY = supportNode.position.y + brickBodyHeight / 2.0
                    newBrickY = supportBrickTopY + brickBodyHeight / 2.0
                }
                
                let candidatePosition = SCNVector3(newBrickX, newBrickY, newBrickZ)
                
                let requiredFootprint = getFootprint(for: newBrickSize, at: candidatePosition)
                let supportingStuds = requiredFootprint.filter { availableStuds.keys.contains($0) }
                
                let allSupported = supportingStuds.count == requiredFootprint.count
                let sameLevel = supportingStuds.allSatisfy { $0.y == targetStudKey.y }

                if allSupported && sameLevel {
                    if occupiedVolume.isDisjoint(with: getOccupiedVolume(for: newBrickSize, at: candidatePosition)) {
                        return candidatePosition
                    }
                }
            }
        }
        return nil
    }

    private func showPlacementFailed(at position: SCNVector3) {
        
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
    
    private func getAllBricks() -> [SCNNode] {
        return scene.rootNode.childNodes.filter { $0.name?.hasPrefix("brick_") == true }
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
        let scaleUp = SCNAction.scale(to: 1.1, duration: 0.1)
        let scaleDown = SCNAction.scale(to: 1.0, duration: 0.1)
        let sequence = SCNAction.sequence([scaleUp, scaleDown])
        
        node.runAction(sequence)
    }
}

