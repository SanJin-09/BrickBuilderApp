import SwiftUI

struct ProjectManagementView: View {
    @ObservedObject var sceneCoordinator: SceneCoordinator
    @Environment(\.dismiss) var dismiss
    
    @State private var newProjectName: String = ""
    @State private var savedProjects: [String] = []
    @State private var showAlert = false
    @State private var projectToDelete: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 保存部分
                HStack {
                    TextField("新项目名称", text: $newProjectName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()

                    Button(action: saveProject) {
                        Text("保存")
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            .background(newProjectName.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(newProjectName.isEmpty)
                    .padding(.trailing)
                }
                .background(Color(.systemGroupedBackground))

                // 项目列表
                List {
                    ForEach(savedProjects, id: \.self) { name in
                        HStack {
                            Text(name)
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("加载") {
                                sceneCoordinator.loadProject(name: name)
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            
                            Button(role: .destructive) {
                                self.projectToDelete = name
                                self.showAlert = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .onAppear(perform: refreshProjectList)
            .navigationTitle("项目管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("确认删除", isPresented: $showAlert, presenting: projectToDelete) { project in
                Button("删除 '\(project)'", role: .destructive) {
                    sceneCoordinator.deleteProject(name: project)
                    refreshProjectList()
                }
            }
        }
    }

    private func saveProject() {
        sceneCoordinator.saveProject(name: newProjectName)
        newProjectName = ""
        refreshProjectList()
        // 让键盘消失
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func refreshProjectList() {
        savedProjects = sceneCoordinator.listSavedProjects()
    }
}
