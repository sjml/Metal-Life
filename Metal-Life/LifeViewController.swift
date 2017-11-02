import Cocoa
import Metal
import simd


class LifeViewController: NSViewController {
    var eqTimer: Timer!
    var mouseTimer: Timer!
    var hidingMouse: Bool = false
    let defaults: UserDefaults = UserDefaults.standard
    
    @IBOutlet weak var lifeView: LifeView!
    @IBOutlet weak var controlGroup: NSBox!
    @IBOutlet weak var defaultsButton: NSButton!
    @IBOutlet weak var pointSizeSlider: NSSlider! {
        didSet {
            pointSizeSlider.minValue = 1.0
            pointSizeSlider.maxValue = 13.0
            pointSizeSlider.doubleValue = 9.0
        }
    }
    @IBAction func pointSizeChanged(sender: NSSlider) {
        lifeView.uniforms.pointSize = Float(self.pointSizeSlider.doubleValue)
        self.defaults.set(self.pointSizeSlider.doubleValue, forKey: "pointSize")
    }
    @IBOutlet weak var fpsMenu: NSPopUpButton!
    @IBAction func fpsChangeRequested(sender: NSPopUpButton) {
        let req = fpsMenu.selectedItem?.title
        let reqInt = Int(req!)!
        lifeView.numSkipFrames = (60 / reqInt) - 1
        
        self.defaults.set(reqInt, forKey: "frameRate")
    }
    
    @IBOutlet weak var bgColorWell: NSColorWell!
    @IBOutlet weak var fgColorWell: NSColorWell!
    
    @IBAction func fgColorChanged(sender: NSColorWell) {
        let c = fgColorWell.color
        lifeView.uniforms.fgColor = float4(Float(c.redComponent), Float(c.greenComponent), Float(c.blueComponent), Float(c.alphaComponent))
        
        self.defaults.set(c.redComponent,   forKey: "fgRed")
        self.defaults.set(c.greenComponent, forKey: "fgGreen")
        self.defaults.set(c.blueComponent,  forKey: "fgBlue")
        
    }
    @IBAction func bgColorChanged(sender: NSColorWell) {
        let c = bgColorWell.color
        lifeView.uniforms.bgColor = float4(Float(c.redComponent), Float(c.greenComponent), Float(c.blueComponent), Float(c.alphaComponent))
        
        self.defaults.set(c.redComponent,   forKey: "bgRed")
        self.defaults.set(c.greenComponent, forKey: "bgGreen")
        self.defaults.set(c.blueComponent,  forKey: "bgBlue")
    }
    @IBAction func defaultsButtonAction(sender: NSButton) {
        self.defaults.set(60,   forKey: "frameRate")
        self.defaults.set(9.0,  forKey: "pointSize")
        self.defaults.set(0.25, forKey: "bgRed")
        self.defaults.set(0.0,  forKey: "bgGreen")
        self.defaults.set(0.0,  forKey: "bgBlue")
        self.defaults.set(1.0,  forKey: "fgRed")
        self.defaults.set(0.0,  forKey: "fgGreen")
        self.defaults.set(0.0,  forKey: "fgBlue")
        
        self.syncRendering()
        self.syncUI()
    }
    
