import SwiftUI
import PhotosUI
import Vision
import CoreML

// MARK: - メイン画面管理 (ContentView)
struct ContentView: View {
    @State private var hasStarted = false
    @State private var isGameActive = false
    @State private var selectedImage: UIImage? = nil
    @State private var sharedBgImage: UIImage? = nil
    @State private var keepBgImageOnce = false
    @State private var selectedDifficulty: Int = 5

    @State private var playingCollectionItem: CollectionItem? = nil

    var body: some View {
        GeometryReader { geometry in
            let screenSize = geometry.size

            ZStack {
                if !hasStarted {
                    StartView(hasStarted: $hasStarted, sharedBgImage: $sharedBgImage, keepBgImageOnce: $keepBgImageOnce, screenSize: screenSize)
                        .transition(.opacity)
                } else if isGameActive, let image = selectedImage {
                    GameView(targetImage: image, isGameActive: $isGameActive, targetCount: selectedDifficulty, screenSize: screenSize, playingCollectionItem: playingCollectionItem)
                        .transition(.opacity)
                } else {
                    HomeView(
                        hasStarted: $hasStarted,
                        sharedBgImage: $sharedBgImage,
                        keepBgImageOnce: $keepBgImageOnce,
                        selectedImage: $selectedImage,
                        isGameActive: $isGameActive,
                        selectedDifficulty: $selectedDifficulty,
                        playingCollectionItem: $playingCollectionItem,
                        screenSize: screenSize
                    )
                    .transition(.opacity)
                }
            }
            .frame(width: screenSize.width, height: screenSize.height)
        }
    }
}

// MARK: - スタート画面 (StartView)
struct StartView: View {
    @Binding var hasStarted: Bool
    @Binding var sharedBgImage: UIImage?
    @Binding var keepBgImageOnce: Bool
    let screenSize: CGSize

    @State private var isBlinking = false

    var body: some View {
        ZStack {
            WalkingBackgroundView(currentImage: $sharedBgImage, screenSize: screenSize)
            Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
            VStack(spacing: 20) {
                Spacer()
                Text("I SPY")
                    .font(.system(size: 60, weight: .light, design: .serif))
                    .foregroundColor(.white)
                    .tracking(10)
                    .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 5)
                Text("Go find a piece of everyday scenery")
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundColor(.white.opacity(isBlinking ? 1.0 : 0.2))
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isBlinking)
                Spacer().frame(height: 120)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            keepBgImageOnce = true
            withAnimation(.easeInOut(duration: 1.0)) { hasStarted = true }
        }
        .onAppear { isBlinking = true }
    }
}

struct WalkingBackgroundView: View {
    @EnvironmentObject var store: CollectionStore
    @Binding var currentImage: UIImage?
    let screenSize: CGSize

    @State private var zoomScale: CGFloat = 1.0
    @State private var stepOffset: CGFloat = 0.0
    @State private var imageID = UUID()

    let timer = Timer.publish(every: 10.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            if let img = currentImage {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: screenSize.width, height: screenSize.height)
                    .scaleEffect(zoomScale).offset(y: stepOffset).clipped().id(imageID)
                    .transition(.opacity.animation(.easeInOut(duration: 3.0)))
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear { changeImageAndAnimate() }
        .onReceive(timer) { _ in changeImageAndAnimate() }
    }

    private func changeImageAndAnimate() {
        withAnimation(.easeInOut(duration: 3.0)) {
            if store.items.isEmpty {
                currentImage = UIImage(named: "DefaultBackground.jpg")
            } else {
                if let randomItem = store.items.randomElement(), let uiImage = UIImage(data: randomItem.imageData) {
                    currentImage = uiImage
                } else {
                    currentImage = UIImage(named: "DefaultBackground.jpg")
                }
            }
            imageID = UUID()

            zoomScale = 1.0
            stepOffset = 0.0
        }

        withAnimation(.linear(duration: 10.0)) { zoomScale = 1.25 }
        withAnimation(.easeInOut(duration: 1.0).repeatCount(10, autoreverses: true)) { stepOffset = 15.0 }
    }
}

// MARK: - ホーム画面 (HomeView)
struct HomeView: View {
    @Binding var hasStarted: Bool
    @Binding var sharedBgImage: UIImage?
    @Binding var keepBgImageOnce: Bool
    @Binding var selectedImage: UIImage?
    @Binding var isGameActive: Bool
    @Binding var selectedDifficulty: Int
    @Binding var playingCollectionItem: CollectionItem?
    let screenSize: CGSize

