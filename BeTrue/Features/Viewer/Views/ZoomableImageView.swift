import SwiftUI
import UIKit

/// Pinch and double-tap zoom, plus the tap and dismiss drag that must not fight them.
///
/// iOS 16 has no SwiftUI magnify gesture, so zoom lives in a `UIScrollView`. Its image stays invisible until
/// a zoom starts: at scale 1 the SwiftUI image underneath is shown instead, because that is the image that
/// flies back to its grid tile.
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage?
    let aspectRatio: CGFloat
    /// True as the viewer closes, so a zoomed image never covers the SwiftUI image flying back to the grid.
    let isHidden: Bool
    let onSingleTap: () -> Void
    let onZoomChange: (Bool) -> Void
    let onDismissDragChange: (CGSize) -> Void
    let onDismissDragEnd: (_ translation: CGSize, _ projectedTranslation: CGSize) -> Void

    func makeUIView(context: Context) -> ZoomingImageScrollView {
        ZoomingImageScrollView()
    }

    func updateUIView(_ scrollView: ZoomingImageScrollView, context: Context) {
        scrollView.image = image
        scrollView.aspectRatio = aspectRatio
        // Set here, not animated by SwiftUI, so it hides in the same frame the flight starts.
        scrollView.isHidden = isHidden
        scrollView.onSingleTap = onSingleTap
        scrollView.onZoomChange = onZoomChange
        scrollView.onDismissDragChange = onDismissDragChange
        scrollView.onDismissDragEnd = onDismissDragEnd
    }
}

final class ZoomingImageScrollView: UIScrollView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    private enum Constants {
        static let maximumZoomScale: CGFloat = 3
        static let doubleTapZoomScale: CGFloat = 2.5
        static let zoomTolerance: CGFloat = 0.01
        /// Matches `UIScrollView.DecelerationRate.normal`, so a flick is judged by where it would coast to.
        static let projectionSeconds: CGFloat = 0.5
    }

    var onSingleTap: () -> Void = {}
    var onZoomChange: (Bool) -> Void = { _ in }
    var onDismissDragChange: (CGSize) -> Void = { _ in }
    var onDismissDragEnd: (CGSize, CGSize) -> Void = { _, _ in }
    var aspectRatio: CGFloat = 1 {
        didSet { if aspectRatio != oldValue { resetZoom() } }
    }
    var image: UIImage? {
        get { imageView.image }
        set { if imageView.image !== newValue { imageView.image = newValue } }
    }
    private let imageView = UIImageView()
    private let dismissPan = UIPanGestureRecognizer()
    private var laidOutSize = CGSize.zero
    private var isZoomed = false

    init() {
        super.init(frame: .zero)
        delegate = self
        backgroundColor = .clear
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .fast
        minimumZoomScale = 1
        maximumZoomScale = Constants.maximumZoomScale
        isScrollEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.alpha = 0
        addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTap.require(toFail: doubleTap)
        addGestureRecognizer(singleTap)
        dismissPan.addTarget(self, action: #selector(handleDismissPan(_:)))
        dismissPan.maximumNumberOfTouches = 1
        dismissPan.delegate = self
        addGestureRecognizer(dismissPan)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != laidOutSize {
            laidOutSize = bounds.size
            resetZoom()
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        setZoomed(true)
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        setZoomed(scale > minimumZoomScale + Constants.zoomTolerance)
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === dismissPan else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        let velocity = dismissPan.velocity(in: self)
        return !isZoomed && velocity.y > abs(velocity.x)
    }

    private func resetZoom() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        zoomScale = minimumZoomScale
        let fitted = fittedSize(in: bounds.size)
        imageView.frame = CGRect(origin: .zero, size: fitted)
        contentSize = fitted
        centerImage()
        contentOffset = CGPoint(x: -contentInset.left, y: -contentInset.top)
        setZoomed(false)
    }

    private func fittedSize(in container: CGSize) -> CGSize {
        let ratio = max(aspectRatio, .leastNonzeroMagnitude)
        if container.width / container.height > ratio {
            return CGSize(width: container.height * ratio, height: container.height)
        }
        return CGSize(width: container.width, height: container.width / ratio)
    }

    private func centerImage() {
        let horizontal = max((bounds.width - contentSize.width) / 2, 0)
        let vertical = max((bounds.height - contentSize.height) / 2, 0)
        contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    private func setZoomed(_ zoomed: Bool) {
        guard zoomed != isZoomed else { return }
        isZoomed = zoomed
        imageView.alpha = zoomed ? 1 : 0
        isScrollEnabled = zoomed
        onZoomChange(zoomed)
    }

    @objc private func handleSingleTap() {
        onSingleTap()
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale + Constants.zoomTolerance {
            setZoomScale(minimumZoomScale, animated: true)
            return
        }
        let point = recognizer.location(in: imageView)
        let scale = min(Constants.doubleTapZoomScale, maximumZoomScale)
        let size = CGSize(width: bounds.width / scale, height: bounds.height / scale)
        setZoomed(true)
        zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                        width: size.width, height: size.height),
             animated: true)
    }

    @objc private func handleDismissPan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: self)
        let dragged = CGSize(width: translation.x, height: translation.y)
        switch recognizer.state {
        case .changed:
            onDismissDragChange(dragged)
        case .ended, .cancelled, .failed:
            let velocity = recognizer.velocity(in: self)
            let projected = CGSize(width: translation.x + velocity.x * Constants.projectionSeconds,
                                   height: translation.y + velocity.y * Constants.projectionSeconds)
            onDismissDragEnd(dragged, recognizer.state == .ended ? projected : .zero)
        default:
            break
        }
    }
}
