import Foundation

struct BrickSize: Hashable, Equatable {
    let width: Int  // studs
    let height: Int // studs
    
    static let availableSizes = [
        BrickSize(width: 1, height: 1),
        BrickSize(width: 1, height: 2),
        BrickSize(width: 1, height: 3),
        BrickSize(width: 1, height: 4),
        BrickSize(width: 1, height: 6),
        BrickSize(width: 1, height: 8),
        BrickSize(width: 2, height: 2),
        BrickSize(width: 2, height: 3),
        BrickSize(width: 2, height: 4),
        BrickSize(width: 2, height: 6),
        BrickSize(width: 2, height: 8),
        BrickSize(width: 3, height: 3),
        BrickSize(width: 4, height: 4),
    ]
    
    var displayName: String {
        return "\(width)×\(height)"
    }
}

struct BrickTemplate: Hashable, Equatable {
    let size: BrickSize
    let color: BrickColor
    
    static func == (lhs: BrickTemplate, rhs: BrickTemplate) -> Bool {
        return lhs.size == rhs.size && lhs.color == rhs.color
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(size)
        hasher.combine(color)
    }
}