    @EnvironmentObject var store: CollectionStore

    @State private var searchText = ""
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showPhotoLibrary = false
    @State private var showActionSheet = false

    @State private var setupImage: UIImage? = nil
    @State private var showSetup = false
    @State private var selectedCollectionItem: CollectionItem? = nil

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false
    @State private var isFirstTimeOnboarding = false

    @State private var itemToDelete: CollectionItem? = nil
    @State private var showDeleteAlert = false

    func handleImagePicked(_ image: UIImage) {
        self.playingCollectionItem = nil
        self.setupImage = image
        self.showSetup = true
    }

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            hasStarted = false
                        }
                    }) {
                        Image(systemName: "house")
                            .font(.title2)
                            .foregroundColor(.white)
                            .glassEffect()
                    }

                    Spacer()

                    Button(action: {
                        isFirstTimeOnboarding = false
                        showOnboarding = true
                    }) {
                        Image(systemName: "questionmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .glassEffect()
                    }
                }
                .padding(.top, 30)
                .padding(.horizontal, 30)

                Spacer()

                ScrollView {
                    let columns = [
                        GridItem(.flexible(), spacing: 20),
                        GridItem(.flexible(), spacing: 20)
                    ]

                    LazyVGrid(columns: columns, spacing: 30) {
                        VStack(spacing: 12) {
                            Image(systemName: "plus")
                                .font(.system(size: 40, weight: .light))
                            Text("New Search")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 170, maxHeight: 170)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(.ultraThinMaterial.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                )
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 15))
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 3)
                        .onTapGesture { showActionSheet = true }

                        let filteredItems = searchText.isEmpty ? store.items : store.items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }

                        ForEach(filteredItems) { item in
                            VStack(alignment: .center) {
                                if let uiImage = UIImage(data: item.imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 170, maxHeight: 170)
                                        .clipped()
                                        .cornerRadius(15)
                                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.3), lineWidth: 1))
                                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                }

                                Text(item.title)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.top, 5)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCollectionItem = item
                            }
                            .onLongPressGesture {
                                itemToDelete = item
                                showDeleteAlert = true
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }

                Spacer()

                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.white.opacity(0.7))
                    TextField("Search Collection", text: $searchText).font(.title3).foregroundColor(.white)
                }
                .padding(.vertical, 15).padding(.horizontal, 20)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 40).padding(.bottom, 40)
            }
            .background(
                ZStack {
                    Color.white
                    if let img = sharedBgImage {
                        Image(uiImage: img).resizable().scaledToFill().blur(radius: 15)
                            .overlay(.ultraThinMaterial.opacity(0.8))
                            .overlay(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0.1), Color.clear, Color.white.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
                .ignoresSafeArea()
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showSetup) {
                if let img = setupImage {
                    GameStartView(
                        image: img, showSetup: $showSetup, selectedImage: $selectedImage,
                        isGameActive: $isGameActive, difficulty: $selectedDifficulty,
                        sharedBgImage: sharedBgImage, screenSize: screenSize
                    )
                }
            }
            .sheet(item: $selectedCollectionItem) { item in
                CollectionDetailView(
                    item: item,
                    startAction: {
                        self.playingCollectionItem = item
                        if let uiImage = UIImage(data: item.imageData) {
                            self.setupImage = uiImage
                            self.showSetup = true
                        }
                        self.selectedCollectionItem = nil
                    }
                )
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(
                    isPresented: $showOnboarding,
                    isFirstTime: isFirstTimeOnboarding,
                    onStartDemo: {
                        hasSeenOnboarding = true
                        isFirstTimeOnboarding = false
                        if let demoImage = UIImage(named: "DefaultBackground.jpg") {
                            handleImagePicked(demoImage)
                        }
                    }
                )
            }
            .alert("Delete Collection", isPresented: $showDeleteAlert, presenting: itemToDelete) { item in
                Button("Delete", role: .destructive) {
                    if let index = store.items.firstIndex(where: { $0.id == item.id }) {
                        withAnimation {
                            store.items.remove(at: index)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { item in
                Text("Are you sure you want to delete '\(item.title)'?\nRecords of found items will also be erased.")
            }
        }
        .tint(.white)
        .confirmationDialog("Add Photo", isPresented: $showActionSheet, titleVisibility: .hidden) {
            Button("Take a Photo") { showCamera = true }
            Button("Choose from Album") { showPhotoLibrary = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(selectedImage: .init(get: { nil }, set: { img in
                if let img = img { handleImagePicked(img) }
            }))
        }
        .photosPicker(isPresented: $showPhotoLibrary, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                    handleImagePicked(uiImage)
                }
                selectedPhotoItem = nil
            }
        }
        .onAppear {
            if !hasSeenOnboarding {
                isFirstTimeOnboarding = true
                showOnboarding = true
                hasSeenOnboarding = true
            }

            if keepBgImageOnce { keepBgImageOnce = false } else {
                if store.items.isEmpty { sharedBgImage = UIImage(named: "DefaultBackground.jpg") } else {
                    if let randomItem = store.items.randomElement(), let uiImage = UIImage(data: randomItem.imageData) { sharedBgImage = uiImage } else { sharedBgImage = UIImage(named: "DefaultBackground.jpg") }
                }
            }
        }
    }
}

// MARK: - 説明シート (OnboardingView)
struct OnboardingView: View {
    @Binding var isPresented: Bool
    let isFirstTime: Bool
    let onStartDemo: () -> Void

    var body: some View {
        TabView {
            VStack(spacing: 40) {
                Image(systemName: "eye")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.primary)
                Text("Scenery you look at,\nbut don't really see")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                Text("The paths we walk every day, the rooms we spend our time in.\nEven within the scenery we take for granted, there are many hidden little discoveries we've never noticed.\n\nThis app is an 'Everyday Museum' that crops such ordinary scenery and lets you re-examine it from a new perspective.")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineSpacing(8)
            }
            .padding(40)

            VStack(spacing: 30) {
                Image(systemName: "plus.app")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.primary)
                Text("1. Crop the scenery")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                Text("From the '+' (New Search) button on the home screen,\ntake a picture of the scenery in front of you with the camera,\nor select your favorite photo from the album.")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineSpacing(8)
            }
            .padding(40)

            VStack(spacing: 30) {
                Image(systemName: "dial.low")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.primary)
                Text("2. Set the difficulty")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                Text("Choose the number of items to find (difficulty).\nAI will randomly crop shapes from the photo to create a puzzle.")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineSpacing(8)
            }
            .padding(40)

            VStack(spacing: 30) {
                Image(systemName: "sparkles.magnifyingglass")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.primary)
                Text("3. Look for little magic")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                Text("Find the exact same spot as the cutout shown below in the original photo.\n\nTake a close look by zooming and moving the photo with your fingers!")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineSpacing(8)

                Button(action: {
                    isPresented = false
                    if isFirstTime {
                        onStartDemo()
                    }
                }) {
                    Text(isFirstTime ? "Try finding from the first scenery" : "Let's explore!")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .cornerRadius(15)
                        .padding(.top, 20)
                }
            }
            .padding(40)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

// MARK: - ホーム画面用コレクション詳細シート (CollectionDetailView)
struct CollectionDetailView: View {
    let item: CollectionItem
    let startAction: () -> Void
    @Environment(\.dismiss) var dismiss

    @State private var shareImage: Image?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    if let uiImage = UIImage(data: item.imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(15)
                            .shadow(radius: 5)
                            .padding(.horizontal)
                    }

                    Text(item.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 15) {
                        Text("Items found so far")
                            .font(.headline)
                            .padding(.horizontal)

                        if item.targets.isEmpty {
                            Text("No items found yet")
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(item.targets) { target in
                                        if let uiImage = UIImage(data: target.croppedImageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 80, height: 80)
                                                .cornerRadius(10)
                                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    Button(action: startAction) {
                        Text("Find from this photo again")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(15)
                            .padding(.horizontal, 40)
                    }
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Collection Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let shareImg = shareImage {
                        ShareLink(item: shareImg, preview: SharePreview(item.title, image: shareImg)) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.primary)
                        }
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.primary)
                            .opacity(0.3)
                    }
                }
            }
            .onAppear {
                generateShareCard()
            }
        }
    }

    @MainActor
    private func generateShareCard() {
        let cardView = VStack(spacing: 20) {
            if let uiImage = UIImage(data: item.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 350)
                    .cornerRadius(15)
            }
            Text(item.title)
                .font(.title)
                .bold()
                .foregroundColor(.black)

            if !item.targets.isEmpty {
                Text("Items found so far")
                    .font(.headline)
                    .foregroundColor(.gray)

                let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: min(item.targets.count, 4))
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(item.targets.prefix(8)) { target in
                        if let img = UIImage(data: target.croppedImageData) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
        .padding(30)
        .background(Color.white)
        .cornerRadius(20)

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = UIScreen.main.scale
        if let uiImage = renderer.uiImage {
            self.shareImage = Image(uiImage: uiImage)
        }
    }
}

