//
//  ZHHTextLayoutCache.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/26.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit

/// 进程内布局缓存。相同的键共享同一次排版，列表滑回来时直接命中。
public final class ZHHTextMemoryLayoutCache: ZHHTextLayoutCache {

    // MARK: - 状态

    /// 进程内缓存桶。
    private let storage = NSCache<ZHHTextLayoutCacheKey, ZHHTextLayoutBox>()

    // MARK: - 初始化

    /// - Parameter countLimit: 最多保留的排版份数。超出后由系统按成本丢弃。
    public init(countLimit: Int = 200) {
        storage.countLimit = max(countLimit, 1)
        storage.totalCostLimit = 2_000_000
    }

    // MARK: - ZHHTextLayoutCache

    /// - Parameter key: 缓存键。
    /// - Returns: 已缓存的排版；未命中为 nil。
    public func layout(for key: ZHHTextLayoutKey) -> ZHHTextLayout? {
        storage.object(forKey: ZHHTextLayoutCacheKey(key))?.layout
    }

    /// - Parameters:
    ///   - layout: 排版结果。
    ///   - key: 缓存键。
    public func store(_ layout: ZHHTextLayout, for key: ZHHTextLayoutKey) {
        let cost = max(layout.displayText.length, 1)
        storage.setObject(ZHHTextLayoutBox(layout), forKey: ZHHTextLayoutCacheKey(key), cost: cost)
    }

    /// 清空全部缓存。
    public func removeAll() {
        storage.removeAllObjects()
    }
}

/// 在后台把排版写入缓存。正在显示的 Label 若使用同一个缓存，会等待同键的这一次计算，而不是再算一遍。
public enum ZHHTextLayoutPrefetcher {
    /// 预计算 `inputs`。已经缓存或正在计算的键会跳过重复工作。
    ///
    /// `completion` 在主线程调用。宽度、行数、展开态、截断文案、样式和 `interfaceStyle` 需要与 Label 一致。
    /// - Parameters:
    ///   - inputs: 与 Label 当前配置对齐的预取输入。
    ///   - cache: 写入结果的缓存。
    ///   - completion: 全部完成后在主线程回调；可为空。
    public static func prefetch(
        _ inputs: [ZHHTextLayoutInput],
        cache: ZHHTextLayoutCache,
        completion: (() -> Void)? = nil
    ) {
        let group = DispatchGroup()
        for input in inputs {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                _ = ZHHTextLayoutTasks.layout(input.request, cache: cache, asynchronous: true)
                group.leave()
            }
        }
        guard let completion = completion else { return }
        group.notify(queue: .main, execute: completion)
    }
}

/// 排版任务调度。同键的并发请求共用一次计算。
enum ZHHTextLayoutTasks {

    // MARK: - 状态

    /// 保护 `inflight` 的锁。
    fileprivate static let lock = NSLock()
    /// 正在计算的键到等待盒。
    fileprivate static var inflight: [ZHHTextLayoutKey: ZHHTextInflightBox] = [:]

    // MARK: - 公开接口

    /// 取排版结果。缓存命中立即返回；未命中时可能与其它调用方共用同一次计算。
    /// - Parameters:
    ///   - request: 排版输入。
    ///   - cache: 可选共享缓存。
    ///   - asynchronous: 主线程上未命中时是否挪到后台算完再回来。
    /// - Returns: 排版结果。
    static func layout(
        _ request: ZHHTextLayoutRequest,
        cache: ZHHTextLayoutCache?,
        asynchronous: Bool
    ) -> ZHHTextLayout {
        let key = ZHHTextLayoutEngine.makeKey(request)
        if let cached = cache?.layout(for: key) {
            return cached
        }

        switch claim(key) {
        case .waiter(let box):
            return box.wait()
        case .owner(let box):
            if let cached = cache?.layout(for: key) {
                retire(key)
                box.finish(cached)
                return cached
            }
            let compute = {
                ZHHTextLayoutEngine.layout(request)
            }
            if asynchronous && Thread.isMainThread {
                DispatchQueue.global(qos: .userInitiated).async {
                    let value = compute()
                    cache?.store(value, for: value.key)
                    retire(key)
                    box.finish(value)
                }
                return box.wait()
            }
            let value = compute()
            cache?.store(value, for: value.key)
            retire(key)
            box.finish(value)
            return value
        }
    }
}

// MARK: - 并发认领

private extension ZHHTextLayoutTasks {

    /// 认领同键计算时的角色。
    enum Claim {
        /// 负责真正计算的一方。
        case owner(ZHHTextInflightBox)
        /// 等待已有计算结束的一方。
        case waiter(ZHHTextInflightBox)
    }

    /// 登记或加入同键的进行中任务。
    /// - Parameter key: 缓存键。
    /// - Returns: 本次是计算方还是等待方。
    static func claim(_ key: ZHHTextLayoutKey) -> Claim {
        lock.lock()
        if let existing = inflight[key] {
            lock.unlock()
            return .waiter(existing)
        }
        let box = ZHHTextInflightBox()
        inflight[key] = box
        lock.unlock()
        return .owner(box)
    }

    /// 计算结束后从进行中表里拿掉该键。
    /// - Parameter key: 缓存键。
    static func retire(_ key: ZHHTextLayoutKey) {
        lock.lock()
        inflight.removeValue(forKey: key)
        lock.unlock()
    }
}

/// `NSCache` 用的键包装。
private final class ZHHTextLayoutCacheKey: NSObject {
    /// 真实缓存键。
    let key: ZHHTextLayoutKey

    /// - Parameter key: 真实缓存键。
    init(_ key: ZHHTextLayoutKey) {
        self.key = key
    }

    override var hash: Int { key.hashValue }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ZHHTextLayoutCacheKey else { return false }
        return other.key == key
    }
}

/// `NSCache` 用的值包装。
private final class ZHHTextLayoutBox: NSObject {
    /// 排版结果。
    let layout: ZHHTextLayout

    /// - Parameter layout: 排版结果。
    init(_ layout: ZHHTextLayout) {
        self.layout = layout
    }
}

/// 同键并发等待盒。计算方 `finish` 后唤醒所有等待方。
private final class ZHHTextInflightBox {
    /// 等待结果的条件变量。
    private let condition = NSCondition()
    /// 计算完成后的排版；未完成时为 nil。
    private var result: ZHHTextLayout?

    /// 阻塞直到结果就绪。
    /// - Returns: 排版结果。
    func wait() -> ZHHTextLayout {
        condition.lock()
        while result == nil {
            condition.wait()
        }
        let value = result!
        condition.unlock()
        return value
    }

    /// 写入结果并唤醒等待方。
    /// - Parameter layout: 排版结果。
    func finish(_ layout: ZHHTextLayout) {
        condition.lock()
        result = layout
        condition.broadcast()
        condition.unlock()
    }
}
