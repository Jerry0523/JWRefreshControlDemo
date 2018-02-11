//
// RefreshControl.swift
//
// Copyright (c) 2015 Jerry Wong
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit

public enum RefreshHeaderInteraction {
    
    case still
    
    case follow
    
    fileprivate func update<T>(content: T, context: UIView) where T: UIView & AnyRefreshContent {
        let viewHeight = T.preferredHeight
        switch self {
        case .still:
            content.frame = CGRect(x: 0, y: 0, width: context.frame.size.width, height: viewHeight)
            content.autoresizingMask = .flexibleWidth
            
        case .follow:
            content.frame = CGRect(x: 0, y: context.frame.size.height - viewHeight, width: context.frame.size.width, height: viewHeight)
            content.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        }
    }
}

open class RefreshHeaderControl<T>: UIView, AnyRefreshContext, RefreshControl where T: AnyRefreshContent & UIView {
    
    open var style: RefreshHeaderInteraction = .still {
        didSet {
            if style != oldValue {
                style.update(content: contentView, context: self)
            }
        }
    }
    
    public var state = PullRefreshState.idle {
        didSet {
            if state != oldValue {
                updateContentViewByStateChanged()
            }
        }
    }
    
    open var refreshingBlock: ((RefreshHeaderControl<T>) -> ())?
    
    open let contentView = T() //(frame: CGRect.zero)
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    open override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        guard let scrollView = newSuperview as? UIScrollView else {
            return
        }
        removeKVO()
        self.scrollView = scrollView
        scrollView.alwaysBounceVertical = true
        registKVO()
        let panGestureRecognizer = scrollView.panGestureRecognizer
        keyPathObservations.append(
            panGestureRecognizer.observe(\.state, changeHandler: { [weak self] (scrollView, change) in
                self?.scrollViewPanGestureStateDidChange()
            })
        )
    }
    
    private func setup() {
        autoresizingMask = .flexibleWidth
        clipsToBounds = true
        addSubview(contentView)
        style.update(content: contentView, context: self)
    }
    
    private func scrollViewPanGestureStateDidChange() {
        guard let scrollView = scrollView else {
            return
        }
        if scrollView.panGestureRecognizer.state == .ended {
            if state != .idle {
                return
            }
            var offsetY = -(scrollView.contentInset.top + scrollView.contentOffset.y)
            if #available(iOS 11.0, *) {
                offsetY -= (scrollView.adjustedContentInset.top - scrollView.contentInset.top)
            }
            if (offsetY >= contentView.frame.size.height) {
                state = .refreshing
            } else {
                state = .idle
            }
        }
    }
    
    weak var scrollView: UIScrollView?
    
    var keyPathObservations: [NSKeyValueObservation] = []
    
}

open class RefreshFooterControl<T>: UIView , AnyRefreshContext, RefreshControl where T: AnyRefreshContent, T: UIView {
    
    open var state = PullRefreshState.idle {
        didSet {
            if state != oldValue {
                updateContentViewByStateChanged()
            }
        }
    }
    
    open var refreshingBlock: ((RefreshFooterControl<T>) -> ())?
    
    open var preFetchedDistance: CGFloat = 0
    
    open let contentView = T()
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    open override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        guard let scrollView = newSuperview as? UIScrollView else {
            return
        }
        removeKVO()
        contentView.frame = CGRect(x: 0, y: 0, width:scrollView.frame.size.width, height: T.preferredHeight)
        self.scrollView = scrollView
        scrollView.alwaysBounceVertical = true
        registKVO()
    }
    
    private func setup() {
        autoresizingMask = .flexibleWidth
        clipsToBounds = true
        addSubview(contentView)
        isHidden = true
    }
    
    weak var scrollView: UIScrollView?
    
    var keyPathObservations: [NSKeyValueObservation] = []
    
}

extension RefreshHeaderControl : AnyRefreshObserver {
    
    func scrollViewContentOffsetDidChange() {
        guard let scrollView = scrollView else {
            return
        }
        
        var offsetY = -scrollView.contentOffset.y
        if #available(iOS 11.0, *) {
            offsetY -= (scrollView.adjustedContentInset.top - scrollView.jw_adjustedContentInset.top)
        } else {
            offsetY -= (scrollView.contentInset.top - scrollView.jw_adjustedContentInset.top)
        }
        
        if offsetY >= 0 {
            frame = CGRect(x: 0, y: -offsetY, width: scrollView.frame.size.width, height: offsetY)
            
            if state == .idle {
                contentView.setProgress?(progress: frame.size.height / contentView.frame.size.height)
            }
        }
        
        if state != .idle {
            var insetsTop = offsetY
            
            if scrollView.isTracking && insetsTop != T.preferredHeight {
                insetsTop = 0
            }
            
            insetsTop = min(contentView.frame.size.height, insetsTop)
            insetsTop = max(0, insetsTop)
            
            if scrollView.jw_adjustedContentInset.top != insetsTop {
                scrollView.layer.removeAllAnimations()
                UIView.animate(withDuration: 0.25, animations: {
                    scrollView.jw_updateHeaderInset(insetsTop)
                })
            }
        }
        
    }
    
    func updateContentViewByStateChanged() {
        guard let scrollView = scrollView else {
            return
        }
        
        switch state {
        case .idle:
            contentView.stopLoading?()
            UIView.animate(withDuration: 0.25, animations: {
                scrollView.jw_updateHeaderInset(0)
            })
            
        case .refreshing:
            contentView.startLoading?()
            UIView.animate(withDuration: 0.25, animations: {
                scrollView.jw_updateHeaderInset(self.contentView.frame.size.height)
            }, completion: { (finished) in
                self.refreshingBlock?(self)
                self.scrollView?.refreshFooter?.stopLoading()
            })
        default:
            break
        }
    }
}

extension RefreshFooterControl : AnyRefreshObserver {
    
    func scrollViewContentOffsetDidChange() {
        guard let scrollView = scrollView else {
            return
        }
        var offsetSpace = -preFetchedDistance
        var contentHeight = scrollView.contentSize.height
        if #available(iOS 11.0, *) {
            offsetSpace += scrollView.adjustedContentInset.bottom
            contentHeight += (scrollView.adjustedContentInset.top + scrollView.adjustedContentInset.bottom)
        }
        contentHeight += (scrollView.contentInset.top + scrollView.contentInset.bottom)
        if state != .pause &&
            scrollView.contentSize.height > 0 &&
            contentHeight >= scrollView.frame.size.height &&
            scrollView.contentOffset.y + scrollView.frame.size.height - scrollView.contentSize.height > offsetSpace {
            state = .refreshing
            frame = CGRect(x: 0, y: scrollView.contentSize.height, width: scrollView.frame.size.width, height: contentView.frame.size.height)
        }
    }
    
    public func updateContentViewByStateChanged() {
        guard let scrollView = scrollView else {
            return
        }
        
        switch state {
        case .idle:
            isHidden = true
            contentView.stopLoading?()
            scrollView.jw_updateFooterInset(0)
        case .refreshing:
            scrollView.jw_updateFooterInset(contentView.frame.size.height)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: {
                self.refreshingBlock?(self)
            })
            isHidden = false
            var contentFrame = contentView.frame
            contentFrame.size.width = scrollView.frame.size.width
            contentView.frame = contentFrame
            contentView.startLoading?()
        default:
            break
        }
    }
}
