import UIKit

enum BrickColor: String, CaseIterable, Hashable {
    case red = "红色"
    case blue = "蓝色"
    case green = "绿色"
    case yellow = "黄色"
    case orange = "橙色"
    case purple = "紫色"
    case white = "白色"
    case black = "黑色"
    case gray = "灰色"
    case brown = "棕色"
    case pink = "粉色"
    case lightBlue = "浅蓝"
    
    var uiColor: UIColor {
        switch self {
        case .red: return UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1.0)
        case .blue: return UIColor(red: 0.1, green: 0.4, blue: 0.8, alpha: 1.0)
        case .green: return UIColor(red: 0.2, green: 0.7, blue: 0.2, alpha: 1.0)
        case .yellow: return UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        case .orange: return UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
        case .purple: return UIColor(red: 0.6, green: 0.3, blue: 0.8, alpha: 1.0)
        case .white: return UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        case .black: return UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
        case .gray: return UIColor.systemGray
        case .brown: return UIColor.brown
        case .pink: return UIColor(red: 1.0, green: 0.4, blue: 0.7, alpha: 1.0)
        case .lightBlue: return UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
        }
    }
}
