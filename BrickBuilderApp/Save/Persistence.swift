import Foundation
import UIKit

// MARK: - Codable Data Models for Saving/Loading
struct SavedBrick: Codable {
    let sizeW: Int
    let sizeH: Int
    let colorHex: String
    let positionX: Float
    let positionY: Float
    let positionZ: Float
    let rotationY: Float
}

struct SavedProject: Codable {
    let groundWidth: Int
    let groundLength: Int
    let groundHeight: Double
    let groundColorHex: String
    let bricks: [SavedBrick]
    let cameraZoom: Float
    let cameraPosition: [Float]
    let cameraRotation: [Float]
}

// MARK: - PersistenceManager
class PersistenceManager {

    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    func save(project: SavedProject, withName name: String) throws {
        let filename = getDocumentsDirectory().appendingPathComponent("\(name).legoProject")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(project)
        try data.write(to: filename, options: [.atomicWrite, .completeFileProtection])
    }

    func load(fromName name: String) throws -> SavedProject {
        let filename = getDocumentsDirectory().appendingPathComponent("\(name).legoProject")
        let data = try Data(contentsOf: filename)
        let project = try JSONDecoder().decode(SavedProject.self, from: data)
        return project
    }

    func listProjects() -> [String] {
        let fileManager = FileManager.default
        let documentsURL = getDocumentsDirectory()
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            return fileURLs
                .filter { $0.pathExtension == "legoProject" }
                .map { $0.deletingPathExtension().lastPathComponent }
                .sorted()
        } catch {
            print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
            return []
        }
    }

    func delete(projectName name: String) throws {
        let filename = getDocumentsDirectory().appendingPathComponent("\(name).legoProject")
        try FileManager.default.removeItem(at: filename)
    }
}

// MARK: - Helper Extensions
extension UIColor {
    func toHex() -> String? {
        guard let components = cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}

extension BrickColor {
    static func from(hex: String) -> BrickColor {
        let cleanHex = hex.uppercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
       
        switch cleanHex {
        case "#FF0000", "#F00": return .red
        case "#0000FF", "#00F": return .blue
        case "#FFFF00", "#FF0": return .yellow
        case "#008000", "#080": return .green
        case "#FFFFFF", "#FFF": return .white
        case "#000000", "#000": return .black
        case "#FFA500": return .orange
        case "#800080": return .purple
        case "#808080": return .gray
        case "#A52A2A": return .brown
        case "#FFC0CB": return .pink
        case "#ADD8E6": return .lightBlue
        default:
            return matchColorByApproximation(hex: cleanHex)
        }
    }
    
    private static func matchColorByApproximation(hex: String) -> BrickColor {
        guard hex.hasPrefix("#"), hex.count == 7 else { return .gray }
        
        let hexString = String(hex.dropFirst())
        guard let hexValue = Int(hexString, radix: 16) else { return .gray }
        
        let r = (hexValue >> 16) & 0xFF
        let g = (hexValue >> 8) & 0xFF
        let b = hexValue & 0xFF
        
        // 定义标准颜色的RGB值
        let standardColors: [(BrickColor, (r: Int, g: Int, b: Int))] = [
            (.red, (255, 0, 0)),
            (.blue, (0, 0, 255)),
            (.yellow, (255, 255, 0)),
            (.green, (0, 128, 0)),
            (.white, (255, 255, 255)),
            (.black, (0, 0, 0)),
            (.orange, (255, 165, 0)),
            (.purple, (128, 0, 128)),
            (.gray, (128, 128, 128)),
            (.brown, (165, 42, 42)),
            (.pink, (255, 192, 203)),
            (.lightBlue, (173, 216, 230))
        ]
        
        var minDistance = Int.max
        var closestColor: BrickColor = .gray
        
        for (color, (sr, sg, sb)) in standardColors {
            let distance = abs(r - sr) + abs(g - sg) + abs(b - sb)
            if distance < minDistance {
                minDistance = distance
                closestColor = color
            }
        }
        
        return closestColor
    }
}

