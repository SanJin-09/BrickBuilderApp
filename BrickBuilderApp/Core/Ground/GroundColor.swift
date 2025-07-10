import UIKit

enum GroundColor: CaseIterable, Codable{
    case gray, green, blue, brown, tan, white, black, red
    
    var uiColor: UIColor {
        switch self {
        case .gray: return .systemGray
        case .green: return .systemGreen
        case .blue: return .systemBlue
        case .brown: return .brown
        case .tan: return .systemOrange
        case .white: return .white
        case .black: return .black
        case .red: return .systemRed
        }
    }
}
