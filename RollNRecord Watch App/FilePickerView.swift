import SwiftUI
import WatchConnectivity

class FileSync: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = FileSync()
    private var session: WCSession?
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    func syncFiles(at urls: [URL]) {
        guard let session = session, session.isReachable else { return }
        
        for url in urls {
            do {
                _ = try Data(contentsOf: url) 
                let filename = url.lastPathComponent
                session.transferFile(url, metadata: ["name": filename])
                print("✈️ Syncing file: \(filename)")
            } catch {
                print("❌ Failed to sync file: \(error.localizedDescription)")
            }
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ WCSession activation failed: \(error.localizedDescription)")
        }
    }
}

struct FilePickerView: View {
    @StateObject private var fileSync = FileSync.shared
    @State private var files: [String] = []
    @State private var selectedFiles: Set<String> = []
    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @FocusState private var isListFocused: Bool
    
    var body: some View {
        NavigationView {
            Group {
                if files.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(files, id: \.self) { file in
                            if isEditing {
                                editableRow(for: file)
                            } else {
                                navigableRow(for: file)
                            }
                        }
                        .onDelete(perform: deleteFiles)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Records")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        if !files.isEmpty {
                            Button(action: {
                                isEditing.toggle()
                                if !isEditing {
                                    selectedFiles.removeAll()
                                }
                            }) {
                                Text(isEditing ? "Done" : "Edit")
                            }
                            Spacer()
                            Button(action: {
                                showDeleteConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    if isEditing && !selectedFiles.isEmpty {
                                        Text("Selected")
                                    }
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text(isEditing ? "Delete Selected Files" : "Delete All Files"),
                    message: Text("Are you sure you want to delete \(isEditing ? "the selected files" : "all files")?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if isEditing {
                            deleteSelectedFiles()
                        } else {
                            deleteAllFiles()
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .onAppear {
                loadFiles()
                isListFocused = true
            }
            .focused($isListFocused)
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 36))
                .foregroundStyle(.orange.gradient)
            
            Text("No Recordings")
                .font(.system(size: 16, weight: .medium))
            
            Text("Start your first recording")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            
            NavigationLink(destination: ZiplineTrackerView()) {
                Label("Record", systemImage: "record.circle")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.top, 8)
        }
        .padding()
    }
    
    private func loadFiles() {
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
                let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }
                
                
                cleanupEmptyFiles(jsonFiles)
                
                
                files = jsonFiles
                    .filter { url in
                        
                        guard let data = try? Data(contentsOf: url) else { return false }
                        return !data.isEmpty
                    }
                    .sorted { url1, url2 in
                        
                        let name1 = url1.lastPathComponent
                        let name2 = url2.lastPathComponent
                        let date1 = extractDateFromFilename(name1)
                        let date2 = extractDateFromFilename(name2)
                        return date1 > date2
                    }
                    .map { $0.lastPathComponent }
                
                
                fileSync.syncFiles(at: jsonFiles)
            } catch {
                print("❌ Error loading files: \(error.localizedDescription)")
            }
        }
    }
    
    private func cleanupEmptyFiles(_ urls: [URL]) {
        for url in urls {
            guard let data = try? Data(contentsOf: url) else { continue }
            if data.isEmpty {
                try? FileManager.default.removeItem(at: url)
                print("🗑️ Removed empty file: \(url.lastPathComponent)")
            }
        }
    }
    
    private func extractDateFromFilename(_ filename: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        
        let dateString = filename
            .replacingOccurrences(of: "zipline_", with: "")
            .replacingOccurrences(of: "drop_", with: "")
            .replacingOccurrences(of: "_zip.json", with: "")
            .replacingOccurrences(of: "_drop.json", with: "")
        
        return formatter.date(from: dateString) ?? .distantPast
    }
    
    private func formatFilename(_ filename: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        
        let dateString = filename
            .replacingOccurrences(of: "zipline_", with: "")
            .replacingOccurrences(of: "_zip.json", with: "")
            .replacingOccurrences(of: "drop_", with: "")
            .replacingOccurrences(of: "_drop.json", with: "")
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            displayFormatter.doesRelativeDateFormatting = true 
            return displayFormatter.string(from: date)
        }
        return filename
    }
    
    private func toggleSelection(for file: String) {
        if selectedFiles.contains(file) {
            selectedFiles.remove(file)
        } else {
            selectedFiles.insert(file)
        }
    }
    
    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let file = files[index]
            deleteFile(named: file)
        }
        files.remove(atOffsets: offsets)
    }
    
    private func deleteFile(named filename: String) {
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentsPath.appendingPathComponent(filename)
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                print("❌ Error deleting file: \(error.localizedDescription)")
            }
        }
    }
    
    private func deleteAllFiles() {
        for file in files {
            deleteFile(named: file)
        }
        files.removeAll()
    }
    
    private func deleteSelectedFiles() {
        for file in selectedFiles {
            deleteFile(named: file)
            if let index = files.firstIndex(of: file) {
                files.remove(at: index)
            }
        }
        selectedFiles.removeAll()
    }
    
    private func activityIcon(for filename: String) -> (icon: String, color: Color) {
        if filename.contains("_zip.json") {
            return ("figure.climbing", .blue)
        } else if filename.contains("_drop.json") {
            return ("arrow.down.to.line.alt", .red)
        }
        return ("questionmark.circle", .gray)
    }
    
    private func editableRow(for file: String) -> some View {
        Button(action: {
            toggleSelection(for: file)
        }) {
            HStack {
                Image(systemName: selectedFiles.contains(file) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedFiles.contains(file) ? .blue : .secondary)
                let activity = activityIcon(for: file)
                Image(systemName: activity.icon)
                    .foregroundStyle(activity.color)
                Text(formatFilename(file))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .contentShape(Rectangle())
        }
    }
    
    private func navigableRow(for file: String) -> some View {
        NavigationLink(destination: ViewRecordings(filename: file, isFromRecording: false)) {
            HStack {
                let activity = activityIcon(for: file)
                Image(systemName: activity.icon)
                    .foregroundStyle(activity.color)
                Text(formatFilename(file))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .contentShape(Rectangle())
        }
    }
}

#Preview {
    FilePickerView()
}
