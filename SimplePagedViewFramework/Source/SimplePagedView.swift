import UIKit

public class SimplePagedView: UIView {

    // MARK: - Properties
    public static func defaultPageControlConstraints(dotsView: UIView, pagedViewController: SimplePagedView) -> ([NSLayoutConstraint]) {
        return [
            dotsView.bottomAnchor.constraint(equalTo: pagedViewController.scrollView.bottomAnchor),
            dotsView.centerXAnchor.constraint(
                equalTo: pagedViewController.centerXAnchor
            ),
            dotsView.leadingAnchor.constraint(equalTo: pagedViewController.leadingAnchor),
            dotsView.trailingAnchor.constraint(equalTo: pagedViewController.trailingAnchor),
            dotsView.heightAnchor.constraint(equalToConstant: 44)
        ]
    }

    fileprivate enum Constants {
        static let startingPage = 0
        static let pageControllerSpacing: CGFloat = -10
    }

    fileprivate var scrollContentView: UIView = {
        var scrollingView = UIView()
        scrollingView.translatesAutoresizingMaskIntoConstraints = false
        return scrollingView
    }()
    fileprivate var innerPages: [UIView]!
    fileprivate var pageControlGestureView: UIView = {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.accessibilityIdentifier = "DotGestureView"

        return view
    }()

    fileprivate let pageControlConstraints: (UIView, SimplePagedView) -> ([NSLayoutConstraint])

    fileprivate let initialPage: Int
    fileprivate var didInit = false
    fileprivate let dotSize: CGFloat

    public var currentPage: Int {
        return pageControl.currentDot
    }

    /// Can be defined in order to trigger an action when pages are switched. Pages are 0 indexed.
    public var didSwitchPages: ((Int) -> Void)?
    /// Can be set to allow or disallow user interaction with the page dot indicators. Defaults to false.
    public var pageIndicatorIsInteractive: Bool = false
    /// The last dot can in the page indicator can be replaced with an image by setting this property
    public var lastPageIndicator: UIImageView?
    /// Executes whenever scrolling ends
    public var didFinishScrolling: (() -> Void)?

    public var isScrolling = false {
        didSet {
            if !isScrolling {
                self.didFinishScrolling?()
            }
        }
    }

    public var scrollView: UIScrollView = {
        var scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = false
        scrollView.alwaysBounceHorizontal = false
        return scrollView
    }()
    fileprivate var pageControl: PageDotsView = {
        var pageControl = PageDotsView(count: 0, frame: .zero)
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        return pageControl
    }()

    public init(
        indicatorColor: UIColor = .red,
        initialPage: Int = 0,
        dotSize: CGFloat = 7,
        imageIndices: [Int: UIImage] = [:],
        pageControlConstraints: @escaping (UIView, SimplePagedView) -> ([NSLayoutConstraint])
            = SimplePagedView.defaultPageControlConstraints,
        with views: UIView...
    ) {
        self.pageControlConstraints = pageControlConstraints
        self.initialPage = initialPage
        self.dotSize = dotSize
        super.init(frame: .zero)
        self.innerPages = setupInnerPages(for: views)

        self.pageControl = setupPageDotsView(
            numberOfDots: self.innerPages.count,
            color: .gray,
            currentColor: indicatorColor,
            dotSize: dotSize,
            currentDot: initialPage,
            imageIndices: imageIndices
        )

        self.scrollView.delegate = self

        self.setupSubviews()
        self.setupConstraints()

        self.didSwitchPages?(0)
    }

    public init(
        indicatorColor: UIColor = .red,
        initialPage: Int = 0,
        dotSize: CGFloat = 7,
        imageIndices: [Int: UIImage] = [:],
        pageControlConstraints: @escaping (UIView, SimplePagedView) -> ([NSLayoutConstraint])
            = SimplePagedView.defaultPageControlConstraints,
        with views: [UIView]
    ) {

        self.pageControlConstraints = pageControlConstraints
        self.initialPage = initialPage
        self.dotSize = dotSize
        super.init(frame: .zero)
        self.innerPages = setupInnerPages(for: views)

        self.pageControl = setupPageDotsView(
            numberOfDots: self.innerPages.count,
            color: .gray,
            currentColor: indicatorColor,
            dotSize: dotSize,
            currentDot: initialPage,
            imageIndices: imageIndices
        )

        self.scrollView.delegate = self

        self.setupSubviews()
        self.setupConstraints()

        self.didSwitchPages?(0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)

        self.setupGestures(pageControl: self.pageControlGestureView)
    }

    public override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)

        self.scrollTo(page: initialPage, animated: false)
    }


    /// Scrolls to the given page
    ///
    /// - Parameters:
    ///   - page: 0 indexed page number
    ///   - animated: should the scrolling be animated
    public func scrollTo(page: Int, animated: Bool) {
        self.scrollView.layoutIfNeeded()
        self.scrollView.setContentOffset(
            CGPoint(x: CGFloat(Int(scrollView.frame.size.width) * page), y: 0),
            animated: animated
        )

        let newPageControl = try! pageControl.moveTo(index: page)

        self.replace(subview: self.pageControl, with: newPageControl, constraints: self.pageControlConstraints)
        self.pageControl = newPageControl
    }

    @objc func panned(sender: UIPanGestureRecognizer) {
        let cgNumberOfPages: CGFloat = CGFloat(self.innerPages.count)
        var page: Int = Int(floor(Double((sender.location(in: self).x/pageControl.frame.width) * cgNumberOfPages)))

        page = (page >= self.innerPages.count)
            ? self.innerPages.count - 1
            : (page < 0)
            ? 0
            : page

        scrollTo(page: page, animated: false)
    }
}

