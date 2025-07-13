import SceneKit
import SwiftUI

// MARK: - Extensions
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
    
    var lengthSquared: Float {
        return x * x + y * y + z * z
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
    weak var scnView: SCNView?
    private var groundNode: SCNNode? // 视觉地面
    private var physicalGroundNode: SCNNode? // 物理地面
    private var ghostBrick: SCNNode?
    private var isGhostValid: Bool = false
    
    @Published var brickCount = 0
    @Published var currentBrickTemplate: BrickTemplate?
    @Published var currentRotation: Int = 0
    @Published var selectedBrick: SCNNode?
    @Published var deleteButtonPosition: CGPoint?
    @Published var projectMessage: String?
    
    // 动态地面尺寸
    private var currentGroundWidth: Int = 8
    private var currentGroundLength: Int = 8
    private var currentGroundColor: GroundColor = .gray
    
    // 相机缩放控制
    private var initialCameraPosition: SCNVector3 = SCNVector3(x: 0, y: 8, z: 15)
    private let minZoom: Float = 0.3
    private let maxZoom: Float = 3.0
    private var currentZoom: Float = 1.0
    
    // 连接检测参数
    private let studSize: Float = 0.8
    private let connectionTolerance: Float = 0.1
    private let persistenceManager = PersistenceManager()
    
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
    
    private func clearScene() {
        getAllBricks().forEach { $0.removeFromParentNode() }
        DispatchQueue.main.async {
            self.brickCount = 0
        }
    }
    
    // MARK: - Project Save/Load Logic
    func saveProject(name: String) {
        let savedBricks = getAllBricks().map { brick -> SavedBrick in
            let size = getBrickSize(brick)
            
            let color: BrickColor
            if let colorRawValue = brick.value(forKey: "originalColor") as? String,
               let originalColor = BrickColor(rawValue: colorRawValue) {
                color = originalColor
            } else {
                color = inferColorFromMaterial(brick.geometry?.firstMaterial)
            }
            let colorHex = color.toHex()
            return SavedBrick(
                sizeW: size.width,
                sizeH: size.height,
                colorHex: colorHex,
                positionX: brick.position.x,
                positionY: brick.position.y,
                positionZ: brick.position.z,
                rotationY: brick.eulerAngles.y
            )
        }
        
        let project = SavedProject(
            groundWidth: currentGroundWidth,
            groundLength: currentGroundLength,
            groundColor: currentGroundColor,
            bricks: savedBricks,
            cameraZoom: currentZoom,
            cameraPosition: [cameraNode.position.x, cameraNode.position.y, cameraNode.position.z],
            cameraRotation: [cameraNode.orientation.x, cameraNode.orientation.y, cameraNode.orientation.z, cameraNode.orientation.w]
        )
        
        do {
            try persistenceManager.save(project: project, withName: name)
            showProjectMessage("项目 '\(name)' 已保存！")
        } catch {
            showProjectMessage("保存失败: \(error.localizedDescription)")
        }
    }
    
    private func inferColorFromMaterial(_ material: SCNMaterial?) -> BrickColor {
        guard let material = material else { return .gray }
        
        if let uiColor = material.diffuse.contents as? UIColor {
            return BrickColor.fromUIColor(uiColor)
        }
        
        return .gray
    }

    func loadProject(name: String) {
        do {
            let project = try persistenceManager.load(fromName: name)
            
            clearScene()
            updateGround(width: project.groundWidth, length: project.groundLength, color: project.groundColor)
            
            for savedBrick in project.bricks {
                let color = BrickColor.from(hex: savedBrick.colorHex)
                let template = BrickTemplate(size: BrickSize(width: savedBrick.sizeW, height: savedBrick.sizeH), color: color)
                let brickNode = createBrick(from: template)
                
                brickNode.position = SCNVector3(savedBrick.positionX, savedBrick.positionY, savedBrick.positionZ)
                brickNode.eulerAngles.y = savedBrick.rotationY
                brickNode.physicsBody?.type = .static
                
                scene.rootNode.addChildNode(brickNode)
            }
            
            cameraNode.position = SCNVector3(project.cameraPosition[0], project.cameraPosition[1], project.cameraPosition[2])
            cameraNode.orientation = SCNQuaternion(project.cameraRotation[0], project.cameraRotation[1], project.cameraRotation[2], project.cameraRotation[3])
            currentZoom = project.cameraZoom
            
            DispatchQueue.main.async {
                self.brickCount = project.bricks.count
            }
            showProjectMessage("项目 '\(name)' 已加载！")
            
        } catch {
            showProjectMessage("加载失败: \(error.localizedDescription)")
        }
    }

    func listSavedProjects() -> [String] {
        return persistenceManager.listProjects()
    }

    func deleteProject(name: String) {
        do {
            try persistenceManager.delete(projectName: name)
            showProjectMessage("项目 '\(name)' 已删除。")
        } catch {
            showProjectMessage("删除失败: \(error.localizedDescription)")
        }
    }
    
    private func showProjectMessage(_ message: String) {
        DispatchQueue.main.async {
            self.projectMessage = message
        }
    }
    
    // MARK: - Ground Management
    public func updateGround(width: Int, length: Int, color: GroundColor) {
        
        // 更新当前地面尺寸
        currentGroundWidth = width
        currentGroundLength = length
        
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
                    studNode.name = "ground_stud_\(row)_\(col)"
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
    
    // MARK: - Brick Delate
    func handleTap(at location: CGPoint, in view: SCNView) {
        let hitTestResults = view.hitTest(location, options: nil)
        
        if let firstResult = hitTestResults.first(where: { $0.node.name?.hasPrefix("brick_") == true }) {
            selectBrick(firstResult.node, in: view)
        } else {
            deselectBrick()
        }
    }
    
    private func selectBrick(_ node: SCNNode, in view: SCNView) {
        // 如果已经选中了同一个砖块，则不做任何事
        if selectedBrick == node { return }
        
        deselectBrick()
        
        selectedBrick = node
        
        let highlightAction = SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.customAction(duration: 0.5, action: { node, _ in
                node.geometry?.firstMaterial?.emission.contents = UIColor.yellow
            }),
            SCNAction.customAction(duration: 0.5, action: { node, _ in
                node.geometry?.firstMaterial?.emission.contents = UIColor.black
            })
        ]))
        node.runAction(highlightAction, forKey: "highlight")

        // 计算删除按钮的位置
        let boundingBox = node.boundingBox
        let button3DPos = SCNVector3(boundingBox.max.x, boundingBox.max.y, boundingBox.max.z)
        let worldPos = node.convertPosition(button3DPos, to: nil)
        let projectedPoint = view.projectPoint(worldPos)
        
        DispatchQueue.main.async {
            self.deleteButtonPosition = CGPoint(x: CGFloat(projectedPoint.x), y: CGFloat(projectedPoint.y))
        }
    }

    func deselectBrick() {
        if let brick = selectedBrick {
            brick.removeAction(forKey: "highlight")
            brick.geometry?.firstMaterial?.emission.contents = UIColor.black
        }
        selectedBrick = nil
        deleteButtonPosition = nil
    }

    func deleteSelectedBrick() {
        guard let brick = selectedBrick else { return }
        
        brick.removeFromParentNode()
        brickCount -= 1
        deselectBrick()
    }
    
    // MARK: - Brick Rotation
    public func rotateCurrentBrick() {
        currentRotation = (currentRotation + 1) % 4
        applyRotationToGhost()
    }
    
    private func applyRotationToGhost() {
        guard let ghost = ghostBrick else {return}
        let angle = Float(currentRotation) * .pi / 2
        ghost.eulerAngles.y = angle
        // 旋转后，重新检查位置有效性
        if let template = currentBrickTemplate, let ghostPosition = ghostBrick?.position {
            if let validPosition = findValidPlacement(for: template, near: ghostPosition) {
                ghost.position = validPosition
                setGhostBrickColor(isValid: true)
                isGhostValid = true
            } else {
                setGhostBrickColor(isValid: false)
                isGhostValid = false
            }
        }
    }
    
    // MARK: - Ghost Brick Management
    private func updateGhostBrick(for template: BrickTemplate, at location: CGPoint, in view: SCNView) {
        if let worldPosition = findWorldCoordinates(at: location, in: view) {
            if ghostBrick == nil {
                createGhostBrick(from: template)
            }
            
            // 检查是否可以放置
            if let validPosition = findValidPlacement(for: template, near: worldPosition) {
                // 可以放置 - 绿色
                ghostBrick?.position = validPosition
                setGhostBrickColor(isValid: true)
                isGhostValid = true
            } else {
                // 不能放置 - 尝试放在相近的位置
                let snappedY = round(worldPosition.y / brickStackingHeight) * brickStackingHeight + brickBodyHeight / 2.0
                ghostBrick?.position = SCNVector3(worldPosition.x, snappedY, worldPosition.z)
                setGhostBrickColor(isValid: false)
                isGhostValid = false
            }
            
            ghostBrick?.isHidden = false
        } else {
            ghostBrick?.isHidden = true
        }
    }
    
    private func createGhostBrick(from template: BrickTemplate) {
        // 创建虚影砖块
        let brick = createBrick(from: template)
        
        brick.eulerAngles.y = Float(currentRotation) * .pi / 2
        
        brick.physicsBody = nil
        brick.opacity = 0.6
        
        scene.rootNode.addChildNode(brick)
        
        ghostBrick = brick
        ghostBrick?.name = "ghost_brick"
    }
    
    private func setGhostBrickColor(isValid: Bool) {
        guard let ghost = ghostBrick else { return }
        
        let color = isValid ? UIColor.green : UIColor.red
        
        // 更新主体材质
        ghost.geometry?.materials.forEach { material in
            material.diffuse.contents = color
            material.transparency = 0.6
        }
        
        ghost.childNodes.forEach { child in
            child.geometry?.materials.forEach { material in
                material.diffuse.contents = color
                material.transparency = 0.6
            }
        }
    }
    
    func removeGhostBrick() {
        ghostBrick?.removeFromParentNode()
        ghostBrick = nil
        isGhostValid = false
    }
    
    func cleanup() {
        removeGhostBrick()
    }
    
    // MARK: - Brick Template Management
    func setCurrentBrickTemplate(_ template: BrickTemplate) {
        DispatchQueue.main.async {
            self.currentBrickTemplate = template
            self.currentRotation = 0
        }
    }
    
    // MARK: - Brick Drop Handling
    func handleBrickDrop(at location: CGPoint, with template: BrickTemplate, in view: SCNView) {
        
        removeGhostBrick()

        if let worldPosition = findWorldCoordinates(at: location, in: view) {
            if let validPosition = findValidPlacement(for: template, near: worldPosition) {
                
                let brick = createBrick(from: template)
                brick.position = validPosition
                // 应用旋转
                brick.eulerAngles.y = Float(currentRotation) * .pi / 2
                
                brick.physicsBody?.type = .kinematic
                scene.rootNode.addChildNode(brick)
                
                DispatchQueue.main.async { self.brickCount += 1 }
                addPlaceAnimation(to: brick)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    brick.physicsBody?.type = .dynamic
                }
            }
        }
    }
    
    // 处理拖动更新
    func handleDragUpdate(at location: CGPoint, with template: BrickTemplate, in view: SCNView) {
        updateGhostBrick(for: template, at: location, in: view)
    }
    
    // 处理拖动取消
    func handleDragCancel() {
        removeGhostBrick()
    }
    
    private func findWorldCoordinates(at location: CGPoint, in view: SCNView) -> SCNVector3? {
        // 优先尝试碰撞到现有几何体的顶面
        let options: [SCNHitTestOption: Any] = [
            .searchMode: SCNHitTestSearchMode.all.rawValue,
            .ignoreHiddenNodes: false
        ]
        let hitTestResults = view.hitTest(location, options: options)

        // 筛选
        if let topSurfaceHit = hitTestResults.first(where: {
            ($0.node.name?.contains("ground") == true || $0.node.name?.hasPrefix("brick_") == true) &&
            $0.worldNormal.y > 0.7
        }) {
            return topSurfaceHit.worldCoordinates
        }

        let cameraPos = self.cameraNode.worldPosition
        let unprojectedPointFar = view.unprojectPoint(SCNVector3(location.x, location.y, 0.9))

        let rayDirection = (unprojectedPointFar - cameraPos).normalized()

        // 只有当射线朝下时，才可能与地面相交
        if rayDirection.y < 0 {
            let t = -cameraPos.y / rayDirection.y
            if t > 0 {
                let intersectionPoint = cameraPos + rayDirection * t
                
                // 确保交点在地面范围内
                let groundHalfWidth = Float(currentGroundWidth) * gridSize / 2.0
                let groundHalfLength = Float(currentGroundLength) * gridSize / 2.0
                
                if abs(intersectionPoint.x) <= groundHalfWidth && abs(intersectionPoint.z) <= groundHalfLength {
                    return intersectionPoint
                }
            }
        }
        
        return nil
    }
    
    private func gridPoint(from world: SCNVector3) -> GridPoint {
        let x = Int(round(world.x / gridSize))
        let z = Int(round(world.z / gridSize))
        
        let level = Int(round(world.y / brickStackingHeight))
        return GridPoint(x, level, z)
    }
    
    private func getOccupiedVolume(for brick: SCNNode) -> Set<GridPoint> {
        var occupied = Set<GridPoint>()
        let size = getBrickSize(brick)
        let position = brick.position
        let rotation = Int(round(brick.eulerAngles.y / (.pi / 2))) % 4
        
        let effectiveSize = (rotation == 1 || rotation == 3) ? BrickSize(width: size.height, height: size.width) : size

        // 砖块占据的Y层级
        let brickGridY = gridPoint(from: position).y

        let startX = position.x - Float(effectiveSize.width - 1) * gridSize / 2.0
        let startZ = position.z - Float(effectiveSize.height - 1) * gridSize / 2.0

        for row in 0..<effectiveSize.height {
            for col in 0..<effectiveSize.width {
                let studWorldX = startX + Float(col) * gridSize
                let studWorldZ = startZ + Float(row) * gridSize
                
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
    
    private func getProspectiveOccupiedVolume(for template: BrickTemplate, at position: SCNVector3) -> Set<GridPoint> {
        
        let size = getEffectiveSize(for: template)
        var occupied = Set<GridPoint>()
        
        let brickGridY = gridPoint(from: position).y
        
        let startX = position.x - Float(size.width - 1) * gridSize / 2.0
        let startZ = position.z - Float(size.height - 1) * gridSize / 2.0
        
        for row in 0..<size.height {
            for col in 0..<size.width {
                let studWorldX = startX + Float(col) * gridSize
                let studWorldZ = startZ + Float(row) * gridSize
                
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
            occupied.formUnion(getOccupiedVolume(for: brick))
        }
        return occupied
    }
    
    private func getFootprint(for template: BrickTemplate, at position: SCNVector3) -> Set<GridPoint> {
        let size = getEffectiveSize(for: template)
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
            let groundSizeW = currentGroundWidth
            let groundSizeL = currentGroundLength

            let startX = -Float(groundSizeW - 1) * gridSize / 2.0
            let startZ = -Float(groundSizeL - 1) * gridSize / 2.0
            
            for r in 0..<groundSizeL {
                for c in 0..<groundSizeW {
                    let worldPos = SCNVector3(startX + Float(c) * gridSize, 0, startZ + Float(r) * gridSize)
                    let gridKey = GridPoint(Int(round(worldPos.x / gridSize)), -1, Int(round(worldPos.z / gridSize)))
                    studs[gridKey] = (pos: worldPos, owner: ground)
                }
            }
        }

        for brick in getAllBricks() {
            let size = getBrickSize(brick)
            let brickSupportLevel = gridPoint(from: brick.position).y
            
            // 遍历砖块的原始行列
            for row in 0..<size.height {
                for col in 0..<size.width {
                    let localX = (Float(col) - Float(size.width - 1) / 2.0) * gridSize
                    let localZ = (Float(row) - Float(size.height - 1) / 2.0) * gridSize
                    let localY = brickBodyHeight / 2.0
                    
                    let localStudPosition = SCNVector3(localX, localY, localZ)
                    let worldPos = brick.convertPosition(localStudPosition, to: nil)
                    
                    let gridKey = GridPoint(Int(round(worldPos.x / gridSize)), brickSupportLevel, Int(round(worldPos.z / gridSize)))
                    studs[gridKey] = (pos: worldPos, owner: brick)
                }
            }
        }
        return studs
    }
    
    private func findValidPlacement(for template: BrickTemplate, near worldPosition: SCNVector3) -> SCNVector3? {
        let newBrickSize = getEffectiveSize(for: template)
        let availableStuds = getAvailableStuds()
        let occupiedVolume = buildSceneOccupationMap()

        var bestCandidate: SCNVector3?
        var minDistanceSq = Float.infinity

        let searchRadius: Float = 2.0 * gridSize
        let nearbyStuds = availableStuds.filter { (gridKey, studData) in
            let distSq = (studData.pos.x - worldPosition.x) * (studData.pos.x - worldPosition.x) +
                         (studData.pos.z - worldPosition.z) * (studData.pos.z - worldPosition.z)
            return distSq < searchRadius * searchRadius
        }
        
        // 如果附近没有支撑点，则将虚拟地面点加入考虑
        var allPossibleAnchors = nearbyStuds
        if nearbyStuds.isEmpty {
            let snappedX = round(worldPosition.x / gridSize) * gridSize
            let snappedZ = round(worldPosition.z / gridSize) * gridSize
            let groundAnchorPos = SCNVector3(snappedX, 0, snappedZ)
            let groundAnchorKey = GridPoint(Int(round(snappedX/gridSize)), -1, Int(round(snappedZ/gridSize)))
            if let ground = groundNode {
                allPossibleAnchors[groundAnchorKey] = (pos: groundAnchorPos, owner: ground)
            }
        }
        
        for (targetStudKey, (targetStudWorldPos, _)) in allPossibleAnchors {
            for r_anchor in 0..<newBrickSize.height {
                for c_anchor in 0..<newBrickSize.width {
                    // 计算锚点相对于新积木中心的偏移
                    let anchorOffsetX = (Float(c_anchor) - Float(newBrickSize.width - 1) / 2.0) * gridSize
                    let anchorOffsetZ = (Float(r_anchor) - Float(newBrickSize.height - 1) / 2.0) * gridSize
                    
                    // 基于支撑点层级计算新砖块的中心高度
                    let newBrickY = (Float(targetStudKey.y) + 1.0) * brickStackingHeight + brickBodyHeight / 2.0
                    
                    let candidatePosition = SCNVector3(
                        targetStudWorldPos.x - anchorOffsetX,
                        newBrickY,
                        targetStudWorldPos.z - anchorOffsetZ
                    )
                    
                    let requiredFootprint = getFootprint(for: template, at: candidatePosition)
                    let isSupported = requiredFootprint.isSubset(of: Set(availableStuds.keys))
                    
                    if isSupported {
                        if occupiedVolume.isDisjoint(with: getProspectiveOccupiedVolume(for: template, at: candidatePosition)) {
                            // 位置有效，计算它与用户原始点击点的距离
                            let distSq = (candidatePosition - worldPosition).lengthSquared
                            if distSq < minDistanceSq {
                                minDistanceSq = distSq
                                bestCandidate = candidatePosition
                            }
                        }
                    }
                }
            }
        }

        return bestCandidate
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
    
    private func getEffectiveSize(for template: BrickTemplate) -> BrickSize {
        if currentRotation == 1 || currentRotation == 3 { // 90° or 270°
            return BrickSize(width: template.size.height, height: template.size.width)
        }
        return template.size
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
        
        brickNode.setValue(template.color.rawValue, forKey: "originalColor")
        
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
    
    private func getBrickSize(_ brick: SCNNode) -> BrickSize {
            if let name = brick.name, name.hasPrefix("brick_") {
                let components = name.components(separatedBy: "_")
                if components.count >= 3, let width = Int(components[1]), let height = Int(components[2]) {
                    return BrickSize(width: width, height: height)
                }
            }
            return BrickSize(width: 2, height: 2)
        }
    
    private func addPlaceAnimation(to node: SCNNode) {
        let scaleUp = SCNAction.scale(to: 1.1, duration: 0.1)
        let scaleDown = SCNAction.scale(to: 1.0, duration: 0.1)
        let sequence = SCNAction.sequence([scaleUp, scaleDown])
        
        node.runAction(sequence)
    }
}