    func setHidingMouse(on: Bool) {
        if (on) {
            NSCursor.setHiddenUntilMouseMoves(true)
            self.hidingMouse = true
        }
        else {
            NSCursor.setHiddenUntilMouseMoves(false)
            self.hidingMouse = false
            self.mouseTimer?.invalidate()
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        if (self.hidingMouse) {
            self.mouseTimer?.invalidate()
            self.mouseTimer = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(LifeViewController.mouseStopped), userInfo: nil, repeats: false)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        if !self.pointSizeSlider.isEnabled {
            return
        }
        
        if (!self.bgColorWell.isActive && !self.fgColorWell.isActive) {
            self.controlGroup.alphaValue = 0.0
            self.bgColorWell.isEnabled = false
            self.fgColorWell.isEnabled = false
            self.pointSizeSlider.isEnabled = false
            self.fpsMenu.isEnabled = false
            self.defaultsButton.isEnabled = false
            self.defaults.synchronize()
        }
    }
    
    @objc func mouseStopped() {
        NSCursor.setHiddenUntilMouseMoves(true)
        self.hidingMouse = true
    }
    
    override func flagsChanged(with event: NSEvent) {
        if (event.modifierFlags.intersection(NSEvent.ModifierFlags.deviceIndependentFlagsMask) == NSEvent.ModifierFlags.control) {
            self.controlGroup.alphaValue = 1.0
            self.bgColorWell.isEnabled = true
            self.fgColorWell.isEnabled = true
            self.pointSizeSlider.isEnabled = true
            self.fpsMenu.isEnabled = true
            self.defaultsButton.isEnabled = true
            self.syncUI()
        }
        else {
            if (!self.bgColorWell.isActive && !self.fgColorWell.isActive) {
                self.controlGroup.alphaValue = 0.0
                self.bgColorWell.isEnabled = false
                self.fgColorWell.isEnabled = false
                self.pointSizeSlider.isEnabled = false
                self.fpsMenu.isEnabled = false
                self.defaultsButton.isEnabled = false
                self.defaults.synchronize()
            }
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        lifeView.setup()
        
        let prefsFilePath = Bundle.main.path(forResource: "InitialPreferences", ofType: "plist")
        let nsDefaultPrefs = NSDictionary(contentsOfFile: prefsFilePath!)
        if let defaultPrefs: Dictionary<String,Any> = nsDefaultPrefs as? Dictionary<String, Any> {
            self.defaults.register(defaults: defaultPrefs)
        }
        
        self.syncRendering()
        
        self.syncUI()
        self.controlGroup.alphaValue = 0.0
        self.bgColorWell.isEnabled = false
        self.fgColorWell.isEnabled = false
        self.pointSizeSlider.isEnabled = false
        self.fpsMenu.isEnabled = false
        
        eqTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) {
            _ in 
            self.lifeView.checkForEquilibrium()
        }
        
        self.view.window?.delegate = self
        self.view.window?.acceptsMouseMovedEvents = true
        
        lifeView.start()
    }
    
    func syncRendering() {
        self.lifeView.uniforms.pointSize = self.defaults.float(forKey: "pointSize")
        self.lifeView.uniforms.bgColor = float4(
            self.defaults.float(forKey: "bgRed"),
            self.defaults.float(forKey: "bgGreen"),
            self.defaults.float(forKey: "bgBlue"),
            1.0
        )
        self.lifeView.uniforms.fgColor = float4(
            self.defaults.float(forKey: "fgRed"),
            self.defaults.float(forKey: "fgGreen"),
            self.defaults.float(forKey: "fgBlue"),
            1.0
        )
        let fr = self.defaults.integer(forKey: "frameRate")
        self.lifeView.numSkipFrames = (60 / fr) - 1
    }
    
    func syncUI() {
        self.pointSizeSlider.doubleValue = self.defaults.double(forKey: "pointSize")
        self.bgColorWell.color = NSColor(
            red: CGFloat(self.defaults.double(forKey: "bgRed")),
            green: CGFloat(self.defaults.double(forKey: "bgGreen")),
            blue: CGFloat(self.defaults.double(forKey: "bgBlue")),
            alpha: 1.0
        )
        self.fgColorWell.color = NSColor(
            red: CGFloat(self.defaults.double(forKey: "fgRed")),
            green: CGFloat(self.defaults.double(forKey: "fgGreen")),
            blue: CGFloat(self.defaults.double(forKey: "fgBlue")),
            alpha: 1.0
        )
        
        let frameRate = self.defaults.integer(forKey: "frameRate")
        let menuItem = self.fpsMenu.item(withTitle: String(frameRate))
        self.fpsMenu.select(menuItem)
    }
}

extension LifeViewController: NSWindowDelegate {
    func windowDidEnterFullScreen(_ notification: Notification) {
        self.setHidingMouse(on: true)
    }
    
    func windowDidExitFullScreen(_ notification: Notification) {
        self.setHidingMouse(on: false)
    }
}
