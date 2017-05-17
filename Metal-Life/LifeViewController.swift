import Cocoa
import MetalKit


class LifeViewController: NSViewController {
    var eqTimer: Timer!
    
    @IBOutlet weak var lifeView: LifeView! {
        didSet {
            lifeView.delegate = self
            lifeView.preferredFramesPerSecond = 60
            lifeView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        }
    }
    @IBOutlet weak var controlGroup: NSBox!
    @IBOutlet weak var pointSizeSlider: NSSlider! {
        didSet {
            pointSizeSlider.minValue = 1.0
            pointSizeSlider.maxValue = 13.0
            pointSizeSlider.doubleValue = 9.0
        }
    }
    @IBAction func pointSizeChanged(sender: NSSlider) {
//        if (self.pointSizeSlider.doubleValue <= 10.0) {
//            self.pointSizeSlider.doubleValue = Double(lround(self.pointSizeSlider.doubleValue))
//        }
        lifeView.uniforms.pointSize = Float(self.pointSizeSlider.doubleValue)
    }
    
    @IBOutlet weak var bgColorWell: NSColorWell!
    @IBOutlet weak var fgColorWell: NSColorWell!
    
    @IBAction func fgColorChanged(sender: NSColorWell) {
        let c = fgColorWell.color
        lifeView.uniforms.fgColor = float4(Float(c.redComponent), Float(c.greenComponent), Float(c.blueComponent), Float(c.alphaComponent))
    }
    @IBAction func bgColorChanged(sender: NSColorWell) {
        let c = bgColorWell.color
        lifeView.uniforms.bgColor = float4(Float(c.redComponent), Float(c.greenComponent), Float(c.blueComponent), Float(c.alphaComponent))
    }

    func getColorsFromView() {
        let bg: float4 = lifeView.uniforms.bgColor
        let fg: float4 = lifeView.uniforms.fgColor
        
        self.bgColorWell.color = NSColor(red: CGFloat(bg.x), green: CGFloat(bg.y), blue: CGFloat(bg.z), alpha: CGFloat(bg.w))
        self.fgColorWell.color = NSColor(red: CGFloat(fg.x), green: CGFloat(fg.y), blue: CGFloat(fg.z), alpha: CGFloat(fg.w))
    }
    
    override func flagsChanged(with event: NSEvent) {
        if (event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .control) {
            self.controlGroup.alphaValue = 1.0
            self.bgColorWell.isEnabled = true
            self.fgColorWell.isEnabled = true
            self.pointSizeSlider.isEnabled = true
            self.getColorsFromView()
        }
        else {
            if (!self.bgColorWell.isActive && !self.fgColorWell.isActive) {
                self.controlGroup.alphaValue = 0.0
                self.bgColorWell.isEnabled = false
                self.fgColorWell.isEnabled = false
                self.pointSizeSlider.isEnabled = false
            }
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        if let device = MTLCreateSystemDefaultDevice() {
            lifeView.setup(device: device)
            
            lifeView.uniforms.bgColor = float4(0.25, 0.0, 0.0, 1.0)
            lifeView.uniforms.fgColor = float4(1.0, 0.0, 0.0, 1.0)
            
            getColorsFromView()
            self.controlGroup.alphaValue = 0.0
            self.bgColorWell.isEnabled = false
            self.fgColorWell.isEnabled = false
            self.pointSizeSlider.isEnabled = false
            
            eqTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(LifeViewController.eqCheck), userInfo: nil, repeats: true)
        }
    }
    
    func eqCheck() {
        lifeView.checkForEquilibrium()
    }
    
    func pointSizeChanged() {
        
    }
}

extension LifeViewController: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        if let cDraw = view.currentDrawable {
            self.lifeView.render(drawable: cDraw)
        }
    }
}