// MARK: - ゲーム設定画面 (GameStartView)
struct GameStartView: View {
    let image: UIImage
    @Binding var showSetup: Bool
    @Binding var selectedImage: UIImage?
    @Binding var isGameActive: Bool
    @Binding var difficulty: Int
    var sharedBgImage: UIImage?
    let screenSize: CGSize

    var body: some View {
        ZStack {
            ZStack {
                Color.white
                if let img = sharedBgImage {
                    Image(uiImage: img).resizable().scaledToFill().blur(radius: 15).overlay(.ultraThinMaterial.opacity(0.8))
                }
            }.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: screenSize.width - 40, maxHeight: screenSize.height * 0.45)
                    .cornerRadius(15).shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

                VStack(spacing: 15) {
                    Text("Select Difficulty").font(.system(size: 22, weight: .bold, design: .serif)).foregroundColor(.white)

                    HStack(spacing: 10) {
                        DifficultyButton(title: "Easy\n(3 items)", value: 3, selectedValue: $difficulty)
                        DifficultyButton(title: "Normal\n(5 items)", value: 5, selectedValue: $difficulty)
                        DifficultyButton(title: "Hard\n(7 items)", value: 7, selectedValue: $difficulty)
                    }
                    .frame(width: screenSize.width - 40)
                }

                Spacer()

                Button(action: {
                    selectedImage = image
                    showSetup = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isGameActive = true }
                }) {
                    Text("Start Game").font(.title3.bold()).foregroundColor(.black).padding().frame(maxWidth: 400)
                        .background(Color.white).cornerRadius(15).shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 3)
                        .padding(.horizontal, 40)
                }.padding(.bottom, 40)
            }.padding(.top, 20)
        }
        .navigationTitle("New Search")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

