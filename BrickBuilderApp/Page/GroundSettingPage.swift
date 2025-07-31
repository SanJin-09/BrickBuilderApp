import SwiftUI

struct GroundSettingPage: View {

    @ObservedObject var sceneCoordinator: SceneCoordinator
    
    @Environment(\.dismiss) private var dismiss
    
    @State var groundLength: Double = 8
    @State var groundHeight: Double = 0.3
    @State private var isSheet: Bool = true
    @State private var selectedColor: Color = .gray
    @State private var myColor: [Color] = []
    
    private let MAIN_BG_COLOR = Color(hex: "#FFFFF8")
    private let MAIN_CARD_COLOR = Color(hex: "#3A3A3A")
    private let SECONDARY_TEXT_COLOR = Color(hex: "#C2C2BB")
    private let DIVIDER_COLOR = Color(hex: "#AAAAAA")

    // MARK: - Page
    var body: some View {
        ZStack {
            MAIN_BG_COLOR.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    
                    // 地面边长与高度设置
                    lengthAndHeightSettingsCard
                    
                    // 地面颜色设置
                    colorSettingsCard
                    
                    // 确认按钮
                    ensureButton
                    
                    Spacer()
                }
                .padding()
            }
        }
    }

    // MARK: - Components
    private var lengthAndHeightSettingsCard: some View {
        VStack(spacing: 15) {
            // 标题
            HStack {
                Text("地面边长与高度设置")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundColor(SECONDARY_TEXT_COLOR)
                Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(SECONDARY_TEXT_COLOR)
                Spacer()
            }
            
            // 设置内容
            VStack(spacing: 10) {
                // 边长设置
                HStack {
                    Slider(value: $groundLength, in: 0...60, step: 1)
                        .tint(MAIN_BG_COLOR)
                    Text("[\(Int(groundLength))]")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(MAIN_BG_COLOR)
                        .frame(width: 50)
                }
                
                Divider().background(DIVIDER_COLOR)
                
                // 板型开启按钮
                Toggle("薄板地面", isOn: $isSheet)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(MAIN_BG_COLOR)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
            }
            .padding()
            .background(MAIN_CARD_COLOR)
            .cornerRadius(32)
            .shadow(color: .black.opacity(0.5), radius: 3, y: 3)
        }
    }
    
    private var colorSettingsCard: some View {
        VStack(spacing: 15) {
            // 标题
            HStack {
                Text("地面颜色设置")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundColor(SECONDARY_TEXT_COLOR)
                Image(systemName: "drop.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(SECONDARY_TEXT_COLOR)
                Spacer()
            }
            
            // 调色板
            VStack(spacing: 20) {
                ColorPickerView(selectedColor: $selectedColor)
                    .frame(height: 200)
                
                Divider().background(DIVIDER_COLOR)
                
                VStack(spacing: 15) {
                    HStack {
                        Text("当前颜色")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(MAIN_BG_COLOR)
                        Spacer()
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedColor)
                            .frame(width: 50, height: 50)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .circular)
                                    .stroke(Color(MAIN_BG_COLOR), lineWidth: 3.0)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack{
                            Text("我的颜色")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(MAIN_BG_COLOR)
                            
                            Button(action: {
                                myColor.append(selectedColor)
                            }){
                                Image(systemName: "plus.app.fill")
                                    .font(.system(size: 18.0))
                                    .imageScale(.small)
                            }
                            .buttonBorderShape(.capsule)
                            .tint(Color(red: 1.0, green: 1.0, blue: 0.96676))
                        }
                        .frame(alignment: .center)
                        
                        // 为队列中的美中颜色创建色卡
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(myColor, id: \.self) { color in
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(color)
                                        .frame(width: 35, height: 35)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6, style: .circular)
                                                .stroke(Color(MAIN_BG_COLOR), lineWidth: 3.0)
                                        )
                                        .onTapGesture {
                                            self.selectedColor = color
                                        }
                                }
                            }
                            .frame(height: 60, alignment: .center)
                        }
                    }
                }
            }
            .padding()
            .background(MAIN_CARD_COLOR)
            .cornerRadius(32)
            .shadow(color: .black.opacity(0.5), radius: 3, y: 3)
        }
    }
    
    private var ensureButton: some View {
        VStack{
            Button(action: {
                // 根据是否选择薄板地面设置地面高度
                if !isSheet {
                    groundHeight = 0.6
                }
                
                // 更新地面
                sceneCoordinator.updateGround(
                    width: Int(groundLength),
                    length: Int(groundLength),
                    height: groundHeight,
                    color: UIColor(selectedColor)
                )
                
                // 关闭页面
                dismiss()
            }) {
                HStack(spacing: 4.0) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32.0))
                }
                .frame(width: 50.0, height: 50.0)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .shadow(color: .black.opacity(0.5), radius: 3, y: 3)
            .tint(.green)
        }
    }
}


private struct ColorPickerView: View {
    
    @Binding var selectedColor: Color
    @State private var hue: CGFloat = 0.0
    
    var body: some View {
        HStack(spacing: 20) {
            ColorPickerSquare(selectedColor: $selectedColor, hue: $hue)
            HueSlider(hue: $hue)
        }
    }
}

private struct ColorPickerSquare: View {
    @Binding var selectedColor: Color
    @Binding var hue: CGFloat
    @State private var pickerPosition: CGPoint = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(hue: hue, saturation: 1.0, brightness: 1.0)
                
                LinearGradient(gradient: Gradient(colors: [.white, .clear]), startPoint: .leading, endPoint: .trailing)
                
                LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .top, endPoint: .bottom)
                
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .position(pickerPosition)
            }
            .cornerRadius(16)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateSelection(at: value.location, in: geometry.size)
                    }
            )
            .onAppear {
                updatePickerPosition(from: selectedColor, in: geometry.size)
            }
            .onChange(of: selectedColor) {
                updatePickerPosition(from: selectedColor, in: geometry.size)
            }
        }
    }
    
    private func updateSelection(at location: CGPoint, in size: CGSize) {
        let boundedLocation = CGPoint(
            x: max(0, min(location.x, size.width)),
            y: max(0, min(location.y, size.height))
        )
        pickerPosition = boundedLocation
        
        let saturation = boundedLocation.x / size.width
        let brightness = 1.0 - (boundedLocation.y / size.height)
        
        selectedColor = Color(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    private func updatePickerPosition(from color: Color, in size: CGSize) {
        let hsb = color.hsb
        if abs(hsb.hue - hue) < 0.01 {
            pickerPosition = CGPoint(
                x: hsb.saturation * size.width,
                y: (1.0 - hsb.brightness) * size.height
            )
        }
    }
}

private struct HueSlider: View {
    @Binding var hue: CGFloat
    
    private let hueGradient = Gradient(colors: [
        .red, .yellow, .green, .cyan, .blue, .purple, .red
    ])
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(gradient: hueGradient, startPoint: .top, endPoint: .bottom))
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 1))
                    .offset(y: (hue * geometry.size.height) - 12)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newHue = min(max(0, value.location.y / geometry.size.height), 1)
                        self.hue = newHue
                    }
            )
        }
        .frame(width: 25)
    }
}
