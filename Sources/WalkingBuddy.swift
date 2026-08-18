import AppKit
import QuartzCore

private final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class DraggablePetView: NSView {
    var onDragStart: ((NSPoint) -> Void)?
    var onDragEnd: ((NSPoint) -> Void)?
    var allowedFrame: (() -> CGRect)?
    private var startingMouseLocation = NSPoint.zero
    private var startingWindowOrigin = NSPoint.zero
    private var didDrag = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { bounds.contains(point) ? self : nil }

    override func mouseDown(with event: NSEvent) {
        NSCursor.closedHand.push()
        startingMouseLocation = NSEvent.mouseLocation
        startingWindowOrigin = window?.frame.origin ?? .zero
        didDrag = false
        onDragStart?(startingMouseLocation)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        var newOrigin = NSPoint(x: startingWindowOrigin.x + mouse.x - startingMouseLocation.x,
                                y: startingWindowOrigin.y + mouse.y - startingMouseLocation.y)
        if let allowed = allowedFrame?() {
            newOrigin.x = min(max(newOrigin.x, allowed.minX), max(allowed.minX, allowed.maxX - window.frame.width))
            newOrigin.y = min(max(newOrigin.y, allowed.minY), max(allowed.minY, allowed.maxY - window.frame.height))
        }
        window.setFrameOrigin(newOrigin)
        didDrag = true
    }

    override func mouseUp(with event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        NSCursor.pop()
        onDragEnd?(didDrag ? mouse : startingMouseLocation)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}

private final class PassthroughImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private enum PetChoice: String, CaseIterable {
    case automatic
    case halloweenGhost
    case santaSleigh
    case springBunny
    case wizardCat
    case tinyDragon
    case ufoAlien
    case snowman
    case beachCrab

    var title: String {
        switch self {
        case .automatic: return "Auto Seasonal"
        case .halloweenGhost: return "Halloween Ghost"
        case .santaSleigh: return "Santa & Sleigh"
        case .springBunny: return "Spring Bunny"
        case .wizardCat: return "Wizard Cat"
        case .tinyDragon: return "Tiny Dragon"
        case .ufoAlien: return "UFO Alien"
        case .snowman: return "Snowman"
        case .beachCrab: return "Beach Crab"
        }
    }

    var icon: String {
        switch self {
        case .automatic: return "✨"
        case .halloweenGhost: return "👻"
        case .santaSleigh: return "🎅"
        case .springBunny: return "🐰"
        case .wizardCat: return "🐈‍⬛"
        case .tinyDragon: return "🐉"
        case .ufoAlien: return "🛸"
        case .snowman: return "☃️"
        case .beachCrab: return "🦀"
        }
    }
}

private enum PetScale: String, CaseIterable {
    case tiny
    case small
    case normal
    case large
    case huge

    var title: String { rawValue.capitalized }

    var factor: CGFloat {
        switch self {
        case .tiny: return 0.55
        case .small: return 0.75
        case .normal: return 1.0
        case .large: return 1.35
        case .huge: return 1.75
        }
    }
}

final class WalkingBuddyApp: NSObject, NSApplicationDelegate {
    private var petSize = NSSize(width: 150, height: 163)

    private var panel: PetPanel!
    private var dragView: DraggablePetView!
    private var imageView: PassthroughImageView!
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var seasonalImages: [PetChoice: NSImage] = [:]
    private var seasonalImagesLeft: [PetChoice: NSImage] = [:]
    private var petMenuItems: [PetChoice: NSMenuItem] = [:]
    private var sizeMenuItems: [PetScale: NSMenuItem] = [:]
    private var selectedPet = PetChoice(rawValue: UserDefaults.standard.string(forKey: "selectedPet") ?? "") ?? .automatic
    private var selectedScale = PetScale(rawValue: UserDefaults.standard.string(forKey: "petScale") ?? "") ?? .normal
    private var activePet: PetChoice = .tinyDragon
    private var lastTick = CACurrentMediaTime()
    private var direction: CGFloat = 1
    private var speed: CGFloat = 90
    private var isPaused = UserDefaults.standard.bool(forKey: "isPaused")
    private var isDragging = false
    private var dragStartMouse = NSPoint.zero
    private var motionBaseVisibleBottomY: CGFloat = 0
    private var travelBounds = CGRect.zero
    private var horizontalPosition: CGFloat?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Walking Buddy: launching")
        NSApp.setActivationPolicy(.accessory)

        guard loadAssets() else {
            let alert = NSAlert()
            alert.messageText = "Walking Buddy couldn't load its character artwork."
            alert.informativeText = "Keep Walking Buddy.app together with its Resources folder."
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        makePanel()
        makeMenuBarItem()
        applyPetSelection()
        updateTravelBounds(resetPosition: true)
        print("Walking Buddy: ready")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        timer = Timer.scheduledTimer(timeInterval: 1.0 / 60.0,
                                     target: self,
                                     selector: #selector(tick),
                                     userInfo: nil,
                                     repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func loadAssets() -> Bool {
        let assets: [(PetChoice, String)] = [
            (.halloweenGhost, "halloween-ghost"),
            (.santaSleigh, "santa-sleigh"),
            (.springBunny, "spring-bunny"),
            (.wizardCat, "wizard-cat"),
            (.tinyDragon, "tiny-dragon"),
            (.ufoAlien, "ufo-alien"),
            (.snowman, "snowman"),
            (.beachCrab, "beach-crab")
        ]
        for (pet, filename) in assets {
            guard let url = Bundle.main.url(forResource: filename, withExtension: "png"),
                  let image = NSImage(contentsOf: url) else { return false }
            seasonalImages[pet] = image
            seasonalImagesLeft[pet] = mirroredImage(image)
        }

        return true
    }

    private func mirroredImage(_ image: NSImage) -> NSImage {
        var proposedRect = NSRect(origin: .zero, size: image.size)
        guard let source = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil),
              let context = CGContext(data: nil,
                                      width: source.width,
                                      height: source.height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return image
        }
        context.translateBy(x: CGFloat(source.width), y: 0)
        context.scaleBy(x: -1, y: 1)
        context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
        guard let mirrored = context.makeImage() else { return image }
        return NSImage(cgImage: mirrored, size: image.size)
    }

    private func makePanel() {
        panel = PetPanel(contentRect: NSRect(origin: .zero, size: petSize),
                         styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered,
                         defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isMovable = true
        panel.isMovableByWindowBackground = true
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        dragView = DraggablePetView(frame: panel.contentView!.bounds)
        dragView.autoresizingMask = [.width, .height]
        dragView.onDragStart = { [weak self] point in self?.beginDrag(at: point) }
        dragView.onDragEnd = { [weak self] point in self?.endDrag(at: point) }
        dragView.allowedFrame = { [weak self] in self?.travelBounds ?? .zero }
        panel.contentView = dragView

        imageView = PassthroughImageView(frame: dragView.bounds)
        imageView.autoresizingMask = [.width, .height]
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.image = seasonalImages[.tinyDragon]
        dragView.addSubview(imageView)
        panel.orderFrontRegardless()
    }

    private func makeMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🤖"
        statusItem.button?.toolTip = "Walking Buddy"

        let menu = NSMenu()
        let petPicker = NSMenu()
        for pet in PetChoice.allCases {
            let item = NSMenuItem(title: "\(pet.icon)  \(pet.title)", action: #selector(choosePet(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pet.rawValue
            petPicker.addItem(item)
            petMenuItems[pet] = item
        }
        let petPickerItem = NSMenuItem(title: "Choose Character", action: nil, keyEquivalent: "")
        petPickerItem.submenu = petPicker
        menu.addItem(petPickerItem)

        let sizePicker = NSMenu()
        for size in PetScale.allCases {
            let item = NSMenuItem(title: size.title, action: #selector(chooseSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = size.rawValue
            sizePicker.addItem(item)
            sizeMenuItems[size] = item
        }
        let sizePickerItem = NSMenuItem(title: "Character Size", action: nil, keyEquivalent: "")
        sizePickerItem.submenu = sizePicker
        menu.addItem(sizePickerItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Pause Walking", action: #selector(togglePause(_:)), keyEquivalent: "p")
        menu.addItem(withTitle: "Reset to Bottom", action: #selector(resetToBottom), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Slow", action: #selector(useSlowSpeed), keyEquivalent: "")
        menu.addItem(withTitle: "Normal", action: #selector(useNormalSpeed), keyEquivalent: "")
        menu.addItem(withTitle: "Fast", action: #selector(useFastSpeed), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Walking Buddy", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        if let pauseItem = menu.items.first(where: { $0.action == #selector(togglePause(_:)) }) {
            pauseItem.title = isPaused ? "Resume Walking" : "Pause Walking"
        }
        statusItem.menu = menu
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let delta = min(now - lastTick, 0.05)
        lastTick = now
        guard !isPaused, !isDragging, travelBounds.width > petSize.width else { return }

        let leftEdge = travelBounds.minX
        let rightEdge = travelBounds.maxX - petSize.width
        var x = horizontalPosition ?? panel.frame.minX
        x += speed * direction * delta
        if x >= rightEdge {
            x = rightEdge
            direction = -1
            updatePetImage()
        } else if x <= leftEdge {
            x = leftEdge
            direction = 1
            updatePetImage()
        }
        horizontalPosition = x
        var origin = panel.frame.origin
        origin.x = x
        origin.y = motionBaseVisibleBottomY + bobOffset(at: now) - visibleBottomInset()
        panel.setFrameOrigin(origin)

    }

    private func bobOffset(at time: TimeInterval) -> CGFloat {
        switch activePet {
        case .halloweenGhost:
            return (sin(time * 2.6) + 1) * 8
        case .santaSleigh:
            return (sin(time * 3.2) + 1) * 3
        case .springBunny:
            return abs(sin(time * 5.5)) * 11
        case .wizardCat, .tinyDragon, .ufoAlien:
            return (sin(time * 2.8) + 1) * 7
        case .snowman:
            return abs(sin(time * 3.5)) * 3
        case .beachCrab:
            return abs(sin(time * 8.0)) * 2
        default:
            return 0
        }
    }

    private func visibleBottomInset() -> CGFloat {
        0
    }

    private func updatePetImage() {
        imageView.image = direction > 0 ? seasonalImages[activePet] : seasonalImagesLeft[activePet]
        imageView.layer?.transform = CATransform3DIdentity
        imageView.layer?.magnificationFilter = .linear
    }

    private func resolvedPet() -> PetChoice {
        guard selectedPet == .automatic else { return selectedPet }
        switch Calendar.current.component(.month, from: Date()) {
        case 1: return .snowman
        case 2: return .ufoAlien
        case 10: return .halloweenGhost
        case 12: return .santaSleigh
        case 3, 4: return .springBunny
        case 5: return .tinyDragon
        case 6, 7, 8: return .beachCrab
        case 9, 11: return .wizardCat
        default: return .tinyDragon
        }
    }

    private func baseSize(for pet: PetChoice) -> NSSize {
        if pet != .automatic, let image = seasonalImages[pet], image.size.height > 0 {
            let height: CGFloat = 160
            return NSSize(width: height * image.size.width / image.size.height, height: height)
        }
        switch pet {
        default: return NSSize(width: 150, height: 163)
        }
    }

    private func scaledSize(for pet: PetChoice) -> NSSize {
        let base = baseSize(for: pet)
        return NSSize(width: base.width * selectedScale.factor,
                      height: base.height * selectedScale.factor)
    }

    private func applyPetSelection() {
        activePet = resolvedPet()
        petSize = scaledSize(for: activePet)
        panel.setContentSize(petSize)
        dragView.frame = NSRect(origin: .zero, size: petSize)
        imageView.frame = NSRect(origin: .zero, size: petSize)
        updatePetImage()
        petMenuItems.forEach { choice, item in
            item.state = choice == selectedPet ? .on : .off
        }
        sizeMenuItems.forEach { size, item in
            item.state = size == selectedScale ? .on : .off
        }
        statusItem.button?.title = activePet.icon
        statusItem.button?.toolTip = selectedPet == .automatic
            ? "Walking Buddy — Auto Seasonal: \(activePet.title)"
            : "Walking Buddy — \(activePet.title)"
        updateTravelBounds(resetPosition: false)
    }

    @objc private func screenConfigurationChanged() {
        updateTravelBounds(resetPosition: false)
    }

    private func updateTravelBounds(resetPosition: Bool) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        travelBounds = screen.frame
        if resetPosition {
            motionBaseVisibleBottomY = travelBounds.minY + 1
            horizontalPosition = travelBounds.minX
            panel.setFrameOrigin(NSPoint(x: travelBounds.minX,
                                         y: motionBaseVisibleBottomY + bobOffset(at: CACurrentMediaTime()) - visibleBottomInset()))
        } else {
            clampMotionBaseToScreen()
            var origin = panel.frame.origin
            origin.x = min(max(origin.x, travelBounds.minX), travelBounds.maxX - petSize.width)
            horizontalPosition = origin.x
            origin.y = motionBaseVisibleBottomY + bobOffset(at: CACurrentMediaTime()) - visibleBottomInset()
            panel.setFrameOrigin(origin)
        }
    }

    private func clampMotionBaseToScreen() {
        let minimum = travelBounds.minY + 1
        let maximum = max(minimum, travelBounds.maxY - petSize.height + visibleBottomInset())
        motionBaseVisibleBottomY = min(max(motionBaseVisibleBottomY, minimum), maximum)
    }

    private func beginDrag(at mouse: NSPoint) {
        isDragging = true
        dragStartMouse = mouse
        panel.hasShadow = true
    }

    private func endDrag(at mouse: NSPoint) {
        guard isDragging else { return }
        if mouse.x - dragStartMouse.x > 1 {
            direction = 1
        } else if mouse.x - dragStartMouse.x < -1 {
            direction = -1
        }
        updatePetImage()
        let now = CACurrentMediaTime()
        motionBaseVisibleBottomY = panel.frame.minY + visibleBottomInset() - bobOffset(at: now)
        let clampedX = min(max(panel.frame.minX, travelBounds.minX), travelBounds.maxX - petSize.width)
        horizontalPosition = clampedX
        clampMotionBaseToScreen()
        panel.setFrameOrigin(NSPoint(x: clampedX,
                                     y: motionBaseVisibleBottomY + bobOffset(at: now) - visibleBottomInset()))
        isDragging = false
        panel.hasShadow = false
        lastTick = now
    }

    @objc private func choosePet(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let pet = PetChoice(rawValue: rawValue) else { return }
        selectedPet = pet
        UserDefaults.standard.set(pet.rawValue, forKey: "selectedPet")
        applyPetSelection()
    }

    @objc private func chooseSize(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let size = PetScale(rawValue: rawValue) else { return }
        selectedScale = size
        UserDefaults.standard.set(size.rawValue, forKey: "petScale")
        applyPetSelection()
    }

    @objc private func resetToBottom() {
        motionBaseVisibleBottomY = travelBounds.minY + 1
        var origin = panel.frame.origin
        origin.y = motionBaseVisibleBottomY + bobOffset(at: CACurrentMediaTime()) - visibleBottomInset()
        panel.setFrameOrigin(origin)
    }

    @objc private func togglePause(_ sender: NSMenuItem) {
        isPaused.toggle()
        UserDefaults.standard.set(isPaused, forKey: "isPaused")
        sender.title = isPaused ? "Resume Walking" : "Pause Walking"
        if !isPaused { lastTick = CACurrentMediaTime() }
    }

    @objc private func useSlowSpeed() { speed = 50 }
    @objc private func useNormalSpeed() { speed = 90 }
    @objc private func useFastSpeed() { speed = 150 }
    @objc private func quit() { NSApp.terminate(nil) }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }
}

let application = NSApplication.shared
let applicationDelegate = WalkingBuddyApp()
application.delegate = applicationDelegate
application.run()