struct DifficultyButton: View {
    let title: String
    let value: Int
    @Binding var selectedValue: Int

    var body: some View {
        Button(action: { selectedValue = value }) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .serif))
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(selectedValue == value ? .black : .white)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(selectedValue == value ? Color.white : Color.white.opacity(0.2))
                .cornerRadius(15)
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white, lineWidth: selectedValue == value ? 0 : 1))
                .shadow(color: selectedValue == value ? .white.opacity(0.5) : .clear, radius: 5, x: 0, y: 0)
        }
    }
}

// MARK: - ゲーム画面 (タップ判定機能付き)
struct GameView: View {
    let targetImage: UIImage
    @Binding var isGameActive: Bool
    let targetCount: Int
    let screenSize: CGSize
    let playingCollectionItem: CollectionItem?

    @StateObject private var detector = ObjectDetectionManager()
    @State private var feedbackMessage: String = ""
    @State private var feedbackColor: Color = .clear
    @State private var showFeedback = false
    @State private var showSaveScreen = false
    @State private var hintedItemID: UUID? = nil
    @State private var showQuitAlert = false

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            if detector.isAnalyzing {
                loadingView
            } else {
                gameContentView
            }
        }
        .onAppear { detector.performDetection(in: targetImage, targetCount: targetCount) }
        .fullScreenCover(isPresented: $showSaveScreen) {
            SaveView(image: targetImage, isGameActive: $isGameActive, targetItems: detector.targetItems, playingCollectionItem: playingCollectionItem)
        }
        .alert("Quit the game?", isPresented: $showQuitAlert) {
            Button("Yes", role: .destructive) { isGameActive = false }
            Button("No", role: .cancel) {}
        } message: {
            Text("Return to the home screen.")
        }
    }

    private var loadingView: some View {
        ZStack {
            Image(uiImage: targetImage).resizable().scaledToFill().blur(radius: 40).edgesIgnoringSafeArea(.all)
            Color.black.opacity(0.3).edgesIgnoringSafeArea(.all)
            VStack(spacing: 40) {
                Text("Looking for little magic\nhidden in the scenery... 🪄")
                    .font(.system(size: 20, weight: .regular, design: .serif)).foregroundColor(.white)
                    .multilineTextAlignment(.center).lineSpacing(10).shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 2)
                ZStack {
                    Circle().stroke(Color.white.opacity(0.2), lineWidth: 3).frame(width: 90, height: 90)
                    Circle().trim(from: 0.0, to: CGFloat(detector.progress))
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 90, height: 90).rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: detector.progress)
                        .shadow(color: .white.opacity(0.5), radius: 10, x: 0, y: 0)
                }
            }
        }
    }

    private var gameContentView: some View {
        let panelHeight: CGFloat = 240
        let imageAreaSize = CGSize(width: screenSize.width - 40, height: screenSize.height - panelHeight - 40)

        return VStack(spacing: 0) {
            ZStack {
                Color.black

                ZStack {
                    Image(uiImage: targetImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageAreaSize.width, height: imageAreaSize.height)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            handleTap(at: location, viewSize: imageAreaSize, imageSize: targetImage.size)
                        }
                        .overlay(
                            ZStack {
                                if let hintedID = hintedItemID,
                                   let target = detector.targetItems.first(where: { $0.id == hintedID }),
                                   !target.isFound {

                                    let rect = convertRect(target.boundingBox, viewSize: imageAreaSize, imageSize: targetImage.size)
                                    let hash = abs(target.id.hashValue)
                                    let offsetX = CGFloat(hash % 121) - 60.0
                                    let offsetY = CGFloat((hash / 100) % 121) - 60.0

                                    Rectangle()
                                        .stroke(Color.gray.opacity(0.7), lineWidth: 5)
                                        .frame(width: rect.width + 150, height: rect.height + 150)
                                        .position(x: rect.midX + offsetX, y: rect.midY + offsetY)
                                        .shadow(color: .yellow, radius: 10, x: 0, y: 0)
                                        .transition(.opacity)
                                }
                            }
                        )
                }
                .frame(width: imageAreaSize.width, height: imageAreaSize.height)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            scale = min(max(scale * delta, 1.0), 5.0)
                            offset = boundedOffset(offset, currentScale: scale, imageAreaSize: imageAreaSize)
                        }
                        .onEnded { _ in lastScale = 1.0 }
                        .simultaneously(with: DragGesture()
                            .onChanged { value in
                                let newOffset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
                                offset = boundedOffset(newOffset, currentScale: scale, imageAreaSize: imageAreaSize)
                            }
                            .onEnded { _ in lastOffset = offset }
                        )
                )

                // ★改善: 背景の白い座布団を削除し、文字だけでも美しく見えるように影を調整
                if showFeedback {
                    Text(feedbackMessage)
                        .font(.system(size: 55, weight: .heavy, design: .rounded))
                        .foregroundColor(feedbackColor)
                        // 文字が写真に紛れないように、白く細いフチ取りのような影と、黒い影を重ねる
                        .shadow(color: .white, radius: 1, x: 0, y: 0)
                        .shadow(color: .white, radius: 1, x: 0, y: 0)
                        .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 3)
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(100)
                }

                VStack {
                    HStack {
                        Spacer()
                        Button(action: { showQuitAlert = true }) {
                            Image(systemName: "pause.circle.fill")
                                .font(.system(size: 35))
                                .foregroundColor(.white)
                                .padding()
                                .shadow(radius: 3)
                        }
                    }
                    Spacer()
                }
            }
            .frame(width: screenSize.width, height: screenSize.height - panelHeight)
            .clipped()

            VStack(spacing: 15) {
                HStack {
                    Image(systemName: "sparkles.magnifyingglass").font(.title).foregroundColor(.primary)

                    if detector.targetItems.isEmpty {
                        Text("Could not find any").font(.system(size: 18, weight: .regular, design: .serif)).foregroundColor(.secondary)
                    } else {
                        VStack(spacing: 10) {
                            if detector.targetItems.allSatisfy({ $0.isFound }) {
                                Text("All Found").font(.system(size: 22, weight: .bold, design: .serif)).foregroundColor(.primary)
                            } else {
                                Text("Find").font(.system(size: 22, weight: .bold, design: .serif)).foregroundColor(.primary)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    let iconSize: CGFloat = 100
                                    ForEach(detector.targetItems) { item in
                                        Image(uiImage: item.croppedImage)
                                            .resizable().scaledToFit()
                                            .frame(width: iconSize, height: iconSize)
                                            .clipShape(RoundedRectangle(cornerRadius: 15))
                                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.5), lineWidth: 1.5))
                                            .overlay(
                                                Group {
                                                    if item.isFound {
                                                        ZStack {
                                                            Color.black.opacity(0.6)
                                                                .cornerRadius(15)
                                                            Image(systemName: "checkmark")
                                                                .font(.system(size: 40, weight: .bold))
                                                                .foregroundColor(.green)
                                                        }
                                                    }
                                                }
                                            )
                                            .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 3)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                if !item.isFound {
                                                    withAnimation(.easeInOut(duration: 0.3)) { hintedItemID = item.id }
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                                        withAnimation(.easeInOut(duration: 0.5)) {
                                                            if hintedItemID == item.id { hintedItemID = nil }
                                                        }
                                                    }
                                                }
                                            }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    Spacer()
                }.padding(.top, 15)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
            .frame(height: panelHeight)
            .background(.ultraThinMaterial)
            .cornerRadius(30, corners: [.topLeft, .topRight])
            .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: -5)
        }
        .edgesIgnoringSafeArea(.bottom)
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }

    private func boundedOffset(_ currentOffset: CGSize, currentScale: CGFloat, imageAreaSize: CGSize) -> CGSize {
        let imageAspect = targetImage.size.width / targetImage.size.height
        let viewAspect = imageAreaSize.width / imageAreaSize.height

        var renderWidth = imageAreaSize.width
        var renderHeight = imageAreaSize.height

        if imageAspect > viewAspect {
            renderHeight = renderWidth / imageAspect
        } else {
            renderWidth = renderHeight * imageAspect
        }

        let scaledWidth = renderWidth * currentScale
        let scaledHeight = renderHeight * currentScale

        let maxOffsetX = max(0, (scaledWidth - imageAreaSize.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - imageAreaSize.height) / 2)

        let boundedX = min(max(currentOffset.width, -maxOffsetX), maxOffsetX)
        let boundedY = min(max(currentOffset.height, -maxOffsetY), maxOffsetY)

        return CGSize(width: boundedX, height: boundedY)
    }

    private func handleTap(at location: CGPoint, viewSize: CGSize, imageSize: CGSize) {
        if detector.targetItems.isEmpty || detector.targetItems.allSatisfy({ $0.isFound }) { return }
        var hitLabel: String? = nil

        for object in detector.detectedObjects.reversed() {
            let rect = convertRect(object.boundingBox, viewSize: viewSize, imageSize: imageSize)
            if rect.contains(location) {
                if let targetIndex = detector.targetItems.firstIndex(where: { $0.label == object.label && !$0.isFound }) {
                    let target = detector.targetItems[targetIndex]
                    let localX = ((location.x - rect.minX) / rect.width) * target.croppedImage.size.width
                    let localY = ((location.y - rect.minY) / rect.height) * target.croppedImage.size.height
                    if target.croppedImage.isPixelOpaque(at: CGPoint(x: localX, y: localY)) {
                        hitLabel = target.label; break
                    }
                } else {
                    hitLabel = object.label; break
                }
            }
        }

        guard let finalHitLabel = hitLabel else { showFeedbackEffect(msg: "Almost!", color: .gray); return }

                if let index = detector.targetItems.firstIndex(where: { $0.label == finalHitLabel && !$0.isFound }) {
                    detector.targetItems[index].isFound = true

                    if detector.targetItems.allSatisfy({ $0.isFound }) {
                        showFeedbackEffect(msg: "Hidden beauty found!", color: .yellow)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showSaveScreen = true }
                    } else {
                        showFeedbackEffect(msg: "Found it!", color: .orange)
                    }
                } else {
                    showFeedbackEffect(msg: "Maybe not", color: .cyan)
                }
    }

    private func convertRect(_ box: CGRect, viewSize: CGSize, imageSize: CGSize) -> CGRect {
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let renderedWidth = imageSize.width * scale
        let renderedHeight = imageSize.height * scale
        let offsetX = (viewSize.width - renderedWidth) / 2
        let offsetY = (viewSize.height - renderedHeight) / 2
        let rectWidth = box.width * renderedWidth
        let rectHeight = box.height * renderedHeight
        let rectX = box.minX * renderedWidth + offsetX
        let rectY = (1 - box.maxY) * renderedHeight + offsetY
        return CGRect(x: rectX, y: rectY, width: rectWidth, height: rectHeight)
    }

    private func showFeedbackEffect(msg: String, color: Color) {
        feedbackMessage = msg; feedbackColor = color
        withAnimation(.spring()) { showFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { withAnimation { showFeedback = false } }
    }
}

