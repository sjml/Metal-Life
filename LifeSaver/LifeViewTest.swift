import ScreenSaver
import MetalKit


class LifeSaverView: ScreenSaverView {
    var lifeView: LifeView?
    var eqTimer: Timer?
    
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
                
        if let device = MTLCreateSystemDefaultDevice() {
            self.lifeView = LifeView(frame: frame, device: device)
        }
        if (self.lifeView == nil) {
            return nil
        }

        self.lifeView!.delegate = self
        self.lifeView!.preferredFramesPerSecond = 60
        self.lifeView!.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        
        self.addSubview(lifeView!)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if let device = MTLCreateSystemDefaultDevice() {
            lifeView!.setup(device: device)
            
            lifeView!.uniforms.bgColor = float4(0.25, 0.0, 0.0, 1.0)
            lifeView!.uniforms.fgColor = float4(1.0, 0.0, 0.0, 1.0)
            
            eqTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self.lifeView!, selector: #selector(LifeView.checkForEquilibrium), userInfo: nil, repeats: true)
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension LifeSaverView: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        if let cDraw = view.currentDrawable {
            if (self.lifeView != nil) {
                self.lifeView!.render(drawable: cDraw)
            }
        }
    }
}