// MARK: - View Setup
fileprivate extension SimplePagedView {

    func setupInnerPages(for views: [UIView]) -> [UIView] {
        if views.count == 0 {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = .white
            return [view]
        }

        return views.map { $0.translatesAutoresizingMaskIntoConstraints = false; return $0 }
    }

    func setupGestures(pageControl: UIView) {
        if pageIndicatorIsInteractive {
            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panned(sender:)))

            panGestureRecognizer.maximumNumberOfTouches = 1
            panGestureRecognizer.minimumNumberOfTouches = 1

            pageControl.addGestureRecognizer(panGestureRecognizer)
        }
    }

    func setupSubviews() {
        self.addSubview(scrollView)
        self.scrollView.addSubview(scrollContentView)

        for page in innerPages {
            scrollContentView.addSubview(page)
        }

        self.addSubview(pageControl)
        self.addSubview(pageControlGestureView)
    }

    // swiftlint:disable next function_body_length
    func setupConstraints() {
        let scrollViewConstraints = [
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ]

        let innerViewConstraints = [
            scrollContentView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            scrollContentView.heightAnchor.constraint(equalTo: heightAnchor),
            scrollContentView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: CGFloat(innerPages.count)),
            scrollContentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            scrollContentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            scrollContentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            scrollContentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
        ]

        let pageConstraints: [NSLayoutConstraint] = {
            var widthConstraints: [NSLayoutConstraint] = []
            var heightConstraints: [NSLayoutConstraint] = []
            var leadingEdgeConstraints: [NSLayoutConstraint] = []
            var topConstraints: [NSLayoutConstraint] = []
            var bottomConstraints: [NSLayoutConstraint] = []

            for page in innerPages {
                widthConstraints.append(page.widthAnchor.constraint(equalTo: widthAnchor))
                heightConstraints.append(page.heightAnchor.constraint(equalTo: heightAnchor))
            }

            leadingEdgeConstraints.append(innerPages[0].leadingAnchor.constraint(equalTo: scrollView.leadingAnchor))

            for index in 1..<innerPages.count {
                leadingEdgeConstraints.append(innerPages[index].leadingAnchor.constraint(
                    equalTo: innerPages[index-1].trailingAnchor)
                )
            }

            for page in innerPages {
                topConstraints.append(page.topAnchor.constraint(equalTo: scrollView.topAnchor))
                bottomConstraints.append(page.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor))
            }

            let allConstraints = Array([
                widthConstraints,
                heightConstraints,
                leadingEdgeConstraints,
                topConstraints,
                bottomConstraints
                ].joined())
            return allConstraints
        }()

        NSLayoutConstraint.activate(
            scrollViewConstraints,
            innerViewConstraints,
            self.pageControlConstraints(self.pageControl, self),
            self.pageControlConstraints(self.pageControlGestureView, self),
            pageConstraints
        )
    }

    func setupPageDotsView(
        numberOfDots: Int,
        color: UIColor,
        currentColor: UIColor,
        dotSize: CGFloat,
        currentDot: Int,
        imageIndices: [Int: UIImage]
    ) -> PageDotsView {
        let view = PageDotsView(
            count: numberOfDots,
            dotColor: color,
            currentDotColor: currentColor,
            dotSize: dotSize,
            currentDot: currentDot,
            imageIndices: imageIndices,
            frame: .zero
        )

        view.frame = CGRect(x: 0, y: 0, width: view.intrinsicContentSize.width, height: view.intrinsicContentSize.height)

        return view
    }
}

// MARK: - UIScrollViewDelegate Methods
extension SimplePagedView: UIScrollViewDelegate {
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isScrolling = true
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { scrollViewDidEndScrolling(scrollView) }
    }

    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollViewDidEndScrolling(scrollView)
    }

    public func scrollViewDidEndScrolling(_ scrollView: UIScrollView) {
        isScrolling = false
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollViewDidEndScrolling(scrollView)
        let page = Int(scrollView.contentOffset.x / scrollView.frame.size.width)
        let newPageControl = try! self.pageControl.moveTo(index: page)

        self.replace(subview: self.pageControl, with: newPageControl, constraints: self.pageControlConstraints)

        self.pageControl = newPageControl

        self.didSwitchPages?(page)
    }
}

extension UIView {
    public func replace<T: UIView>(
        subview: UIView,
        with other: UIView,
        constraints: (_ child: UIView, _ parent: T) -> [NSLayoutConstraint]
    ) {
        let newConstraints = constraints(other, self as! T)
        guard let subviewIndex = subview.superview?.subviews.firstIndex(of: subview) else { fatalError() }
        subview.removeFromSuperview()
        self.insertSubview(other, at: subviewIndex)

        NSLayoutConstraint.activate(newConstraints)
    }
}

extension SimplePagedView {
    /// Gestures won't be recognized on subviews that are outside the bounds of a view
    /// This subclass and override remedies that.
    /// We're using it because there are situations where we want the page
    /// indicator to be outside the page view
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !clipsToBounds && !isHidden && alpha > 0 else { return nil }
        for member in subviews.reversed() {
            let subPoint = member.convert(point, from: self)
            guard let result = member.hitTest(subPoint, with: event) else { continue }
            return result
        }
        return nil
    }
}