// MARK: - 保存画面 (SaveView)
struct SaveView: View {
    let image: UIImage
    @Binding var isGameActive: Bool
    let targetItems: [TargetItem]
    let playingCollectionItem: CollectionItem?

    @EnvironmentObject var store: CollectionStore
    @State private var titleText = ""

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 35) {
                        Spacer(minLength: 20)

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: geometry.size.height * 0.45)
                            .cornerRadius(15)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 15) {
                            Text("Items found this time")
                                .font(.headline)
                                .padding(.horizontal, 25)

                            let foundItems = targetItems.filter { $0.isFound }
                            if foundItems.isEmpty {
                                Text("None")
                                    .padding(.horizontal, 25)
                                    .foregroundColor(.secondary)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 20) {
                                        ForEach(foundItems) { item in
                                            Image(uiImage: item.croppedImage)
                                                .resizable().scaledToFit()
                                                .frame(width: 100, height: 100)
                                                .cornerRadius(12)
                                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                        }
                                    }
                                    .padding(.horizontal, 25)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Title")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 30)

                            HStack {
                                Image(systemName: "pencil.line")
                                    .foregroundColor(.gray)
                                TextField("Give it a wonderful name...", text: $titleText)
                                    .font(.system(size: 18, weight: .regular, design: .serif))
                            }
                            .padding(.vertical, 15)
                            .padding(.horizontal, 20)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal, 25)
                        }

                        Button(action: saveAndReturn) {
                            Text("Save and return Home")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity)
                                .background(Color.black)
                                .cornerRadius(15)
                                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                                .padding(.horizontal, 25)
                        }

                        Spacer(minLength: 40)
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
            .navigationTitle("Cleared!")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let existing = playingCollectionItem {
                    titleText = existing.title
                }
            }
        }
    }

    private func saveAndReturn() {
        let finalTitle = titleText.isEmpty ? "Untitled Collection" : titleText
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        let targetDataList = targetItems.filter { $0.isFound }.compactMap { item -> TargetItemData? in
            guard let croppedData = item.croppedImage.pngData() else { return nil }
            return TargetItemData(id: item.id, label: item.label, croppedImageData: croppedData, isFound: item.isFound)
        }

        if let existing = playingCollectionItem, let index = store.items.firstIndex(where: { $0.id == existing.id }) {
            var existingTargets = store.items[index].targets
            let existingLabels = Set(existingTargets.map { $0.label })
            for newTarget in targetDataList {
                if !existingLabels.contains(newTarget.label) {
                    existingTargets.append(newTarget)
                }
            }
            store.items[index] = CollectionItem(id: existing.id, title: finalTitle, imageData: existing.imageData, targets: existingTargets)
        } else {
            store.items.append(CollectionItem(id: UUID(), title: finalTitle, imageData: imageData, targets: targetDataList))
        }
        isGameActive = false
    }
}

// MARK: - カメラ機能
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator; picker.sourceType = .camera; return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage { parent.selectedImage = image }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - UI拡張機能
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    func glassEffect() -> some View {
        self
            .padding(15)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity; var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - ピクセル判定の拡張機能
extension UIImage {
    func isPixelOpaque(at point: CGPoint) -> Bool {
        if point.x < 0 || point.x >= self.size.width || point.y < 0 || point.y >= self.size.height { return false }
        var pixelData: [UInt8] = [0, 0, 0, 0]; let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: &pixelData, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        UIGraphicsPushContext(context); context.translateBy(x: -point.x, y: -point.y); self.draw(at: .zero); UIGraphicsPopContext()
        return pixelData[3] > 10
    }
}
