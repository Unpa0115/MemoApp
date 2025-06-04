import SwiftUI
import SwiftData

// MARK: - Category List View

struct CategoryListView: View {
    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<Category> { category in
            category.parent == nil
        },
        sort: \Category.orderIndex,
        order: .forward
    ) private var rootCategories: [Category]
    
    @State private var showingAddCategory = false
    @State private var editingCategory: Category?
    @State private var showAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(rootCategories) { category in
                    CategoryRowView(
                        category: category,
                        level: 0,
                        onEdit: { editingCategory = category },
                        onDelete: { deleteCategory(category) }
                    )
                }
                .onMove(perform: moveCategories)
            }
            .navigationTitle("カテゴリ")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddCategory = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategoryView()
            }
            .sheet(item: $editingCategory) { category in
                EditCategoryView(category: category)
            }
            .alert("エラー", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func moveCategories(from offsets: IndexSet, to destination: Int) {
        var current = Array(rootCategories)
        current.move(fromOffsets: offsets, toOffset: destination)
        
        for (index, category) in current.enumerated() {
            category.orderIndex = index
        }
        
        do {
            try context.save()
        } catch {
            errorMessage = "カテゴリの並び替えに失敗しました: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func deleteCategory(_ category: Category) {
        context.delete(category)
        do {
            try context.save()
        } catch {
            errorMessage = "カテゴリの削除に失敗しました: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

// MARK: - Category Row View

struct CategoryRowView: View {
    let category: Category
    let level: Int
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                // インデント
                HStack(spacing: 0) {
                    ForEach(0..<level, id: \.self) { _ in
                        Rectangle()
                            .frame(width: 20, height: 1)
                            .opacity(0)
                    }
                }
                
                // 展開/折りたたみボタン
                if !category.subCategories.isEmpty {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Rectangle()
                        .frame(width: 16, height: 16)
                        .opacity(0)
                }
                
                // カテゴリ名とメモ数
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.body)
                    Text("\(category.subNotes.count)件のメモ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .swipeActions {
                Button("削除", role: .destructive, action: onDelete)
                Button("編集", action: onEdit)
            }
            
            // 子カテゴリ
            if isExpanded {
                ForEach(category.subCategories.sorted { $0.orderIndex < $1.orderIndex }) { subCategory in
                    CategoryRowView(
                        category: subCategory,
                        level: level + 1,
                        onEdit: onEdit,
                        onDelete: onDelete
                    )
                }
            }
        }
    }
}

// MARK: - Add Category View

struct AddCategoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.name, order: .forward) private var allCategories: [Category]
    
    @State private var categoryName = ""
    @State private var selectedParent: Category?
    @State private var showAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("カテゴリ情報") {
                    TextField("カテゴリ名を入力", text: $categoryName)
                    
                    Picker("親カテゴリを選択", selection: $selectedParent) {
                        Text("なし（ルート階層）").tag(Category?.none)
                        ForEach(allCategories) { category in
                            Text(category.name).tag(category as Category?)
                        }
                    }
                }
            }
            .navigationTitle("新規カテゴリ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("作成") {
                        createCategory()
                    }
                    .disabled(categoryName.isEmpty)
                }
            }
            .alert("エラー", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func createCategory() {
        let orderIndex = selectedParent?.subCategories.count ?? rootCategoriesCount()
        let newCategory = Category(name: categoryName, orderIndex: orderIndex, parent: selectedParent)
        
        context.insert(newCategory)
        
        do {
            try context.save()
            dismiss()
        } catch {
            errorMessage = "カテゴリの作成に失敗しました: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func rootCategoriesCount() -> Int {
        allCategories.filter { $0.parent == nil }.count
    }
}

// MARK: - Edit Category View

struct EditCategoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.name, order: .forward) private var allCategories: [Category]
    
    let category: Category
    @State private var categoryName = ""
    @State private var selectedParent: Category?
    @State private var showAlert = false
    @State private var errorMessage = ""
    
    var availableParents: [Category] {
        allCategories.filter { $0.id != category.id && !isDescendant(of: category, candidate: $0) }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("カテゴリ情報") {
                    TextField("カテゴリ名", text: $categoryName)
                    
                    Picker("親カテゴリ", selection: $selectedParent) {
                        Text("なし（ルート階層）").tag(Category?.none)
                        ForEach(availableParents) { parent in
                            Text(parent.name).tag(parent as Category?)
                        }
                    }
                }
            }
            .navigationTitle("カテゴリ編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveCategory()
                    }
                    .disabled(categoryName.isEmpty)
                }
            }
            .onAppear {
                categoryName = category.name
                selectedParent = category.parent
            }
            .alert("エラー", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func isDescendant(of ancestor: Category, candidate: Category) -> Bool {
        var current = candidate.parent
        while let parent = current {
            if parent.id == ancestor.id {
                return true
            }
            current = parent.parent
        }
        return false
    }
    
    private func saveCategory() {
        category.name = categoryName
        category.parent = selectedParent
        
        do {
            try context.save()
            dismiss()
        } catch {
            errorMessage = "カテゴリの更新に失敗しました: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

// MARK: - Category Selection Modal

struct CategorySelectionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.name, order: .forward) private var allCategories: [Category]
    
    @Binding var selectedCategories: [Category]
    @State private var searchText = ""
    @State private var showAlert = false
    @State private var errorMessage = ""
    
    var filteredCategories: [Category] {
        if searchText.isEmpty {
            return allCategories
        }
        return allCategories.filter { category in
            category.name.localizedStandardContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // 検索バー
                TextField("カテゴリを検索…", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                // 選択されたカテゴリの表示
                if !selectedCategories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedCategories, id: \.id) { category in
                                CategoryChipView(
                                    category: category,
                                    onRemove: {
                                        selectedCategories.removeAll { $0.id == category.id }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                }
                
                // カテゴリリスト
                List {
                    ForEach(filteredCategories) { category in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.name)
                                    .font(.body)
                                Text("\(category.subNotes.count)件のメモ")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedCategories.contains(where: { $0.id == category.id }) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleCategory(category)
                        }
                    }
                    
                    // 新規カテゴリ作成ボタン
                    if !searchText.isEmpty && !filteredCategories.contains(where: { $0.name.lowercased() == searchText.lowercased() }) {
                        Button(action: createNewCategory) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("'\(searchText)' を新規作成")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("カテゴリ選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .alert("エラー", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func toggleCategory(_ category: Category) {
        if let index = selectedCategories.firstIndex(where: { $0.id == category.id }) {
            selectedCategories.remove(at: index)
        } else {
            selectedCategories.append(category)
        }
    }
    
    private func createNewCategory() {
        let newCategory = Category(name: searchText, orderIndex: allCategories.count, parent: nil)
        context.insert(newCategory)
        
        do {
            try context.save()
            selectedCategories.append(newCategory)
            searchText = ""
        } catch {
            errorMessage = "カテゴリの作成に失敗しました: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

// MARK: - Category Chip View

struct CategoryChipView: View {
    let category: Category
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(category.name)
                .font(.caption)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.1))
        )
        .foregroundColor(.blue)
    }
} 